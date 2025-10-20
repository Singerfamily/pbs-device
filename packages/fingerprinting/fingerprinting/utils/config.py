"""
Configuration Management

Centralized configuration for the fingerprinting system.
Supports environment variables and provides sensible defaults.
"""

import os
from dataclasses import dataclass
from typing import Optional


@dataclass
class DatabaseConfig:
    """PostgreSQL database configuration."""
    
    dbname: str = os.getenv("FINGERPRINT_DB_NAME", "hymn_fingerprints")
    user: str = os.getenv("FINGERPRINT_DB_USER", "postgres")
    password: str = os.getenv("FINGERPRINT_DB_PASSWORD", "postgres")
    host: str = os.getenv("FINGERPRINT_DB_HOST", "localhost")
    port: int = int(os.getenv("FINGERPRINT_DB_PORT", "5432"))
    max_connections: int = int(os.getenv("FINGERPRINT_DB_MAX_CONNECTIONS", "10"))


@dataclass
class AudioConfig:
    """Audio processing configuration."""
    
    # Audio processing parameters
    sample_rate: int = 22050
    fft_window_size: int = 4096
    overlap_ratio: float = 0.5
    
    # Peak detection parameters
    peak_neighborhood_size: int = 20
    
    # Fingerprint pairing parameters
    min_time_delta: int = 0
    max_time_delta: int = 200
    freq_bins: int = 512
    fan_value: int = 5
    
    # Performance parameters
    chunk_duration: int = 30
    max_workers: Optional[int] = None


@dataclass
class RecognitionConfig:
    """Audio recognition configuration."""
    
    # Recognition parameters
    min_confidence: float = 10.0
    default_top_matches: int = 5
    
    # Real-time recognition (if implemented)
    buffer_duration: float = 5.0
    recognition_interval: float = 2.0


class Config:
    """Main configuration object."""
    
    def __init__(self):
        self.database = DatabaseConfig()
        self.audio = AudioConfig()
        self.recognition = RecognitionConfig()
    
    @classmethod
    def from_env(cls) -> "Config":
        """Create configuration from environment variables."""
        return cls()


# Global configuration instance
config = Config.from_env()
