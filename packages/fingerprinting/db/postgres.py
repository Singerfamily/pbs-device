"""
PostgreSQL Fingerprint Database

This module implements a PostgreSQL version of the fingerprint database,
optimized for high-performance operations with concurrent writes.

This is now the primary and only database backend for the hymn recognition system.
"""

import os
import re
from typing import List, Tuple, Dict, Optional
from collections import defaultdict
from database_base import FingerprintDatabaseBase

try:
    import psycopg2
    from psycopg2 import pool
    from psycopg2.extras import execute_batch
    POSTGRES_AVAILABLE = True
except ImportError:
    POSTGRES_AVAILABLE = False
    print("Warning: psycopg2 not installed. PostgreSQL support disabled.")
    print("Install with: pip install psycopg2-binary")


class PostgresFingerprintDatabase(FingerprintDatabaseBase):
    """PostgreSQL implementation of fingerprint database for high-performance operations."""
    
    def __init__(
        self, 
        dbname: str = "hymn_fingerprints",
        user: str = "postgres",
        password: str = "postgres", 
        host: str = "localhost",
        port: int = 5432,
        max_connections: int = 10
    ):
        """
        Initialize PostgreSQL database connection.
        
        Args:
            dbname: Database name
            user: Database user
            password: Database password
            host: Database host
            port: Database port
            max_connections: Max connections in pool
        """
        if not POSTGRES_AVAILABLE:
            raise ImportError("psycopg2 is required for PostgreSQL support")
        
        self.connection_pool = psycopg2.pool.ThreadedConnectionPool(
            minconn=1,
            maxconn=max_connections,
            dbname=dbname,
            user=user,
            password=password,
            host=host,
            port=port
        )
        
        self._init_db()
    
    def _get_connection(self):
        """Get a connection from the pool."""
        return self.connection_pool.getconn()
    
    def _return_connection(self, conn):
        """Return a connection to the pool."""
        self.connection_pool.putconn(conn)
    
    def _init_db(self):
        """Create database tables if they don't exist."""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            
            # Table for songs/hymns
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS songs (
                    hymn_number INTEGER PRIMARY KEY,
                    filepath TEXT UNIQUE NOT NULL,
                    title TEXT NOT NULL,
                    duration_seconds REAL,
                    fingerprint_count INTEGER DEFAULT 0,
                    indexed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Table for fingerprints
            # Use BYTEA for hash storage (more efficient than TEXT)
            # But we'll keep TEXT for now for compatibility - can migrate later
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS fingerprints (
                    id BIGSERIAL PRIMARY KEY,
                    hash TEXT NOT NULL,
                    time_offset INTEGER NOT NULL,
                    hymn_number INTEGER NOT NULL,
                    CONSTRAINT fk_hymn 
                        FOREIGN KEY (hymn_number) 
                        REFERENCES songs(hymn_number) 
                        ON DELETE CASCADE
                )
            """)
            
            # Create optimized indices for fast lookup
            # HASH index is perfect for exact-match queries (faster than B-tree for =)
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_hash 
                ON fingerprints USING HASH (hash)
            """)
            
            # B-tree index for hymn_number (needed for FK and range queries)
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_hymn_number 
                ON fingerprints(hymn_number)
            """)
            
            # Composite index for common query patterns
            # Useful if we ever query by hash AND hymn_number together
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_hash_hymn 
                ON fingerprints(hash, hymn_number)
            """)
            
            # Add index on time_offset for potential future queries
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_time_offset 
                ON fingerprints(time_offset)
            """)
            
            # Enable parallel query execution for large scans
            cursor.execute("SET max_parallel_workers_per_gather = 4")
            
            # Optimize for bulk inserts
            cursor.execute("SET maintenance_work_mem = '256MB'")
            
            conn.commit()
        finally:
            self._return_connection(conn)
    
    def add_song(self, filepath: str, title: Optional[str] = None, hymn_number: Optional[int] = None) -> int:
        """Add a song to the database."""
        # Extract hymn number from filepath if not provided
        if hymn_number is None:
            basename = os.path.basename(filepath)
            if '__' in basename:
                try:
                    hymn_number = int(basename.split('__')[0])
                except ValueError:
                    raise ValueError(f"Could not extract hymn number from filepath: {filepath}")
            else:
                raise ValueError(f"Filepath must be in format 'NUMBER__name.mp3': {filepath}")
        
        # Extract title from filename if not provided
        if title is None:
            basename = os.path.basename(filepath)
            if '__' in basename:
                slug = basename.split('__')[1].replace('.mp3', '')
                title = slug.replace('-', ' ').replace('_', ' ')
            else:
                title = basename.replace('.mp3', '').replace('_', ' ')
        
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            
            # Use INSERT ON CONFLICT for upsert behavior
            cursor.execute("""
                INSERT INTO songs (hymn_number, filepath, title, fingerprint_count, indexed_at, updated_at)
                VALUES (%s, %s, %s, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                ON CONFLICT (hymn_number) 
                DO UPDATE SET 
                    filepath = EXCLUDED.filepath,
                    title = EXCLUDED.title,
                    updated_at = CURRENT_TIMESTAMP
            """, (hymn_number, filepath, title))
            
            conn.commit()
            return hymn_number
        finally:
            self._return_connection(conn)
    
    def add_fingerprints(self, hymn_number: int, fingerprints: List[Tuple[str, int]]):
        """Add fingerprints for a song to the database."""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            
            # Delete existing fingerprints for this hymn (in case of re-indexing)
            cursor.execute("DELETE FROM fingerprints WHERE hymn_number = %s", (hymn_number,))
            
            # Prepare data for batch insert
            data = [(hash_val, time_offset, hymn_number) 
                    for hash_val, time_offset in fingerprints]
            
            # Use execute_batch for efficient bulk insert (much faster than executemany)
            execute_batch(
                cursor,
                "INSERT INTO fingerprints (hash, time_offset, hymn_number) VALUES (%s, %s, %s)",
                data,
                page_size=2000  # Insert in batches of 2000 (increased from 1000)
            )
            
            # Update fingerprint count in songs table
            cursor.execute("""
                UPDATE songs 
                SET fingerprint_count = %s, updated_at = CURRENT_TIMESTAMP 
                WHERE hymn_number = %s
            """, (len(fingerprints), hymn_number))
            
            conn.commit()
        finally:
            self._return_connection(conn)
    
    def get_matches(self, fingerprints: List[Tuple[str, int]]) -> Dict[int, List[int]]:
        """Find matching fingerprints in the database with optimized query."""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            
            # Dictionary to store matches
            matches = defaultdict(list)
            
            # Extract just the hashes for efficient querying
            hashes = [h for h, _ in fingerprints]
            
            # Create lookup dict for query times
            query_times = {h: t for h, t in fingerprints}
            
            # Optimized query using ANY for hash matching
            # The HASH index on hash column makes this very fast
            # We select only the columns we need to minimize data transfer
            cursor.execute("""
                SELECT hash, hymn_number, time_offset 
                FROM fingerprints 
                WHERE hash = ANY(%s)
            """, (hashes,))
            
            # Process results efficiently
            for db_hash, hymn_number, db_time in cursor.fetchall():
                if db_hash in query_times:
                    query_time = query_times[db_hash]
                    time_diff = db_time - query_time
                    matches[hymn_number].append(time_diff)
            
            return dict(matches)
        finally:
            self._return_connection(conn)
    
    def get_song_info(self, hymn_number: int) -> Optional[Dict[str, any]]:
        """Get information about a song."""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT hymn_number, filepath, title, duration_seconds, 
                       fingerprint_count, indexed_at, updated_at 
                FROM songs 
                WHERE hymn_number = %s
            """, (hymn_number,))
            result = cursor.fetchone()
            
            if result:
                return {
                    'hymn_number': result[0],
                    'filepath': result[1],
                    'title': result[2],
                    'duration_seconds': result[3],
                    'fingerprint_count': result[4],
                    'indexed_at': result[5],
                    'updated_at': result[6]
                }
            return None
        finally:
            self._return_connection(conn)
    
    def get_all_songs(self) -> List[Dict[str, any]]:
        """Get all songs in the database."""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT hymn_number, filepath, title, duration_seconds, 
                       fingerprint_count, indexed_at, updated_at 
                FROM songs 
                ORDER BY hymn_number
            """)
            results = cursor.fetchall()
            
            songs = []
            for row in results:
                songs.append({
                    'hymn_number': row[0],
                    'filepath': row[1],
                    'title': row[2],
                    'duration_seconds': row[3],
                    'fingerprint_count': row[4],
                    'indexed_at': row[5],
                    'updated_at': row[6]
                })
            
            return songs
        finally:
            self._return_connection(conn)
    
    def delete_song(self, hymn_number: int):
        """Delete a song and all its fingerprints."""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM songs WHERE hymn_number = %s", (hymn_number,))
            conn.commit()
        finally:
            self._return_connection(conn)
    
    def clear_database(self):
        """Delete all songs and fingerprints."""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM fingerprints")
            cursor.execute("DELETE FROM songs")
            conn.commit()
        finally:
            self._return_connection(conn)
    
    def get_stats(self) -> Dict[str, int]:
        """Get database statistics."""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            
            cursor.execute("SELECT COUNT(*) FROM songs")
            num_songs = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM fingerprints")
            num_fingerprints = cursor.fetchone()[0]
            
            return {
                'num_songs': num_songs,
                'num_fingerprints': num_fingerprints,
                'avg_fingerprints_per_song': num_fingerprints / num_songs if num_songs > 0 else 0
            }
        finally:
            self._return_connection(conn)
    
    def close(self):
        """Close all database connections."""
        self.connection_pool.closeall()
