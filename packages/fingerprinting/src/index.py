"""
Indexing Script

This script processes all MP3 files in the downloads directory
and creates fingerprints for the PostgreSQL database.
"""

import os
import glob
import argparse
from tqdm import tqdm
from fingerprint import AudioFingerprinter
from database import FingerprintDatabase
from concurrent.futures import ThreadPoolExecutor, as_completed
import multiprocessing


def process_single_file(filepath: str, fingerprinter: AudioFingerprinter) -> tuple:
    """
    Process a single MP3 file and return its fingerprints.
    
    Args:
        filepath: Path to the MP3 file
        fingerprinter: AudioFingerprinter instance
        
    Returns:
        Tuple of (filepath, hymn_number, title, fingerprints) or (filepath, None, None, error_message)
    """
    try:
        # Extract hymn number and title from filename
        filename = os.path.basename(filepath)

        if '__' not in filename:
            return (filepath, None, None, f"Filename must be in format 'NUMBER__name.mp3': {filename}")

        try:
            hymn_number = int(filename.split('__')[0])
        except ValueError:
            return (filepath, None, None, f"Could not parse hymn number from: {filename}")

        # Extract title from slug
        slug = filename.split('__')[1].replace('.mp3', '')
        title = slug.replace('-', ' ').replace('_', ' ')

        # Generate fingerprints
        fingerprints = fingerprinter.fingerprint_file(filepath)

        return (filepath, hymn_number, title, fingerprints)
    except Exception as e:
        return (filepath, None, None, str(e))


def index_directory(
        directory: str,
        dbname: str = "hymn_fingerprints",
        user: str = "postgres",
        password: str = "postgres",
        host: str = "localhost",
        port: int = 5432,
        clear_existing: bool = False,
        parallel_files: bool = True,
        max_workers: int = None
):
    """
    Index all MP3 files in a directory.
    
    Args:
        directory: Path to directory containing MP3 files
        dbname: PostgreSQL database name
        user: PostgreSQL user
        password: PostgreSQL password
        host: PostgreSQL host
        port: PostgreSQL port
        clear_existing: If True, clear existing database before indexing
        parallel_files: If True, process multiple files in parallel
        max_workers: Number of parallel workers (None = auto-detect)
    """
    # Initialize fingerprinter and database
    if max_workers is None:
        max_workers = max(1, multiprocessing.cpu_count() // 2)  # Leave some CPU for system

    fingerprinter = AudioFingerprinter(max_workers=2)  # Each file gets 2 threads for internal parallelism

    # Connect to PostgreSQL database
    database = FingerprintDatabase(
        dbname=dbname,
        user=user,
        password=password,
        host=host,
        port=port
    )
    print(f"Using PostgreSQL database: {dbname}")

    # Clear database if requested
    if clear_existing:
        print("Clearing existing database...")
        database.clear_database()

    # Find all MP3 files
    mp3_files = glob.glob(os.path.join(directory, "*.mp3"))

    if not mp3_files:
        print(f"No MP3 files found in {directory}")
        return

    print(f"Found {len(mp3_files)} MP3 files")
    print(f"Database: {dbname}")
    print(f"Parallel processing: {'enabled' if parallel_files else 'disabled'} ({max_workers} workers)")
    print("Starting indexing process...\n")

    # Process each file
    successful = 0
    failed = 0

    if parallel_files and len(mp3_files) > 1:
        # Parallel processing mode
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all files for processing
            future_to_file = {
                executor.submit(process_single_file, filepath, fingerprinter): filepath
                for filepath in mp3_files
            }

            # Process results as they complete
            with tqdm(total=len(mp3_files), desc="Indexing songs") as pbar:
                for future in as_completed(future_to_file):
                    result = future.result()
                    filepath, hymn_number, title, data = result

                    if hymn_number is None:
                        # Error occurred
                        print(f"\nError processing {filepath}: {data}")
                        failed += 1
                    else:
                        # Success - add to database
                        fingerprints = data
                        database.add_song(filepath, title, hymn_number)
                        database.add_fingerprints(hymn_number, fingerprints)
                        successful += 1

                    pbar.update(1)
    else:
        # Sequential processing mode
        for filepath in tqdm(mp3_files, desc="Indexing songs"):
            result = process_single_file(filepath, fingerprinter)
            filepath, hymn_number, title, data = result

            if hymn_number is None:
                print(f"\nError processing {filepath}: {data}")
                failed += 1
            else:
                fingerprints = data
                database.add_song(filepath, title, hymn_number)
                database.add_fingerprints(hymn_number, fingerprints)
                successful += 1

    # Print summary
    print(f"\n{'='*60}")
    print(f"Indexing complete!")
    print(f"  Successful: {successful}")
    print(f"  Failed: {failed}")

    # Print database statistics
    stats = database.get_stats()
    print(f"\nDatabase statistics:")
    print(f"  Total songs: {stats['num_songs']}")
    print(f"  Total fingerprints: {stats['num_fingerprints']}")
    print(f"  Avg fingerprints/song: {stats['avg_fingerprints_per_song']:.0f}")
    print(f"{'='*60}")

    # Close database connection
    database.close()


def main():
    """Main entry point for the indexing script."""
    parser = argparse.ArgumentParser(
        description="Index MP3 files for hymn recognition using PostgreSQL"
    )
    parser.add_argument(
        "directory",
        nargs="?",
        default="downloads",
        help="Directory containing MP3 files (default: downloads)"
    )
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
    parser.add_argument(
        "--clear",
        action="store_true",
        help="Clear existing database before indexing"
    )
    parser.add_argument(
        "--no-parallel",
        action="store_true",
        help="Disable parallel processing (slower but uses less memory)"
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=None,
        help="Number of parallel workers (default: auto-detect)"
    )

    args = parser.parse_args()

    # Check if directory exists
    if not os.path.exists(args.directory):
        print(f"Error: Directory '{args.directory}' not found")
        return

    # Run indexing
    index_directory(
        args.directory,
        dbname=args.dbname,
        user=args.user,
        password=args.password,
        host=args.host,
        port=args.port,
        clear_existing=args.clear,
        parallel_files=not args.no_parallel,
        max_workers=args.workers
    )


if __name__ == "__main__":
    main()
