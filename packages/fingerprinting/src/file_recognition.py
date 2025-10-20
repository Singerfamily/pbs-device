#!/usr/bin/env python3
"""
Hymn Recognition CLI

Command-line interface for the hymn recognition system.
"""

import argparse
import sys
import os
from audio_recognizer import AudioRecognizer
from database import FingerprintDatabase
from realtime_recognizer import RealtimeRecognizer


def recognize_command(args):
    """Handle the recognize command."""
    if not os.path.exists(args.file):
        print(f"Error: File '{args.file}' not found")
        return

    print(f"\n{'='*80}")
    print(f"Recognizing: {args.file}")
    print(f"{'='*80}\n")

    # Initialize recognizer
    recognizer = AudioRecognizer(
        dbname=args.dbname,
        user=args.user,
        password=args.password,
        host=args.host,
        port=args.port
    )

    # Recognize the audio
    matches = recognizer.recognize_file(args.file, top_n=args.top)

    if not matches:
        print("No matches found. The audio may not be in the database.")
        return

    # Display results
    print(f"{'='*80}")
    print(f"Top {len(matches)} Match(es):")
    print(f"{'='*80}\n")

    for i, match in enumerate(matches, 1):
        print(f"{i}. {match['title']}")
        print(f"   Confidence: {match['confidence']:.1f}%")
        print(f"   Aligned Matches: {match['aligned_matches']} / {match['total_matches']} total")
        print(f"   Coverage: {match['coverage']:.1f}%")
        print(f"   File: {os.path.basename(match['filepath'])}")
        print()


def stats_command(args):
    """Handle the stats command."""
    database = FingerprintDatabase(
        dbname=args.dbname,
        user=args.user,
        password=args.password,
        host=args.host,
        port=args.port
    )
    stats = database.get_stats()

    print(f"{'='*60}")
    print("Database Statistics")
    print(f"{'='*60}")
    print(f"Database: {args.dbname}")
    print(f"Total songs: {stats['num_songs']}")
    print(f"Total fingerprints: {stats['num_fingerprints']:,}")
    print(f"Average fingerprints per song: {stats['avg_fingerprints_per_song']:.0f}")
    print(f"{'='*60}")


def list_command(args):
    """Handle the list command."""
    database = FingerprintDatabase(
        dbname=args.dbname,
        user=args.user,
        password=args.password,
        host=args.host,
        port=args.port
    )
    songs = database.get_all_songs()

    if not songs:
        print("No songs in database")
        return

    print(f"{'='*80}")
    print(f"Songs in Database ({len(songs)} total)")
    print(f"{'='*80}\n")

    for i, song in enumerate(songs, 1):
        print(f"{i}. {song['title']}")
        print(f"   ID: {song['hymn_number']}")
        print(f"   File: {os.path.basename(song['filepath'])}")
        print(f"   Indexed: {song['indexed_at']}")
        print()


def clear_command(args):
    """Handle the clear command."""
    if not args.confirm:
        response = input("Are you sure you want to clear the database? (yes/no): ")
        if response.lower() != 'yes':
            print("Cancelled")
            return

    database = FingerprintDatabase(
        dbname=args.dbname,
        user=args.user,
        password=args.password,
        host=args.host,
        port=args.port
    )
    database.clear_database()
    print("Database cleared successfully")


def realtime_command(args):
    """Handle the realtime command."""
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

    # Run interactive recognition
    print("\n" + "="*80)
    print("Real-Time Hymn Recognition")
    print("="*80)
    recognizer.run_interactive()


def main():
    """Main entry point for the CLI."""
    parser = argparse.ArgumentParser(
        description="Hymn Recognition System - Shazam for hymns",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Recognize an audio file
  python hymn_recognition.py recognize recording.mp3
  
  # Index all MP3 files in downloads directory
  python index.py downloads --clear
  
  # Show database statistics
  python hymn_recognition.py stats
  
  # List all songs in database
  python hymn_recognition.py list
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

    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Recognize command
    recognize_parser = subparsers.add_parser(
        "recognize",
        help="Recognize an audio file"
    )
    recognize_parser.add_argument(
        "file",
        help="Path to audio file to recognize"
    )
    recognize_parser.add_argument(
        "--top",
        type=int,
        default=5,
        help="Number of top matches to show (default: 5)"
    )

    # Stats command
    stats_parser = subparsers.add_parser(
        "stats",
        help="Show database statistics"
    )

    # List command
    list_parser = subparsers.add_parser(
        "list",
        help="List all songs in database"
    )

    # Clear command
    clear_parser = subparsers.add_parser(
        "clear",
        help="Clear the database"
    )
    clear_parser.add_argument(
        "--confirm",
        action="store_true",
        help="Skip confirmation prompt"
    )

    # Realtime command
    realtime_parser = subparsers.add_parser(
        "realtime",
        help="Recognize audio in real-time from microphone"
    )
    realtime_parser.add_argument(
        "--buffer",
        type=float,
        default=5.0,
        help="Audio buffer duration in seconds (default: 5.0)"
    )
    realtime_parser.add_argument(
        "--interval",
        type=float,
        default=2.0,
        help="Recognition interval in seconds (default: 2.0)"
    )
    realtime_parser.add_argument(
        "--min-confidence",
        type=float,
        default=10.0,
        help="Minimum confidence threshold to report matches (default: 10.0)"
    )
    realtime_parser.add_argument(
        "--device",
        type=int,
        default=None,
        help="Audio input device ID (use --list-devices to see available devices)"
    )
    realtime_parser.add_argument(
        "--list-devices",
        action="store_true",
        help="List available audio input devices and exit"
    )

    # Parse arguments
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    # Execute command
    if args.command == "recognize":
        recognize_command(args)
    elif args.command == "stats":
        stats_command(args)
    elif args.command == "list":
        list_command(args)
    elif args.command == "clear":
        clear_command(args)
    elif args.command == "realtime":
        realtime_command(args)


if __name__ == "__main__":
    main()
