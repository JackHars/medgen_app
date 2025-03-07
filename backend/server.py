from flask import Flask, request, jsonify, send_file, redirect
from flask_cors import CORS
import os
import tempfile
import uuid
import threading
import json
import traceback
import sys
from main import generate_meditation_script, generate_meditation_from_text, generate_tts, process_audio
import time
import argparse
import secrets
import hashlib

app = Flask(__name__)
CORS(app)  # Enable Cross-Origin Resource Sharing

# Directory to store generated meditations
UPLOAD_FOLDER = 'generated_meditations'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# In-memory job status tracking
jobs = {}

# API Security configuration
API_KEY_FILE = os.path.join(os.path.dirname(__file__), 'api_key.txt')
API_KEY = None

def load_or_generate_api_key():
    """Load existing API key or generate a new one if it doesn't exist"""
    global API_KEY
    if os.path.exists(API_KEY_FILE):
        with open(API_KEY_FILE, 'r') as f:
            API_KEY = f.read().strip()
    else:
        # Generate a new secure API key
        API_KEY = secrets.token_hex(32)  # 64 character hex string
        with open(API_KEY_FILE, 'w') as f:
            f.write(API_KEY)
    
    # Also create a hashed version for comparison
    return API_KEY

def require_api_key(func):
    """Decorator to require API key for routes when API_KEY is set and host is not localhost"""
    def wrapper(*args, **kwargs):
        # Skip authentication if API_KEY is not set or if request is from localhost
        if API_KEY is None or request.remote_addr in ('127.0.0.1', 'localhost'):
            return func(*args, **kwargs)
        
        # Check for API key in headers
        request_api_key = request.headers.get('X-API-Key')
        if not request_api_key:
            return jsonify({'error': 'API key required'}), 401
        
        # Validate API key
        if request_api_key != API_KEY:
            return jsonify({'error': 'Invalid API key'}), 403
        
        return func(*args, **kwargs)
    
    # Preserve the original function name and docstring
    wrapper.__name__ = func.__name__
    wrapper.__doc__ = func.__doc__
    return wrapper

@app.route('/')
@require_api_key
def index():
    """
    Root route that provides information about the API and redirects to the web application
    """
    return jsonify({
        'name': 'Oneiro Meditation Generator API',
        'status': 'running',
        'message': 'This is the API server. The web application is available at http://127.0.0.1:8080'
    })

@app.route('/api/generate-meditation', methods=['POST'])
@require_api_key
def generate_meditation():
    """
    API endpoint to generate a meditation from a user's worry.
    Returns a job ID for polling the status.
    """
    try:
        print(f"Received meditation generation request: {request.method}")
        
        # Check if request contains JSON
        if not request.is_json:
            print("Error: Request did not contain valid JSON")
            return jsonify({'error': 'Request must be JSON'}), 400
            
        data = request.json
        print(f"Request data: {data}")
        
        user_worry = data.get('worry', '')
        
        if not user_worry:
            print("Error: No worry description provided")
            return jsonify({'error': 'No worry description provided'}), 400
        
        # Create a unique job ID
        job_id = str(uuid.uuid4())
        print(f"Created job ID: {job_id}")
        
        # Set initial job status
        jobs[job_id] = {
            'status': 'pending',
            'progress': 0,
            'meditation_script': '',
            'audio_url': None
        }
        
        # Run meditation generation in a background thread
        thread = threading.Thread(
            target=process_meditation_job,
            args=(job_id, user_worry)
        )
        thread.daemon = True
        thread.start()
        
        print(f"Started background job for {job_id}")
        return jsonify({
            'job_id': job_id,
            'status': 'pending',
            'message': 'Meditation generation started'
        })
        
    except Exception as e:
        error_details = traceback.format_exc()
        print(f"Error in generate_meditation: {str(e)}")
        print(f"Traceback: {error_details}")
        return jsonify({
            'error': str(e),
            'details': error_details
        }), 500

