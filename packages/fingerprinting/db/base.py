"""
Database Abstraction Layer

This module provides a base class for database implementations.
The primary implementation is PostgreSQL (database_postgres.py).
SQLite legacy support is available in database_sqlite.py.
"""

from abc import ABC, abstractmethod
from typing import List, Tuple, Dict, Optional


class FingerprintDatabaseBase(ABC):
    """Abstract base class for fingerprint database implementations."""
    
    @abstractmethod
    def add_song(self, filepath: str, title: Optional[str] = None, hymn_number: Optional[int] = None) -> int:
        """
        Add a song to the database.
        
        Args:
            filepath: Path to the audio file (e.g., "1__the-morning-breaks.mp3")
            title: Optional title for the song (auto-extracted if not provided)
            hymn_number: Optional hymn number (auto-extracted from filepath if not provided)
            
        Returns:
            Hymn number (used as primary key)
        """
        pass
    
    @abstractmethod
    def add_fingerprints(self, hymn_number: int, fingerprints: List[Tuple[str, int]]):
        """
        Add fingerprints for a song to the database.
        
        Args:
            hymn_number: Hymn number (primary key)
            fingerprints: List of (hash, time_offset) tuples
        """
        pass
    
    @abstractmethod
    def get_matches(self, fingerprints: List[Tuple[str, int]]) -> Dict[int, List[int]]:
        """
        Find matching fingerprints in the database.
        
        Args:
            fingerprints: List of (hash, time_offset) tuples from query audio
            
        Returns:
            Dictionary mapping hymn_number to list of time differences
        """
        pass
    
    @abstractmethod
    def get_song_info(self, hymn_number: int) -> Optional[Dict[str, any]]:
        """
        Get information about a song.
        
        Args:
            hymn_number: Hymn number (primary key)
            
        Returns:
            Dictionary with song information or None if not found
        """
        pass
    
    @abstractmethod
    def get_all_songs(self) -> List[Dict[str, any]]:
        """
        Get all songs in the database.
        
        Returns:
            List of dictionaries with song information
        """
        pass
    
    @abstractmethod
    def delete_song(self, hymn_number: int):
        """
        Delete a song and all its fingerprints from the database.
        
        Args:
            hymn_number: Hymn number of the song to delete
        """
        pass
    
    @abstractmethod
    def clear_database(self):
        """Delete all songs and fingerprints from the database."""
        pass
    
    @abstractmethod
    def get_stats(self) -> Dict[str, int]:
        """
        Get database statistics.
        
        Returns:
            Dictionary with statistics
        """
        pass
    
    @abstractmethod
    def close(self):
        """Close database connection."""
        pass
