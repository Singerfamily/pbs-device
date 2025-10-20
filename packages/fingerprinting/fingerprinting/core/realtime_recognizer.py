"""
Real-Time Audio Recognition Module

This module implements real-time audio recognition by continuously capturing
audio from a microphone and matching it against the fingerprint database.
"""

import numpy as np
import sounddevice as sd
from typing import Optional, Callable, List, Dict
from collections import deque
import threading
import time
from fingerprint import AudioFingerprinter
from database import FingerprintDatabase
from utils.logger import setup_logger, ProgressLogger


class RealtimeRecognizer:
    """Recognize audio in real-time from microphone input."""
    
    def __init__(
        self,
        dbname: str = "hymn_fingerprints",
        user: str = "postgres",
        password: str = "postgres",
        host: str = "localhost",
        port: int = 5432,
        sample_rate: int = 22050,
        buffer_duration: float = 5.0,
        recognition_interval: float = 2.0,
        min_confidence: float = 10.0
    ):
        """
        Initialize the real-time recognizer.
        
        Args:
            dbname: PostgreSQL database name
            user: PostgreSQL user
            password: PostgreSQL password
            host: PostgreSQL host
            port: PostgreSQL port
            sample_rate: Audio sample rate (should match fingerprinter)
            buffer_duration: Duration of audio buffer in seconds (how much audio to analyze)
            recognition_interval: How often to attempt recognition in seconds
            min_confidence: Minimum confidence threshold to report matches
        """
        self.sample_rate = sample_rate
        self.buffer_duration = buffer_duration
        self.recognition_interval = recognition_interval
        self.min_confidence = min_confidence
        
        # Initialize fingerprinter and database
        self.fingerprinter = AudioFingerprinter()
        self.database = FingerprintDatabase(
            dbname=dbname,
            user=user,
            password=password,
            host=host,
            port=port
        )
        
        # Audio buffer - circular buffer to store recent audio
        buffer_samples = int(buffer_duration * sample_rate)
        self.audio_buffer = deque(maxlen=buffer_samples)
        
        # Recognition state
        self.is_running = False
        self.recognition_thread = None
        self.audio_stream = None
        self.last_recognition_time = 0
        
        # Callback for match results
        self.match_callback: Optional[Callable[[List[Dict]], None]] = None
        
        # Lock for thread-safe buffer access
        self.buffer_lock = threading.Lock()
    
    def _audio_callback(self, indata, frames, time_info, status):
        """
        Callback function for audio stream.
        Called by sounddevice when new audio data is available.
        
        Args:
            indata: Input audio data
            frames: Number of frames
            time_info: Time information
            status: Stream status
        """
        if status:
            print(f"Audio stream status: {status}")
        
        # Convert to mono if stereo
        if len(indata.shape) > 1:
            audio_data = indata[:, 0]
        else:
            audio_data = indata[:, 0] if len(indata.shape) > 1 else indata
        
        # Add to buffer (thread-safe)
        with self.buffer_lock:
            self.audio_buffer.extend(audio_data.flatten())
    
    def _recognition_loop(self):
        """
        Background thread that periodically processes the audio buffer
        and attempts to recognize the audio.
        """
        while self.is_running:
            current_time = time.time()
            
            # Check if enough time has passed since last recognition
            if current_time - self.last_recognition_time >= self.recognition_interval:
                self.last_recognition_time = current_time
                
                # Get current buffer content (thread-safe)
                with self.buffer_lock:
                    if len(self.audio_buffer) < self.sample_rate * 2:  # Need at least 2 seconds
                        continue
                    audio_data = np.array(self.audio_buffer, dtype=np.float32)
                
                try:
                    # Generate fingerprints for the buffered audio
                    fingerprints = self.fingerprinter.fingerprint_audio(
                        audio_data,
                        use_parallel=False  # Don't use parallel for real-time
                    )
                    
                    if not fingerprints:
                        continue
                    
                    # Match against database
                    raw_matches = self.database.get_matches(fingerprints)
                    
                    if not raw_matches:
                        continue
                    
                    # Score matches (simplified version of recognizer._match_fingerprints)
                    from collections import Counter
                    matches = []
                    
                    for hymn_number, time_diffs in raw_matches.items():
                        time_diff_counter = Counter(time_diffs)
                        most_common_diff, aligned_matches = time_diff_counter.most_common(1)[0]
                        
                        # Calculate confidence
                        total_query_fingerprints = len(fingerprints)
                        coverage_score = aligned_matches / total_query_fingerprints if total_query_fingerprints > 0 else 0
                        confidence = coverage_score * 100
                        
                        # Only report if above minimum confidence
                        if confidence >= self.min_confidence:
                            song_info = self.database.get_song_info(hymn_number)
                            
                            if song_info:
                                matches.append({
                                    'hymn_number': hymn_number,
                                    'title': song_info['title'],
                                    'confidence': round(confidence, 2),
                                    'aligned_matches': aligned_matches,
                                    'timestamp': current_time
                                })
                    
                    # Sort by confidence
                    matches.sort(key=lambda x: x['confidence'], reverse=True)
                    
                    # Call callback if we have matches
                    if matches and self.match_callback:
                        self.match_callback(matches)
                
                except Exception as e:
                    print(f"Error during recognition: {e}")
            
            # Sleep briefly to avoid busy-waiting
            time.sleep(0.1)
    
    def start(self, match_callback: Optional[Callable[[List[Dict]], None]] = None):
        """
        Start real-time audio recognition.
        
        Args:
            match_callback: Optional callback function that receives match results.
                           Called with a list of match dictionaries when matches are found.
        """
        if self.is_running:
            print("Real-time recognition is already running")
            return
        
        self.match_callback = match_callback
        self.is_running = True
        self.last_recognition_time = time.time()
        
        # Start audio stream
        print(f"Starting audio capture (sample rate: {self.sample_rate} Hz)")
        print(f"Buffer duration: {self.buffer_duration}s")
        print(f"Recognition interval: {self.recognition_interval}s")
        print(f"Minimum confidence: {self.min_confidence}%")
        print("\nListening...")
        
        self.audio_stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=1,
            callback=self._audio_callback,
            blocksize=2048
        )
        self.audio_stream.start()
        
        # Start recognition thread
        self.recognition_thread = threading.Thread(
            target=self._recognition_loop,
            daemon=True
        )
        self.recognition_thread.start()
    
    def stop(self):
        """Stop real-time audio recognition."""
        if not self.is_running:
            return
        
        print("\nStopping real-time recognition...")
        self.is_running = False
        
        # Stop audio stream
        if self.audio_stream:
            self.audio_stream.stop()
            self.audio_stream.close()
            self.audio_stream = None
        
        # Wait for recognition thread to finish
        if self.recognition_thread:
            self.recognition_thread.join(timeout=2.0)
            self.recognition_thread = None
        
        print("Stopped")
    
    def run_interactive(self):
        """
        Run in interactive mode with console output.
        Blocks until user presses Ctrl+C.
        """
        def print_matches(matches: List[Dict]):
            """Print match results to console."""
            if not matches:
                return
            
            # Clear line and print timestamp
            timestamp = time.strftime("%H:%M:%S")
            print(f"\n[{timestamp}] Match found!")
            
            # Print top match
            top_match = matches[0]
            print(f"  🎵 {top_match['title']}")
            print(f"  📊 Confidence: {top_match['confidence']:.1f}%")
            print(f"  🎯 Aligned matches: {top_match['aligned_matches']}")
            
            # Print other matches if confidence is high enough
            if len(matches) > 1 and matches[1]['confidence'] > self.min_confidence * 0.8:
                print(f"\n  Other possible matches:")
                for match in matches[1:4]:  # Show up to 3 more
                    print(f"    • {match['title']} ({match['confidence']:.1f}%)")
            
            print()
        
        try:
            self.start(match_callback=print_matches)
            
            # Keep running until interrupted
            print("\nPress Ctrl+C to stop...\n")
            while self.is_running:
                time.sleep(0.5)
        
        except KeyboardInterrupt:
            print("\n\nInterrupted by user")
        
        finally:
            self.stop()
    
    def list_audio_devices(self):
        """List available audio input devices."""
        print("\nAvailable audio input devices:")
        print("-" * 80)
        devices = sd.query_devices()
        for i, device in enumerate(devices):
            if device['max_input_channels'] > 0:
                print(f"{i}: {device['name']}")
                print(f"   Channels: {device['max_input_channels']} in")
                print(f"   Sample rate: {device['default_samplerate']} Hz")
                print()
    
    def set_audio_device(self, device_id: int):
        """
        Set the audio input device to use.
        
        Args:
            device_id: Device ID from list_audio_devices()
        """
        sd.default.device = device_id
        print(f"Set audio input device to: {sd.query_devices(device_id)['name']}")
