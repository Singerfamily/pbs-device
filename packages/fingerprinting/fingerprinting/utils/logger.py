"""
Logging Configuration

Centralized logging setup for the fingerprinting system.
"""

import logging
import sys
from typing import Optional


def setup_logger(
    name: str,
    level: int = logging.INFO,
    log_file: Optional[str] = None
) -> logging.Logger:
    """
    Set up a logger with consistent formatting.
    
    Args:
        name: Logger name (usually __name__)
        level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_file: Optional file path to write logs to
        
    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)
    logger.setLevel(level)
    
    # Remove existing handlers to avoid duplicates
    logger.handlers.clear()
    
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # File handler (optional)
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(level)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    
    return logger


class ProgressLogger:
    """Helper class for logging progress with consistent formatting."""
    
    def __init__(self, logger: logging.Logger):
        self.logger = logger
    
    def start(self, message: str):
        """Log the start of an operation."""
        self.logger.info(f"→ {message}")
    
    def success(self, message: str):
        """Log a successful operation."""
        self.logger.info(f"✓ {message}")
    
    def warning(self, message: str):
        """Log a warning."""
        self.logger.warning(f"⚠ {message}")
    
    def error(self, message: str):
        """Log an error."""
        self.logger.error(f"✗ {message}")
