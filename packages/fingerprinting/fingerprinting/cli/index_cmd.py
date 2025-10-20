#!/usr/bin/env python3
"""
Index Command - Index audio files for fingerprinting
"""

import sys
import os

# Add parent directory to path for imports
parent_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, parent_dir)

from fingerprinting.cli.index import main

if __name__ == "__main__":
    main()
