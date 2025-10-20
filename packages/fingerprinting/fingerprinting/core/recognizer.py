"""
Recognition Module

This module implements the audio recognition algorithm that matches
query audio against the fingerprint database.
"""

from typing import List, Tuple, Dict, Optional
from collections import Counter
import numpy as np

from fingerprint import AudioFingerprinter
from database import FingerprintDatabase
from utils.logger import setup_logger, ProgressLogger
from utils.exceptions import RecognitionError
from utils.config import config


class AudioRecognizer:
    """Recognize audio by matching fingerprints against the database."""

    def __init__(
            self,
            dbname: Optional[str] = None,
            user: Optional[str] = None,
            password: Optional[str] = None,
            host: Optional[str] = None,
            port: Optional[int] = None
    ):
        """
        Initialize the audio recognizer.
        
        Args:
            dbname: PostgreSQL database name (defaults to config value)
            user: PostgreSQL user (defaults to config value)
            password: PostgreSQL password (defaults to config value)
            host: PostgreSQL host (defaults to config value)
            port: PostgreSQL port (defaults to config value)
        """
        self.fingerprinter = AudioFingerprinter()
        self.database = FingerprintDatabase(
            dbname=dbname,
            user=user,
            password=password,
            host=host,
            port=port
        )
        
        # Setup logger
        self.logger = setup_logger(__name__)
        self.progress = ProgressLogger(self.logger)

    def recognize_file(self, filepath: str, top_n: int = 5) -> List[Dict]:
        """
        Recognize an audio file.
        
        Args:
            filepath: Path to the audio file to recognize
            top_n: Number of top matches to return
            
        Returns:
            List of match dictionaries with song info and confidence scores
        """
        # Generate fingerprints for the query audio
        fingerprints = self.fingerprinter.fingerprint_file(filepath)

        # Match against database
        matches = self._match_fingerprints(fingerprints, top_n)

        return matches

    def recognize_audio(self, audio: np.ndarray, top_n: int = 5) -> List[Dict]:
        """
        Recognize audio from a numpy array.
        
        Args:
            audio: Audio signal as numpy array
            top_n: Number of top matches to return
            
        Returns:
            List of match dictionaries with song info and confidence scores
        """
        # Generate fingerprints for the query audio
        fingerprints = self.fingerprinter.fingerprint_audio(audio)

        # Match against database
        matches = self._match_fingerprints(fingerprints, top_n)

        return matches

    def _match_fingerprints(
            self,
            query_fingerprints: List[Tuple[str, int]],
            top_n: int
    ) -> List[Dict]:
        """
        Match query fingerprints against the database.
        
        The matching algorithm works by:
        1. Finding all database fingerprints that match query hashes
        2. For each matching song, collecting time differences
        3. Finding the most common time difference (histogram peak)
        4. Scoring songs based on the number of aligned matches
        
        Args:
            query_fingerprints: List of (hash, time_offset) tuples
            top_n: Number of top matches to return
            
        Returns:
            List of match dictionaries sorted by confidence
        """
        if not query_fingerprints:
            self.logger.warning("No fingerprints provided for matching")
            return []
        
        # Get raw matches from database
        self.progress.start(f"Searching database for matches ({len(query_fingerprints)} fingerprints)")
        raw_matches = self.database.get_matches(query_fingerprints)

        if not raw_matches:
            self.progress.warning("No matches found in database")
            return []

        self.progress.success(f"Found potential matches in {len(raw_matches)} songs")

        # Score each song based on time-aligned matches
        self.progress.start("Scoring and aligning matches")
        song_scores = []

        for hymn_number, time_diffs in raw_matches.items():
            # Count occurrences of each time difference
            # The most common time difference represents the true alignment
            time_diff_counter = Counter(time_diffs)

            # Get the most common time difference and its count
            most_common_diff, aligned_matches = time_diff_counter.most_common(1)[0]

            # Calculate cluster score - how concentrated are the top matches?
            top_10 = time_diff_counter.most_common(10)
            if len(top_10) > 1:
                top_10_sum = sum(count for _, count in top_10)
                cluster_score = top_10_sum / len(time_diffs) if len(time_diffs) > 0 else 0
            else:
                cluster_score = aligned_matches / len(time_diffs) if len(time_diffs) > 0 else 0

            # Calculate confidence score
            total_query_fingerprints = len(query_fingerprints)
            total_matches = len(time_diffs)

            coverage_score = aligned_matches / total_query_fingerprints if total_query_fingerprints > 0 else 0
            consistency_score = aligned_matches / total_matches if total_matches > 0 else 0

            # Combined confidence score (0-100 scale)
            confidence = (
                    coverage_score * 85 +
                    cluster_score * 10 +
                    consistency_score * 5
            )

            # Get song information
            song_info = self.database.get_song_info(hymn_number)

            if song_info:
                song_scores.append({
                    'hymn_number': hymn_number,
                    'title': song_info['title'],
                    'filepath': song_info['filepath'],
                    'confidence': round(confidence, 2),
                    'aligned_matches': aligned_matches,
                    'total_matches': total_matches,
                    'coverage': round(coverage_score * 100, 2),
                    'consistency': round(consistency_score * 100, 4),
                    'cluster_score': round(cluster_score * 100, 4),
                    'time_offset': most_common_diff
                })

        # Sort by aligned matches, cluster score, and consistency
        song_scores.sort(
            key=lambda x: (x['aligned_matches'], x['cluster_score'], x['consistency']),
            reverse=True
        )

        self.progress.success(f"Scored {len(song_scores)} songs")

        # Return top N matches
        return song_scores[:top_n]

    def get_database_stats(self) -> Dict[str, int]:
        """
        Get statistics about the fingerprint database.
        
        Returns:
            Dictionary with database statistics
        """
        return self.database.get_stats()
