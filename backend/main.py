import argparse
import numpy as np
import librosa
import soundfile as sf
from scipy import signal
import sys
import math
import os
import tempfile
import json
import requests

# Import F5-TTS API
from f5_tts.api import F5TTS

# Custom F5-TTS model paths
CUSTOM_F5TTS_CHECKPOINT = "./models/experimental.pt"  # Path to custom model checkpoint file
CUSTOM_F5TTS_VOCAB = "./models/main.txt"       # Path to custom vocabulary file

# Local Ollama settings
OLLAMA_MODEL = "phi4"
OLLAMA_LOCAL_URL = "http://localhost:11434/api/generate"

def paulstretch(samplerate, smp, stretch, windowsize_seconds=0.25, onset_level=10.0):
    """
    Paul's Extreme Sound Stretch (Paulstretch) algorithm
    Based on the implementation by Nasca Octavian Paul
    https://github.com/paulnasca/paulstretch_python
    
    Parameters:
    - samplerate: sample rate of the audio
    - smp: audio samples (numpy array)
    - stretch: stretch factor
    - windowsize_seconds: window size in seconds
    - onset_level: onset sensitivity (0.0=max, 1.0=min)
    
    Returns:
    - stretched audio (numpy array)
    """
    # Check if input is mono
    input_is_mono = len(smp.shape) == 1
    
    # If input is mono, convert to stereo format expected by the algorithm
    if input_is_mono:
        smp = np.tile(smp, (2, 1))
    elif len(smp.shape) == 2 and smp.shape[0] > 2:  # Channels in rows format
        smp = smp.T
    
    nchannels = smp.shape[0]
    
    # Make sure that windowsize is even and larger than 16
    windowsize = int(windowsize_seconds * samplerate)
    if windowsize < 16:
        windowsize = 16
    windowsize = int(windowsize / 2) * 2
    half_windowsize = int(windowsize / 2)
    
    # Correct the end of the smp
    nsamples = smp.shape[1]
    end_size = int(samplerate * 0.05)
    if end_size < 16:
        end_size = 16
    
    # Apply fade out at the end
    if nsamples > end_size:
        smp[:, nsamples-end_size:nsamples] *= np.linspace(1, 0, end_size)
    
    # Create Hann window
    window = 0.5 - np.cos(np.arange(windowsize, dtype='float') * 2.0 * math.pi / (windowsize - 1)) * 0.5
    
    # Initialize processing variables
    old_windowed_buf = np.zeros((nchannels, windowsize))
    hinv_sqrt2 = (1 + np.sqrt(0.5)) * 0.5
    hinv_buf = 2.0 * (hinv_sqrt2 - (1.0 - hinv_sqrt2) * np.cos(np.arange(half_windowsize, dtype='float') * 2.0 * math.pi / half_windowsize)) / hinv_sqrt2
    
    freqs = np.zeros((nchannels, half_windowsize + 1), dtype=complex)
    old_freqs = freqs
    
    # For onset detection
    num_bins_scaled_freq = 32
    freqs_scaled = np.zeros(num_bins_scaled_freq)
    old_freqs_scaled = freqs_scaled
    
    # Processing variables
    start_pos = 0.0
    displace_pos = windowsize * 0.5
    
    displace_tick = 0.0
    displace_tick_increase = 1.0 / stretch
    if displace_tick_increase > 1.0:
        displace_tick_increase = 1.0
    
    extra_onset_time_credit = 0.0
    get_next_buf = True
    
    # Output array
    output_length = int(nsamples * stretch)
    output_array = np.zeros((nchannels, output_length))
    output_index = 0
    
    # For progress reporting
    total_progress_steps = int((nsamples - windowsize) / displace_pos)
    progress_counter = 0
    last_progress_percent = -1
    
    # Main processing loop
    while start_pos < nsamples - windowsize:
        # Show progress updates
        progress_percent = int(100.0 * start_pos / nsamples)
        if progress_percent != last_progress_percent and progress_percent % 10 == 0:
            print(f"PaulStretch progress: {progress_percent}%")
            last_progress_percent = progress_percent
            
        if get_next_buf:
            old_freqs = freqs.copy()
            old_freqs_scaled = freqs_scaled.copy()
            
            # Get the windowed buffer
            istart_pos = int(start_pos)
            buf = smp[:, istart_pos:istart_pos+windowsize]
            
            # Apply window
            buf = buf * window
            
            # FFT
            freqs = np.zeros((nchannels, half_windowsize + 1), dtype=complex)
            for channel in range(nchannels):
                freqs[channel, :] = np.fft.rfft(buf[channel, :])
            
            # Calculate the magnitudes of the frequencies
            freqs_mag = np.abs(freqs)
            
            # Calculate scaled frequencies for onset detection
            if num_bins_scaled_freq > 0:
                freqs_scaled = np.zeros(num_bins_scaled_freq)
                for i in range(num_bins_scaled_freq):
                    si = i * half_windowsize // num_bins_scaled_freq
                    ei = ((i + 1) * half_windowsize // num_bins_scaled_freq) - 1
                    if ei < 0:
                        ei = 0
                    if si > half_windowsize:
                        si = half_windowsize
                    
                    # Calculate the average magnitude for this bin
                    bin_sum = 0
                    for channel in range(nchannels):
                        bin_sum += np.sum(freqs_mag[channel, si:ei+1])
                    bin_sum /= (ei - si + 1) * nchannels
                    freqs_scaled[i] = bin_sum
            
            # Onset detection
            onset = 0.0
            if num_bins_scaled_freq > 0:
                # Calculate onset detection function
                sum1 = sum2 = 0.0
                for i in range(num_bins_scaled_freq):
                    sum1 += abs(freqs_scaled[i])
                    sum2 += abs(old_freqs_scaled[i])
                
                if sum2 > 1e-10:
                    onset = sum1 / sum2
                else:
                    onset = 1.0
                
                if onset > onset_level:
                    displace_tick = 1.0
                    extra_onset_time_credit += 1.0
        
        # Interpolate between the old and new frequencies
        cfreqs = np.zeros((nchannels, half_windowsize + 1), dtype=complex)
        for channel in range(nchannels):
            cfreqs[channel, :] = (freqs[channel, :] * displace_tick) + (old_freqs[channel, :] * (1.0 - displace_tick))
        
        # Randomize the phases by multiplication with a random complex number with modulus=1
        ph = np.random.uniform(0, 2 * math.pi, (nchannels, half_windowsize + 1)) * 1j
        cfreqs = cfreqs * np.exp(ph)
        
        # Do the inverse FFT for each channel
        buf = np.zeros((nchannels, windowsize))
        for channel in range(nchannels):
            buf[channel, :] = np.fft.irfft(cfreqs[channel, :])
        
        # Window again the output buffer
        buf = buf * window
        
        # Overlap-add the output
        output = np.zeros((nchannels, half_windowsize))
        for channel in range(nchannels):
            output[channel, :] = buf[channel, :half_windowsize] + old_windowed_buf[channel, half_windowsize:]
        old_windowed_buf = buf
        
        # Remove the resulted amplitude modulation
        output = output * hinv_buf
        
        # Clamp the values to -1..1
        output = np.clip(output, -1.0, 1.0)
        
        # Store the output
        if output_index + half_windowsize <= output_length:
            output_array[:, output_index:output_index + half_windowsize] = output
            output_index += half_windowsize
        
        if get_next_buf:
            start_pos += displace_pos
            get_next_buf = False
        
        # Advance the displacement tick and handle onsets
        if extra_onset_time_credit <= 0.0:
            displace_tick += displace_tick_increase
        else:
            credit_get = 0.5 * displace_tick_increase
            extra_onset_time_credit -= credit_get
            if extra_onset_time_credit < 0:
                extra_onset_time_credit = 0
            displace_tick += displace_tick_increase - credit_get
        
        if displace_tick >= 1.0:
            displace_tick = displace_tick % 1.0
            get_next_buf = True
    
    # Return the same format (mono/stereo) as the input
    if input_is_mono:
        return output_array[0]  # Return only first channel if input was mono
    else:
        return output_array.T if output_array.shape[0] <= 2 else output_array

def process_audio(input_path, background_path, output_path, time_resolution=0.25, bg_gain_db=20):
    """
    Process audio for meditation by:
    1. Loading the input audio and ambient background
    2. Stretching the background to match input length
    3. Adjusting background volume
    4. Merging the two audio files to create a meditative atmosphere
    5. Saving the result
    """
    print(f"Loading meditation voice audio: {input_path}")
    input_audio, sr = librosa.load(input_path, sr=None)
    
    print(f"Loading ambient background audio: {background_path}")
    bg_audio, bg_sr = librosa.load(background_path, sr=None)
    
    # Check if input is mono or stereo
    input_is_mono = len(input_audio.shape) == 1
    print(f"Input audio format: {'mono' if input_is_mono else 'stereo'}")
    
    # Resample background if needed
    if bg_sr != sr:
        print(f"Resampling background from {bg_sr}Hz to {sr}Hz")
        bg_audio = librosa.resample(bg_audio, orig_sr=bg_sr, target_sr=sr)
    
    # Calculate stretch factor to match input length
    stretch_factor = len(input_audio) / len(bg_audio)
    print(f"Stretching background by factor: {stretch_factor}")
    
    # Apply paulstretch to the background
    print("Applying PaulStretch algorithm to create immersive background (this may take a while)...")
    stretched_bg = paulstretch(sr, bg_audio, stretch_factor, time_resolution)
    print("PaulStretch complete!")
    
    # Trim or pad to exact length
    print("Adjusting stretched background to match meditation audio length...")
    if len(stretched_bg) > len(input_audio):
        if len(stretched_bg.shape) > 1:  # If stereo
            stretched_bg = stretched_bg[:len(input_audio), :]
        else:  # If mono
            stretched_bg = stretched_bg[:len(input_audio)]
    elif len(stretched_bg) < len(input_audio):
        if len(stretched_bg.shape) > 1:  # If stereo
            pad_width = ((0, len(input_audio) - len(stretched_bg)), (0, 0))
            stretched_bg = np.pad(stretched_bg, pad_width)
        else:  # If mono
            stretched_bg = np.pad(stretched_bg, (0, len(input_audio) - len(stretched_bg)))
    
    # Adjust background volume (+20dB)
    gain_factor = 10 ** (bg_gain_db / 20)
    print(f"Adjusting ambient background volume: +{bg_gain_db}dB (factor: {gain_factor})")
    stretched_bg = stretched_bg * gain_factor
    
    # Print shape information for debugging
    print(f"Meditation audio shape: {input_audio.shape}")
    print(f"Stretched background shape: {stretched_bg.shape}")
    
    # Make sure both audio signals have the same number of channels
    if input_is_mono and len(stretched_bg.shape) > 1:
        print("Converting stretched background to mono to match meditation audio")
        # Convert stereo to mono by averaging channels
        stretched_bg = np.mean(stretched_bg, axis=1)
    elif not input_is_mono and len(stretched_bg.shape) == 1:
        print("Converting stretched background to stereo to match meditation audio")
        # Convert mono to stereo by duplicating the channel
        stretched_bg = np.column_stack((stretched_bg, stretched_bg))
    
    print(f"Final shapes - Meditation: {input_audio.shape}, Background: {stretched_bg.shape}")
    
    # Mix audio files (ensuring no clipping)
    print("Creating meditation audio by mixing voice with ambient background...")
    mixed_audio = input_audio + stretched_bg
    
    # Normalize if needed to prevent clipping
    max_amplitude = np.max(np.abs(mixed_audio))
    if max_amplitude > 1.0:
        print(f"Normalizing output (max amplitude was {max_amplitude})")
        mixed_audio = mixed_audio / max_amplitude
    
    # Save output
    print(f"Saving meditation to: {output_path}")
    sf.write(output_path, mixed_audio, sr)
    print("Meditation generation complete!")

def generate_tts(text, output_path, ref_audio=None, ref_text=None, 
                 model_type="F5-TTS", vocoder_name="vocos", device=None,
                 cfg_strength=2, nfe_step=64, speed=1.0, seed=-1,
                 sway_sampling_coef=-1, target_rms=0.1, cross_fade_duration=1,
                 fix_duration=None, remove_silence=True, use_ema=True):
    """
    Generate meditation voice from text using F5-TTS.
    
    Parameters:
    - text: Meditation text to convert to speech
    - output_path: Where to save the generated audio
    - ref_audio: Optional reference audio file for voice cloning (if None, uses default voice)
    - ref_text: Optional transcription of reference audio (if None and ref_audio provided, will attempt auto-transcription)
    
    F5-TTS Model Initialization Parameters:
    - model_type: Model architecture to use. Options:
        - "F5-TTS" (Default): DiT architecture with ConvNeXt V2, faster trained and inference
        - "E2-TTS": Flat-UNet Transformer, reproduction from paper
    - vocoder_name: Vocoder to use for waveform generation. Options:
        - "vocos" (Default): Higher quality, lightweight vocoder
        - "bigvgan": Alternative vocoder
    - device: Device to run inference on:
        - None (Auto-select): CUDA > XPU > MPS > CPU
        - "cuda": NVIDIA GPU
        - "xpu": Intel GPU
        - "mps": Apple Silicon
        - "cpu": CPU only (slowest)
    - use_ema: Whether to use EMA (Exponential Moving Average) weights (default=True)
        - True: Better quality for well-trained models
        - False: May work better for early-stage finetuned models
    
    F5-TTS Generation Parameters:
    - cfg_strength: Classifier-free guidance strength (default=2)
        - Higher values (2-5): More faithful to text content
        - Lower values (0.5-1.5): More similar to reference voice
    - nfe_step: Number of flow matching steps (default=64)
        - Higher values (48-64): Better quality but slower
        - Lower values (16-24): Faster but potentially lower quality
    - speed: Speech generation speed multiplier (default=1.0)
        - 0.8: Slower speech
        - 1.2: Faster speech
    - seed: Random seed for reproducibility (default=-1)
        - -1: Random seed each time
        - Any integer: Fixed seed for reproducible generation
    - sway_sampling_coef: Sway sampling coefficient (default=-1)
        - -1: Disabled
        - Values > 0: Enables sway sampling (improves quality)
        - Recommended values: 0.2-0.5
    - target_rms: Target RMS amplitude for audio normalization (default=0.1)
    - cross_fade_duration: Duration of cross-fade for chunked generation in seconds (default=1)
    - fix_duration: Fixed duration for generated audio in seconds (default=None)
        - None: Natural duration based on content
        - Float value: Force specific duration
    - remove_silence: Whether to remove silence from generated audio (default=True)
    
    Returns:
    - Path to the generated meditation voice audio file
    """
    print(f"Initializing F5-TTS model for meditation voice...")
    tts = F5TTS(
        model_type=model_type,
        vocoder_name=vocoder_name,
        device=device,
        use_ema=use_ema,
        ckpt_file=CUSTOM_F5TTS_CHECKPOINT,
        vocab_file=CUSTOM_F5TTS_VOCAB,
    )
    
    # Determine reference audio and text
    if ref_audio and not ref_text:
        print(f"Transcribing reference audio...")
        ref_text = tts.transcribe(ref_audio)
        print(f"Transcription: {ref_text}")
    
    # Use default example if no reference provided
    if not ref_audio:
        # Use the reference files from samples directory
        ref_audio = "samples/ref.wav"
        # Read reference text from file
        try:
            with open("samples/ref.reference.txt", "r") as f:
                ref_text = f.read().strip()
        except FileNotFoundError:
            # Fallback if file is missing
            ref_text = "some call me nature, others call me mother nature."
        print(f"Using reference audio from samples/ref.wav with accompanying text")
    
    print(f"Generating meditation voice from text: '{text}'")
    wav, sr, _ = tts.infer(
        ref_file=ref_audio,
        ref_text=ref_text,
        gen_text=text,
        file_wave=output_path,
        cfg_strength=cfg_strength,          # Controls text fidelity vs voice similarity
        nfe_step=nfe_step,                  # Number of flow matching steps
        speed=0.8,                          # Speech speed multiplier hardcoded to 0.7
        seed=seed,                          # Random seed for reproducibility
        sway_sampling_coef=sway_sampling_coef,  # Sway sampling for improved quality
        target_rms=target_rms,              # Target RMS amplitude
        cross_fade_duration=1,  # Cross-fade duration for chunks hardcoded to 1 second
        fix_duration=fix_duration,          # Fixed duration (if specified)
        remove_silence=True,                # Always remove silence regardless of input parameter
    )
    
    print(f"Generated meditation voice saved to: {output_path}")
    return output_path

def generate_meditation_from_text(text, background_path, output_path, ref_audio=None, ref_text=None, 
                           time_resolution=0.25, bg_gain_db=20, model_type="F5-TTS", 
                           vocoder_name="vocos", cfg_strength=2, nfe_step=64, speed=1.0, 
                           seed=-1, sway_sampling_coef=-1, use_ema=True):
    """
    Generate a complete meditation by:
    1. Converting meditation text to speech using F5-TTS
    2. Processing the generated voice with ambient background sounds
    
    Parameters:
    - text: Meditation text to convert to speech
    - background_path: Path to ambient background audio file
    - output_path: Path to save the final meditation
    - ref_audio: Optional reference audio for voice cloning
    - ref_text: Optional transcription of reference audio
    - time_resolution: Time resolution for paulstretch
    - bg_gain_db: Background gain in dB
    
    TTS Parameters:
    - model_type: F5-TTS model type ("F5-TTS" or "E2-TTS")
    - vocoder_name: Vocoder to use ("vocos" or "bigvgan")
    - cfg_strength: Classifier-free guidance strength (default=2)
    - nfe_step: Number of flow matching steps (default=64)
    - speed: Speech generation speed multiplier (default=1.0)
    - seed: Random seed for reproducibility (default=-1)
    - sway_sampling_coef: Sway sampling coefficient (default=-1, disabled)
    - use_ema: Whether to use EMA weights (default=True)
    """
    # Create a temporary file for the TTS output
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
        tts_output_path = temp_file.name
    
    try:
        # Generate TTS audio for meditation voice
        generate_tts(
            text, 
            tts_output_path, 
            ref_audio, 
            ref_text,
            model_type=model_type,
            vocoder_name=vocoder_name,
            cfg_strength=cfg_strength,
            nfe_step=nfe_step,
            speed=speed,
            seed=seed,
            sway_sampling_coef=sway_sampling_coef,
            use_ema=use_ema
        )
        
        # Process the generated voice with ambient background
        process_audio(tts_output_path, background_path, output_path, time_resolution, bg_gain_db)
        
    finally:
        # Clean up the temporary file
        if os.path.exists(tts_output_path):
            os.remove(tts_output_path)

def generate_meditation_script(user_worry):
    """
    Generate a guided meditation script based on the user's worry using local Ollama instance.
    Streams the output in real-time to show progress.
    
    Parameters:
    - user_worry: String containing what the user is worried about
    
    Returns:
    - A guided meditation script
    """
    prompt = f"""
    You are a professional meditation guide. Create a detailed, comprehensive guided meditation script (approximately 1200 words) that helps with the following concern:
    
    "{user_worry}"
    
    The meditation should:
    1. Use a warm, gentle, and soothing tone
    2. Have a clear beginning, middle, and end with thorough guidance throughout
    3. Include detailed breathing guidance and visualization exercises
    4. Take the listener on a journey to help them find deep peace with their concern
    5. Include extended periods of guided relaxation for each part of the body
    6. End with positive affirmations and empowering statements
    7. Be approximately 1200 words in length to provide a complete 15-20 minute meditation experience
    
    Write ONLY the meditation script without any additional explanations or headers, and do not greet the user (No "Hello, I'm a meditation guide..." or anything like that).
    """
    
    print(f"Generating comprehensive personalized meditation script using local {OLLAMA_MODEL} model...")
    print("Streaming output as it's generated:\n" + "-" * 50)
    
    # Connect to local Ollama instance with streaming enabled
    try:
        full_response = ""
        response = requests.post(
            OLLAMA_LOCAL_URL,
            json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "stream": True
            },
            stream=True,
            timeout=180  # Increase timeout for longer generation
        )
        
        # Process the stream
        for line in response.iter_lines():
            if line:
                # Parse the JSON from each line
                chunk = json.loads(line.decode('utf-8'))
                if 'response' in chunk:
                    text_chunk = chunk['response']
                    full_response += text_chunk
                    # Print the chunk without a newline to create a continuous stream effect
                    print(text_chunk, end='', flush=True)
                
                # Check if we're done
                if chunk.get('done', False):
                    break
        
        print("\n" + "-" * 50)
        word_count = len(full_response.split())
        print(f"Meditation script generated successfully ({word_count} words)")
        
        return full_response
    except requests.exceptions.Timeout:
        print("\nError: Connection to Ollama timed out. Please check if Ollama is running with:")
        print("  ollama serve")
        print(f"  ollama pull {OLLAMA_MODEL}")
        print("Try again with a shorter timeout or ensure Ollama is responding.")
        sys.exit(1)
    except requests.exceptions.ConnectionError:
        print("\nError: Could not connect to Ollama at localhost:11434.")
        print("Please ensure Ollama is running with: ollama serve")
        sys.exit(1)
    except Exception as e:
        print(f"\nUnexpected error: {str(e)}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Meditation Generator: Create personalized audio meditations.")
    
    # Create subparsers for different modes
    subparsers = parser.add_subparsers(dest="mode", help="Mode of operation")
    
    # Parser for audio processing mode
    audio_parser = subparsers.add_parser("audio", help="Create meditation from an existing voice recording")
    audio_parser.add_argument("input_file", help="Input voice recording WAV file")
    audio_parser.add_argument("--output", "-o", default="meditation_output.wav", help="Output meditation WAV file")
    audio_parser.add_argument("--background", "-b", default="samples/breakfill.wav", help="Ambient background WAV file")
    audio_parser.add_argument("--time-resolution", "-t", type=float, default=0.25, help="Time resolution for ambient background stretching in seconds")
    audio_parser.add_argument("--bg-gain", "-g", type=float, default=20, help="Background gain in dB")
    
    # Parser for text-to-speech mode
    text_parser = subparsers.add_parser("text", help="Create meditation from text")
    text_parser.add_argument("text", help="Meditation text to convert to speech")
    text_parser.add_argument("--output", "-o", default="meditation_output.wav", help="Output meditation WAV file")
    text_parser.add_argument("--background", "-b", default="samples/breakfill.wav", help="Ambient background WAV file")
    text_parser.add_argument("--ref-audio", "-r", default="samples/ref.wav", help="Reference audio for voice cloning (default: samples/ref.wav)")
    text_parser.add_argument("--ref-text", default=None, help="Reference text transcription (default: read from samples/ref.reference.txt)")
    text_parser.add_argument("--time-resolution", "-t", type=float, default=0.25, help="Time resolution for ambient background stretching in seconds")
    text_parser.add_argument("--bg-gain", "-g", type=float, default=20, help="Background gain in dB")
    text_parser.add_argument("--model-type", default="F5-TTS", choices=["F5-TTS", "E2-TTS"], help="TTS model architecture")
    text_parser.add_argument("--vocoder", default="vocos", choices=["vocos", "bigvgan"], help="Vocoder to use")
    text_parser.add_argument("--cfg-strength", type=float, default=2.0, help="Classifier-free guidance strength (higher = more text faithful)")
    text_parser.add_argument("--nfe-step", type=int, default=64, help="Number of flow matching steps (higher = better quality but slower)")
    text_parser.add_argument("--speed", type=float, default=0.9, help="Speech speed multiplier (default: 0.9 for slower, calming pace)")
    text_parser.add_argument("--seed", type=int, default=-1, help="Random seed (-1 for random)")
    text_parser.add_argument("--sway-sampling", type=float, default=-1, help="Sway sampling coefficient (>0 to enable)")
    text_parser.add_argument("--use-ema", action="store_true", default=True, help="Use EMA weights for the model")
    
    # Parser for personalized meditation mode
    personalized_parser = subparsers.add_parser("personalized", help="Create personalized meditation from a description of your worries")
    personalized_parser.add_argument("worry", help="Description of what's worrying you")
    personalized_parser.add_argument("--output", "-o", default="meditation_output.wav", help="Output meditation WAV file")
    personalized_parser.add_argument("--background", "-b", default="samples/breakfill.wav", help="Ambient background WAV file")
    personalized_parser.add_argument("--ref-audio", "-r", default="samples/ref.wav", help="Reference audio for voice cloning")
    personalized_parser.add_argument("--ref-text", default=None, help="Reference text transcription")
    personalized_parser.add_argument("--time-resolution", "-t", type=float, default=0.25, help="Time resolution for ambient background stretching in seconds")
    personalized_parser.add_argument("--bg-gain", "-g", type=float, default=20, help="Background gain in dB")
    personalized_parser.add_argument("--model-type", default="F5-TTS", choices=["F5-TTS", "E2-TTS"], help="TTS model architecture")
    personalized_parser.add_argument("--vocoder", default="vocos", choices=["vocos", "bigvgan"], help="Vocoder to use")
    personalized_parser.add_argument("--cfg-strength", type=float, default=2.0, help="Classifier-free guidance strength")
    personalized_parser.add_argument("--nfe-step", type=int, default=64, help="Number of flow matching steps")
    personalized_parser.add_argument("--speed", type=float, default=0.9, help="Speech speed multiplier")
    personalized_parser.add_argument("--seed", type=int, default=-1, help="Random seed (-1 for random)")
    personalized_parser.add_argument("--sway-sampling", type=float, default=-1, help="Sway sampling coefficient")
    personalized_parser.add_argument("--use-ema", action="store_true", default=True, help="Use EMA weights for the model")
    
    args = parser.parse_args()
    
    if args.mode == "audio" or args.mode is None:  # Default to audio mode for backwards compatibility
        process_audio(
            args.input_file, 
            args.background, 
            args.output, 
            args.time_resolution,
            args.bg_gain
        )
    elif args.mode == "text":
        generate_meditation_from_text(
            args.text,
            args.background,
            args.output,
            args.ref_audio,
            args.ref_text,
            args.time_resolution,
            args.bg_gain,
            args.model_type,
            args.vocoder,
            args.cfg_strength,
            args.nfe_step,
            args.speed,
            args.seed,
            args.sway_sampling,
            args.use_ema
        )
    elif args.mode == "personalized":
        # Use the command line argument directly
        user_worry = args.worry
        
        # Generate meditation script from user input
        meditation_script = generate_meditation_script(user_worry)
        
        # Generate audio meditation
        generate_meditation_from_text(
            meditation_script,
            args.background,
            args.output,
            args.ref_audio,
            args.ref_text,
            args.time_resolution,
            args.bg_gain,
            args.model_type,
            args.vocoder,
            args.cfg_strength,
            args.nfe_step,
            args.speed,
            args.seed,
            args.sway_sampling,
            args.use_ema
        )
        
        print(f"\nYour personalized meditation has been created: {args.output}")
        print("Meditation script:")
        print("-" * 50)
        print(meditation_script)
        print("-" * 50)

if __name__ == "__main__":
    main() 