#!/usr/bin/env python3
"""
Real-Time Hymn Recognition

A standalone script for real-time hymn recognition from microphone input.
This provides a simple way to start listening for hymns without needing
to remember CLI arguments.
"""

from .file_recognition import RealtimeRecognizer
import argparse


def main():
    parser = argparse.ArgumentParser(
        description="Real-time hymn recognition from microphone",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Start listening with default settings
  python realtime.py
  
  # List available audio devices
  python realtime.py --list-devices
  
  # Use a specific audio device
  python realtime.py --device 2
  
  # Adjust buffer and recognition interval
  python realtime.py --buffer 8 --interval 3
  
  # Set minimum confidence threshold
  python realtime.py --min-confidence 15
        """
    )
    
    # PostgreSQL connection arguments
    parser.add_argument(
        "--dbname",
        default="hymn_fingerprints",
        help="PostgreSQL database name (default: hymn_fingerprints)"
    )
    parser.add_argument(
        "--user",
        default="postgres",
        help="PostgreSQL user (default: postgres)"
    )
    parser.add_argument(
        "--password",
        default="postgres",
        help="PostgreSQL password (default: postgres)"
    )
    parser.add_argument(
        "--host",
        default="localhost",
        help="PostgreSQL host (default: localhost)"
    )
    parser.add_argument(
        "--port",
        type=int,
        default=5432,
        help="PostgreSQL port (default: 5432)"
    )
    
    # Real-time recognition settings
    parser.add_argument(
        "--buffer",
        type=float,
        default=5.0,
        help="Audio buffer duration in seconds (default: 5.0)"
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=2.0,
        help="How often to attempt recognition in seconds (default: 2.0)"
    )
    parser.add_argument(
        "--min-confidence",
        type=float,
        default=10.0,
        help="Minimum confidence threshold to report matches (default: 10.0)"
    )
    
    # Audio device settings
    parser.add_argument(
        "--device",
        type=int,
        default=None,
        help="Audio input device ID (use --list-devices to see options)"
    )
    parser.add_argument(
        "--list-devices",
        action="store_true",
        help="List available audio input devices and exit"
    )
    
    args = parser.parse_args()
    
    # Create recognizer
    recognizer = RealtimeRecognizer(
        dbname=args.dbname,
        user=args.user,
        password=args.password,
        host=args.host,
        port=args.port,
        buffer_duration=args.buffer,
        recognition_interval=args.interval,
        min_confidence=args.min_confidence
    )
    
    # List devices if requested
    if args.list_devices:
        recognizer.list_audio_devices()
        return
    
    # Set device if specified
    if args.device is not None:
        recognizer.set_audio_device(args.device)
    
    # Display banner
    print("\n" + "="*80)
    print(" " * 25 + "Real-Time Hymn Recognition")
    print("="*80)
    print()
    print("This system will continuously listen to your microphone and identify")
    print("hymns being played. Make sure your database is populated with hymn")
    print("fingerprints before running this.")
    print()
    
    # Run recognition
    recognizer.run_interactive()


if __name__ == "__main__":
    main()
