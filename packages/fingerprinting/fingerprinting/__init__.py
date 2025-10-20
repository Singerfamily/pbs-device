"""
Audio Fingerprinting System

A Shazam-like audio fingerprinting and recognition system for identifying songs.
"""

__version__ = "1.0.0"

from .core.fingerprint import AudioFingerprinter
from .core.database import FingerprintDatabase
from .core.recognizer import AudioRecognizer
from .utils.config import config, Config
from .utils.exceptions import (
    FingerprintException,
    AudioProcessingError,
    DatabaseError,
    InvalidFileFormatError,
    RecognitionError,
    ValidationError,
)

__all__ = [
    "AudioFingerprinter",
    "FingerprintDatabase",
    "AudioRecognizer",
    "config",
    "Config",
    "FingerprintException",
    "AudioProcessingError",
    "DatabaseError",
    "InvalidFileFormatError",
    "RecognitionError",
    "ValidationError",
]
