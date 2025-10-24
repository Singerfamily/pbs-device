"""
Custom Exceptions

Defines custom exception classes for better error handling and user feedback.
"""


class FingerprintException(Exception):
    """Base exception for fingerprinting system errors."""
    pass


class AudioProcessingError(FingerprintException):
    """Raised when audio processing fails."""
    pass


class DatabaseError(FingerprintException):
    """Raised when database operations fail."""
    pass


class InvalidFileFormatError(FingerprintException):
    """Raised when the audio file format is invalid or unsupported."""
    pass


class FileNotFoundError(FingerprintException):
    """Raised when a required file is not found."""
    pass


class ConfigurationError(FingerprintException):
    """Raised when there's an issue with configuration."""
    pass


class RecognitionError(FingerprintException):
    """Raised when audio recognition fails."""
    pass


class ValidationError(FingerprintException):
    """Raised when input validation fails."""
    pass