def generate_meditation_from_text_with_progress(text, background_path, output_path, progress_callback=None, **kwargs):
    """
    Wrapper for generate_meditation_from_text that adds progress reporting.
    
    Args:
        text: The meditation script text
        background_path: Path to background audio file
        output_path: Where to save the output audio
        progress_callback: Function to call with progress updates
        **kwargs: Additional arguments to pass to generate_meditation_from_text
    """
    # Start by estimating text chunks
    # Average English word is about 5 characters
    # F5 processes roughly about 25 words per chunk (estimate)
    words = text.split()
    total_words = len(words)
    estimated_chunks = max(1, total_words // 25)
    
    # Report initial setup
    if progress_callback:
        progress_callback('initializing')
    
    # Report text chunking step
    if progress_callback:
        progress_callback('chunking')
    
    # Create a temporary file for the TTS output
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
        tts_output_path = temp_file.name
    
    try:
        # This is where the actual F5 TTS processing happens
        # Since we can't directly hook into each batch processing,
        # we'll simulate progress updates based on text length
        
        # Initialize F5-TTS and other setup
        if progress_callback:
            progress_callback('processing', 1, estimated_chunks)
        
        # Create a simulated chunk_monitor thread that updates progress
        # while the TTS process is running
        stop_monitor = False
        
        def chunk_monitor():
            chunk = 1
            while not stop_monitor and chunk < estimated_chunks:
                time.sleep(max(0.5, 60 / estimated_chunks))  # Sleep time based on estimated chunks
                if progress_callback:
                    # Only update if we haven't reached the end
                    if chunk < estimated_chunks:
                        chunk += 1
                        progress_callback('processing', chunk, estimated_chunks)
        
        # Start the monitor thread
        if progress_callback:
            monitor_thread = threading.Thread(target=chunk_monitor)
            monitor_thread.daemon = True
            monitor_thread.start()
        
        try:
            # Generate the TTS audio 
            generate_tts(
                text, 
                tts_output_path, 
                # Pass through any relevant kwargs
                **{k: v for k, v in kwargs.items() if k in [
                    'ref_audio', 'ref_text', 'model_type', 'vocoder_name',
                    'cfg_strength', 'nfe_step', 'speed', 'seed',
                    'sway_sampling_coef', 'use_ema'
                ]}
            )
        finally:
            # Signal the monitor thread to stop
            stop_monitor = True
            if progress_callback:
                # Ensure we report completion of processing stage
                progress_callback('processing', estimated_chunks, estimated_chunks)
        
        # Report post-processing stage
        if progress_callback:
            progress_callback('post_processing')
            
        # Process audio with background
        process_audio(tts_output_path, background_path, output_path, 
                     time_resolution=kwargs.get('time_resolution', 0.25),
                     bg_gain_db=kwargs.get('bg_gain_db', 20))
        
        return output_path
        
    finally:
        # Clean up temporary file
        if os.path.exists(tts_output_path):
            try:
                os.remove(tts_output_path)
            except:
                pass

def process_meditation_job(job_id, user_worry):
    """
    Background process to generate meditation script and audio.
    Updates job status as it progresses.
    """
    try:
        print(f"Processing job {job_id} with worry: {user_worry[:30]}...")
        
        # Step 1: Initialize job (5%)
        jobs[job_id]['status'] = 'initializing'
        jobs[job_id]['progress'] = 5
        
        # Step 2: Preparing to generate script (10%)
        print(f"Preparing to generate meditation script for job {job_id}")
        jobs[job_id]['status'] = 'generating_script'
        jobs[job_id]['progress'] = 10
        
        # Step 3: Generating meditation script (15-35%)
        # Start script generation
        print(f"Generating meditation script for job {job_id}")
        
        # Update progress to 15% to indicate script generation started
        jobs[job_id]['progress'] = 15
        
        # Generate script
        meditation_script = generate_meditation_script(user_worry)
        print(f"Script generated successfully (length: {len(meditation_script)})")
        
        # Store the script and update progress to 35%
        jobs[job_id]['meditation_script'] = meditation_script
        jobs[job_id]['progress'] = 35
        
        # Step 4: Preparing for audio generation (40%)
        jobs[job_id]['status'] = 'preparing_audio'
        jobs[job_id]['progress'] = 40
        
        # Create output file path
        filename = f"{job_id}.wav"
        output_path = os.path.join(UPLOAD_FOLDER, filename)
        
        # Use sample background file path
        background_path = "samples/breakfill.wav"
        
        # Check if background file exists
        if not os.path.exists(background_path):
            print(f"Error: Background file not found at {background_path}")
            jobs[job_id]['status'] = 'error'
            jobs[job_id]['error'] = f"Background file not found: {background_path}"
            return
        
        # Step 5: Starting audio generation (45%)
        jobs[job_id]['status'] = 'generating_audio'
        jobs[job_id]['progress'] = 45
        print(f"Starting audio generation for job {job_id}")
        
        # Step 5.1: Text to speech conversion setup (45-90%)
        # The audio generation in F5 happens in batches, so we need to track progress more precisely
        
        # Create a more granular progress callback function for F5 audio generation
        def update_audio_progress(stage, current=0, total=100):
            """
            Update progress during audio generation
            
            Parameters:
            - stage: String describing the current stage ('initializing', 'chunking', 'processing', 'finalizing')
            - current: Current chunk/batch being processed
            - total: Total chunks/batches to process
            """
            # F5 audio generation happens between 45% and 90% of the overall process
            # Map the current/total within this range
            progress_base = 45
            progress_max = 90
            progress_range = progress_max - progress_base
            
            # Calculate base progress based on stage
            if stage == 'initializing':
                # Initializing model (45-48%)
                stage_progress = 0.05
            elif stage == 'chunking':
                # Text chunking stage (48-52%)
                stage_progress = 0.12
            elif stage == 'processing':
                # Main processing stage - this is where most time is spent (52-85%)
                # Here we use the current/total to track batch progress with finer granularity
                base_processing = 0.15
                processing_range = 0.7
                
                # Adjust for the case when current is 0 (just started)
                if current == 0 and total > 0:
                    current = 1
                    
                # For small number of batches, interpolate more points
                if total <= 3 and current <= total:
                    # Use a more granular approach for small batch counts
                    batch_index = current - 1
                    
                    # Calculate direct proportion for fewer batches for more granular updates
                    stage_progress = base_processing + (processing_range * (current / total))
                    
                    # For small batches, we'll do additional tracking in the meditation_status endpoint
                    # by storing additional tracking data in the job
                    batch_progress = (current - batch_index)
                    jobs[job_id]['batch_progress'] = batch_progress
                else:
                    # For larger batch counts, use the regular calculation
                    stage_progress = base_processing + (processing_range * (current / total))
            elif stage == 'post_processing':
                # Audio post-processing (85-90%)
                stage_progress = 0.92
            else:
                # Default fallback
                stage_progress = 0.5
            
            # Calculate overall progress in the 45-90% range
            overall_progress = progress_base + (progress_range * stage_progress)
            
            # Update job progress and substage information
            jobs[job_id]['progress'] = min(progress_max, int(overall_progress))
            jobs[job_id]['audio_substage'] = stage
            
            # Store current and total for processing stage
            if stage == 'processing':
                jobs[job_id]['audio_current'] = current
                jobs[job_id]['audio_total'] = total
                
            print(f"Audio generation progress: Stage={stage}, Progress={jobs[job_id]['progress']}%, Current={current}, Total={total}")
        
        # Generate the meditation audio with progress tracking
        print(f"Generating meditation audio for job {job_id}")
        
        # Now use our new function with progress callback
        generate_meditation_from_text_with_progress(
            meditation_script,
            background_path,
            output_path,
            progress_callback=update_audio_progress
        )
        
        # Check if audio was generated successfully
        if not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
            print(f"Error: Audio file was not generated at {output_path}")
            jobs[job_id]['status'] = 'error'
            jobs[job_id]['error'] = "Failed to generate audio file"
            return
            
        print(f"Audio generated successfully and saved to {output_path}")
        
        # Step 6: Finalizing (95-100%)
        jobs[job_id]['progress'] = 95
        jobs[job_id]['status'] = 'finalizing'
        
        # Set the audio URL for client-side retrieval
        audio_url = f"/api/meditation-audio/{job_id}"
        jobs[job_id]['audio_url'] = audio_url
        jobs[job_id]['progress'] = 100
        jobs[job_id]['status'] = 'completed'
        
    except Exception as e:
        error_details = traceback.format_exc()
        print(f"Error in meditation job {job_id}: {str(e)}")
        print(f"Traceback: {error_details}")
        jobs[job_id]['status'] = 'error'
        jobs[job_id]['error'] = str(e)

@app.route('/api/meditation-status/<job_id>', methods=['GET'])
@require_api_key
def meditation_status(job_id):
    """
    Check the status of a meditation generation job.
    """
    if job_id not in jobs:
        return jsonify({
            'status': 'error',
            'error': f'Job ID {job_id} not found'
        }), 404
    
    job = jobs[job_id]
    
    # Basic response with status and progress
    response = {
        'status': job.get('status', 'pending'),
        'progress': job.get('progress', 0)
    }
    
    # If the job is in the audio generation phase, include substage information
    if job.get('status') == 'generating_audio' and 'audio_substage' in job:
        response['substage'] = job.get('audio_substage')
        
        # Include current and total for processing stage
        if job.get('audio_substage') == 'processing':
            response['current'] = job.get('audio_current', 1)
            response['total'] = job.get('audio_total', 1)
            
            # For small batch counts, provide more granular progress
            if job.get('audio_total', 1) <= 3:
                # We may have additional intra-batch progress for small batches
                if 'batch_progress' in job:
                    batch_progress = job.get('batch_progress', 0)
                    current = job.get('audio_current', 1)
                    total = job.get('audio_total', 1)
                    
                    # Calculate finer-grained progress for the progress bar
                    # Map the progress to a slightly larger range to show movement
                    base_progress = response['progress']
                    if current < total:
                        # Add up to 3% increment based on batch progress
                        increment = int(3 * batch_progress)
                        response['progress'] = min(85, base_progress + increment)
    
    # If the job is completed, include the meditation script and audio URL
    if job.get('status') == 'completed':
        response['meditation_script'] = job.get('meditation_script', '')
        response['audio_url'] = job.get('audio_url', '')
    
    # If there was an error, include the error message
    if job.get('status') == 'error':
        response['error'] = job.get('error', 'Unknown error')
    
    return jsonify(response)

@app.route('/api/meditation-audio/<job_id>', methods=['GET'])
@require_api_key
def get_meditation_audio(job_id):
    """
    API endpoint to retrieve the generated meditation audio file.
    """
    file_path = os.path.join(UPLOAD_FOLDER, f"{job_id}.wav")
    
    if not os.path.exists(file_path):
        return jsonify({'error': 'Audio file not found'}), 404
    
    return send_file(
        file_path,
        mimetype='audio/wav',
        as_attachment=True,
        download_name='meditation.wav'
    )

@app.route('/api/health', methods=['GET'])
def health_check():
    """
    Simple health check endpoint - no auth required for basic health check
    """
    return jsonify({'status': 'ok'})

@app.route('/api/verify-key', methods=['GET'])
def verify_key():
    """
    Endpoint to verify API key is correct - returns 200 if valid, 403 if invalid
    """
    if API_KEY is None:
        return jsonify({'status': 'no_auth_required'}), 200
    
    request_api_key = request.headers.get('X-API-Key')
    if not request_api_key:
        return jsonify({'error': 'API key required'}), 401
    
    if request_api_key != API_KEY:
        return jsonify({'error': 'Invalid API key'}), 403
        
    return jsonify({'status': 'valid'}), 200

if __name__ == '__main__':
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Oneiro Meditation Generator API Server')
    parser.add_argument('--host', type=str, default='127.0.0.1', 
                        help='Host to bind to (use 0.0.0.0 to accept connections from any IP)')
    parser.add_argument('--port', type=int, default=5000,
                        help='Port to listen on')
    parser.add_argument('--debug', action='store_true',
                        help='Run in debug mode')
    parser.add_argument('--no-auth', action='store_true',
                        help='Disable API key authentication')
    
    args = parser.parse_args()
    
    # Only load/generate API key if we're exposing the API to LAN and auth is not disabled
    if args.host == '0.0.0.0' and not args.no_auth:
        api_key = load_or_generate_api_key()
        print(f"API Key is required for remote access. Key: {api_key}")
        print(f"API_KEY_VALUE={api_key}")
    elif args.no_auth:
        print("WARNING: API key authentication is disabled")
    
    # Run the Flask application with the provided arguments
    app.run(host=args.host, port=args.port, debug=args.debug) 