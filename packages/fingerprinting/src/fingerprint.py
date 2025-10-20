"""
Audio Fingerprinting Module

This module implements a Shazam-style audio fingerprinting algorithm.
It generates unique fingerprints from audio files using spectral peak analysis.

The algorithm works as follows:
1. Convert audio to mono and resample to a standard sample rate
2. Compute spectrogram using Short-Time Fourier Transform (STFT)
3. Find spectral peaks in the spectrogram (constellation map)
4. Generate hash pairs from peaks based on time and frequency relationships
5. Store hashes with time offsets for matching
"""

import numpy as np
import librosa
import hashlib
import os
from typing import List, Tuple, Dict, Optional
from scipy.ndimage import maximum_filter
from scipy.ndimage import generate_binary_structure, iterate_structure
from concurrent.futures import ThreadPoolExecutor, as_completed
import multiprocessing
import subprocess
import io

from logger import setup_logger, ProgressLogger
from exceptions import AudioProcessingError, InvalidFileFormatError
from config import config


class AudioFingerprinter:
    """Generate audio fingerprints using spectral peak analysis."""

    def __init__(self, max_workers: Optional[int] = None):
        """
        Initialize the fingerprinter.
        
        Args:
            max_workers: Maximum number of worker threads. If None, uses CPU count.
        """
        # Use configuration from config module
        self.sample_rate = config.audio.sample_rate
        self.fft_window_size = config.audio.fft_window_size
        self.overlap_ratio = config.audio.overlap_ratio
        self.peak_neighborhood_size = config.audio.peak_neighborhood_size
        self.min_time_delta = config.audio.min_time_delta
        self.max_time_delta = config.audio.max_time_delta
        self.freq_bins = config.audio.freq_bins
        self.fan_value = config.audio.fan_value
        self.chunk_duration = config.audio.chunk_duration
        
        self.hop_length = int(self.fft_window_size * (1 - self.overlap_ratio))
        self.max_workers = max_workers or config.audio.max_workers or max(1, multiprocessing.cpu_count() - 2)
        
        # Setup logger
        self.logger = setup_logger(__name__)
        self.progress = ProgressLogger(self.logger)

    def load_audio(self, filepath: str) -> np.ndarray:
        """
        Load an audio file and convert it to the standard format using ffmpeg.
        This is much faster than librosa's default decoder.
        
        Args:
            filepath: Path to the audio file
            
        Returns:
            Audio signal as numpy array
            
        Raises:
            InvalidFileFormatError: If the file format is not supported
            AudioProcessingError: If audio loading fails
        """
        if not os.path.exists(filepath):
            raise InvalidFileFormatError(f"Audio file not found: {filepath}")
        
        self.progress.start(f"Loading audio file: {os.path.basename(filepath)}")
        
        # Use ffmpeg to decode audio to raw PCM format
        command = [
            'ffmpeg',
            '-i', filepath,
            '-f', 's16le',  # 16-bit PCM
            '-acodec', 'pcm_s16le',
            '-ar', str(self.sample_rate),  # Resample to target rate
            '-ac', '1',  # Convert to mono
            '-'  # Output to stdout
        ]

        try:
            # Run ffmpeg and capture output
            process = subprocess.run(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True
            )

            # Convert raw PCM bytes to numpy array
            audio = np.frombuffer(process.stdout, dtype=np.int16)

            # Normalize to [-1.0, 1.0] range (librosa convention)
            audio = audio.astype(np.float32) / 32768.0

            duration = len(audio) / self.sample_rate
            self.progress.success(f"Loaded {duration:.1f} seconds of audio")

            return audio

        except subprocess.CalledProcessError as e:
            error_msg = e.stderr.decode() if e.stderr else str(e)
            self.progress.warning(f"ffmpeg failed, falling back to librosa: {error_msg}")
            
            try:
                audio, _ = librosa.load(filepath, sr=self.sample_rate, mono=True)
                duration = len(audio) / self.sample_rate
                self.progress.success(f"Loaded {duration:.1f} seconds of audio (via librosa)")
                return audio
            except Exception as librosa_error:
                raise AudioProcessingError(
                    f"Failed to load audio file {filepath}. "
                    f"Tried both ffmpeg and librosa. Error: {str(librosa_error)}"
                )
                
        except FileNotFoundError:
            # ffmpeg not found, fallback to librosa
            self.progress.warning("ffmpeg not installed, using librosa (slower)")
            
            try:
                audio, _ = librosa.load(filepath, sr=self.sample_rate, mono=True)
                duration = len(audio) / self.sample_rate
                self.progress.success(f"Loaded {duration:.1f} seconds of audio (via librosa)")
                return audio
            except Exception as librosa_error:
                raise AudioProcessingError(
                    f"Failed to load audio file {filepath} with librosa. "
                    f"Error: {str(librosa_error)}. "
                    f"Install ffmpeg for faster processing: apt-get install ffmpeg"
                )
    def _split_audio_into_chunks(self, audio: np.ndarray) -> List[Tuple[np.ndarray, int]]:
        """
        Split audio into overlapping chunks for parallel processing.
        
        Args:
            audio: Full audio signal
            
        Returns:
            List of (chunk_audio, start_sample) tuples
        """
        chunk_samples = int(self.chunk_duration * self.sample_rate)
        # Use 10% overlap between chunks to avoid missing peaks at boundaries
        overlap_samples = int(chunk_samples * 0.1)

        chunks = []
        start = 0

        while start < len(audio):
            end = min(start + chunk_samples, len(audio))
            chunk = audio[start:end]
            chunks.append((chunk, start))

            if end >= len(audio):
                break

            start += chunk_samples - overlap_samples

        return chunks

    def compute_spectrogram(self, audio: np.ndarray) -> np.ndarray:
        """
        Compute the spectrogram of an audio signal.
        
        Args:
            audio: Audio signal
            
        Returns:
            Spectrogram as 2D array (frequency x time)
        """
        # Compute Short-Time Fourier Transform
        stft = librosa.stft(
            audio,
            n_fft=self.FFT_WINDOW_SIZE,
            hop_length=self.hop_length,
            window='hann'
        )

        # Convert to magnitude spectrogram
        spectrogram = np.abs(stft)

        # Convert to dB scale for better peak detection
        spectrogram = librosa.amplitude_to_db(spectrogram, ref=np.max)

        return spectrogram

    def find_peaks(self, spectrogram: np.ndarray) -> List[Tuple[int, int]]:
        """
        Find spectral peaks in the spectrogram using local maxima.
        
        Args:
            spectrogram: 2D spectrogram array
            
        Returns:
            List of (time_index, freq_index) tuples for peaks
        """
        # Create a structural element for finding local maxima
        struct = generate_binary_structure(2, 1)
        neighborhood = iterate_structure(struct, self.PEAK_NEIGHBORHOOD_SIZE)

        # Find local maxima
        local_max = maximum_filter(spectrogram, footprint=neighborhood) == spectrogram

        # Remove background (keep only significant peaks)
        background = (spectrogram == 0)
        eroded_background = maximum_filter(background, footprint=neighborhood)
        detected_peaks = local_max ^ eroded_background

        # Get coordinates of peaks
        peaks = np.argwhere(detected_peaks)

        # Return as list of (time, frequency) tuples
        # peaks are returned as [freq_idx, time_idx], so we swap them
        peak_list = [(int(time), int(freq)) for freq, time in peaks]

        return peak_list

    def _process_chunk(self, chunk_data: Tuple[np.ndarray, int]) -> Tuple[List[Tuple[int, int]], int]:
        """
        Process a single audio chunk: compute spectrogram and find peaks.
        
        Args:
            chunk_data: Tuple of (audio_chunk, start_sample)
            
        Returns:
            Tuple of (peaks, time_offset_frames)
        """
        chunk_audio, start_sample = chunk_data

        # Compute spectrogram for this chunk
        spectrogram = self.compute_spectrogram(chunk_audio)

        # Find peaks in this chunk
        peaks = self.find_peaks(spectrogram)

        # Calculate time offset in frames for this chunk
        time_offset_frames = int(start_sample / self.hop_length)

        return peaks, time_offset_frames

    def _process_chunks_parallel(self, chunks: List[Tuple[np.ndarray, int]]) -> List[Tuple[int, int]]:
        """
        Process multiple audio chunks in parallel.
        
        Args:
            chunks: List of (audio_chunk, start_sample) tuples
            
        Returns:
            Combined list of peaks with adjusted time offsets
        """
        all_peaks = []

        # Process chunks in parallel
        self.progress.start(f"Processing {len(chunks)} audio chunks in parallel")
        
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            # Submit all chunks for processing
            future_to_chunk = {
                executor.submit(self._process_chunk, chunk): i
                for i, chunk in enumerate(chunks)
            }

            # Collect results as they complete
            chunk_results = [None] * len(chunks)
            for future in as_completed(future_to_chunk):
                chunk_idx = future_to_chunk[future]
                peaks, time_offset = future.result()
                chunk_results[chunk_idx] = (peaks, time_offset)

        # Combine peaks from all chunks with adjusted time offsets
        self.progress.start("Combining peaks from chunks")
        seen_peaks = set()
        for peaks, time_offset in chunk_results:
            for time_idx, freq_idx in peaks:
                adjusted_time = time_idx + time_offset
                peak_tuple = (adjusted_time, freq_idx)

                # Deduplicate peaks from overlapping regions
                if peak_tuple not in seen_peaks:
                    seen_peaks.add(peak_tuple)
                    all_peaks.append(peak_tuple)

        self.progress.success(f"Found {len(all_peaks)} spectral peaks")
        return all_peaks

    def generate_hashes(self, peaks: List[Tuple[int, int]]) -> List[Tuple[str, int]]:
        """
        Generate hash fingerprints from spectral peaks.
        
        Each hash is created by pairing an anchor peak with nearby peaks in time.
        The hash encodes the frequencies of both peaks and their time difference.
        
        Args:
            peaks: List of (time_index, freq_index) tuples
            
        Returns:
            List of (hash_string, time_offset) tuples
        """
        # Sort peaks by time
        peaks_sorted = sorted(peaks, key=lambda x: x[0])

        hashes = []

        for i, (t1, f1) in enumerate(peaks_sorted):
            # Look for peaks within the target time range
            for j in range(i + 1, len(peaks_sorted)):
                t2, f2 = peaks_sorted[j]

                time_delta = t2 - t1

                # Check if time delta is within valid range
                if time_delta < self.MIN_TIME_DELTA:
                    continue
                if time_delta > self.MAX_TIME_DELTA:
                    break  # No need to check further peaks

                # Limit the number of peaks paired with each anchor
                if j > i + self.FAN_VALUE:
                    break

                # Create hash from peak pair
                # Format: freq1|freq2|time_delta
                hash_string = f"{f1}|{f2}|{time_delta}"

                # Create a more compact hash using SHA1
                hash_obj = hashlib.sha1(hash_string.encode('utf-8'))
                hash_value = hash_obj.hexdigest()[:20]  # Use first 20 chars

                # Store hash with the absolute time of the anchor peak
                hashes.append((hash_value, t1))

        return hashes

    def fingerprint_file(self, filepath: str, use_parallel: bool = True) -> List[Tuple[str, int]]:
        """
        Generate fingerprints for an entire audio file.
        
        Args:
            filepath: Path to the audio file
            use_parallel: If True, use parallel processing for better performance
            
        Returns:
            List of (hash, time_offset) tuples
        """
        # Load audio
        audio = self.load_audio(filepath)

        # Use parallel processing for better performance
        return self.fingerprint_audio(audio, use_parallel=use_parallel)

    def fingerprint_audio(self, audio: np.ndarray, use_parallel: bool = True) -> List[Tuple[str, int]]:
        """
        Generate fingerprints from an audio signal.
        
        Args:
            audio: Audio signal as numpy array
            use_parallel: If True, use parallel processing for better performance
            
        Returns:
            List of (hash, time_offset) tuples
        """
        if use_parallel and len(audio) > self.chunk_duration * self.sample_rate:
            # Use parallel processing for long audio files
            self.progress.start("Using parallel processing for audio")
            chunks = self._split_audio_into_chunks(audio)
            peaks = self._process_chunks_parallel(chunks)
        else:
            # Use sequential processing for short files
            self.progress.start("Computing spectrogram")
            spectrogram = self.compute_spectrogram(audio)
            self.progress.start("Finding spectral peaks")
            peaks = self.find_peaks(spectrogram)
            self.progress.success(f"Found {len(peaks)} spectral peaks")

        # Generate hashes
        self.progress.start("Generating fingerprint hashes")
        hashes = self.generate_hashes(peaks)
        self.progress.success(f"Generated {len(hashes)} fingerprint hashes")

        return hashes
