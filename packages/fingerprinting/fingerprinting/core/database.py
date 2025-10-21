import os
from typing import List, Tuple, Dict, Optional
from collections import defaultdict

from psycopg import pool, Error
from psycopg_pool import ConnectionPool
import psycopg

from ..utils.logger import setup_logger, ProgressLogger
from ..utils.exceptions import DatabaseError
from ..utils.config import config


class FingerprintDatabase():
    """PostgreSQL implementation of fingerprint database for high-performance operations."""

    def __init__(
            self,
            dbname: Optional[str] = None,
            user: Optional[str] = None,
            password: Optional[str] = None,
            host: Optional[str] = None,
            port: Optional[int] = None,
            max_connections: Optional[int] = None
    ):
        """
        Initialize PostgreSQL database connection.
        
        Args:
            dbname: Database name (defaults to config value)
            user: Database user (defaults to config value)
            password: Database password (defaults to config value)
            host: Database host (defaults to config value)
            port: Database port (defaults to config value)
            max_connections: Max connections in pool (defaults to config value)
            
        Raises:
            DatabaseError: If database connection fails
        """
        # Use config values as defaults
        self.dbname = dbname or config.database.dbname
        self.user = user or config.database.user
        self.password = password or config.database.password
        self.host = host or config.database.host
        self.port = port or config.database.port
        max_conn = max_connections or config.database.max_connections
        
        # Setup logger
        self.logger = setup_logger(__name__)
        self.progress = ProgressLogger(self.logger)
        
        try:
            self.connection_pool = ConnectionPool(
                minconn=1,
                maxconn=max_conn,
                dbname=self.dbname,
                user=self.user,
                password=self.password,
                host=self.host,
                port=self.port
            )
            self.progress.success(f"Connected to database: {self.dbname}")
        except Error as e:
            raise DatabaseError(
                f"Failed to connect to PostgreSQL database '{self.dbname}' "
                f"at {self.host}:{self.port}. Error: {str(e)}. "
                f"Make sure PostgreSQL is running and credentials are correct."
            )

        self._init_db()

    def _get_connection(self):
        """Get a connection from the pool."""
        return self.connection_pool.getconn()

    def _return_connection(self, conn):
        """Return a connection to the pool."""
        self.connection_pool.putconn(conn)

    def _init_db(self):
        """
        Create database tables if they don't exist.
        
        Raises:
            DatabaseError: If table creation fails
        """
        conn = self._get_connection()
        try:
            cursor: psycopg.cursor.Cursor = conn.cursor()

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
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_hash 
                ON fingerprints USING HASH (hash)
            """)

            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_hymn_number 
                ON fingerprints(hymn_number)
            """)

            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_hash_hymn 
                ON fingerprints(hash, hymn_number)
            """)

            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_time_offset 
                ON fingerprints(time_offset)
            """)

            # Optimize database settings
            cursor.execute("SET max_parallel_workers_per_gather = 4")
            cursor.execute("SET maintenance_work_mem = '256MB'")

            conn.commit()
            self.logger.debug("Database schema initialized successfully")
        except Error as e:
            raise DatabaseError(f"Failed to initialize database schema: {str(e)}")
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
            data = [(hash_val, time_offset, hymn_number) for hash_val, time_offset in fingerprints]

            cursor.executemany(
                "INSERT INTO fingerprints (hash, time_offset, hymn_number) VALUES (%s, %s, %s)",
                data,
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
