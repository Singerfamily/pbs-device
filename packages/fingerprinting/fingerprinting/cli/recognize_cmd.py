#!/usr/bin/env python3
"""
Recognize Command - Recognize audio files
"""

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from recognize import main

if __name__ == "__main__":
    main()
