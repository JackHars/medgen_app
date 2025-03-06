from flask import Flask, request, jsonify, send_file, redirect
from flask_cors import CORS
import os
import tempfile
import uuid
import threading
import json
import traceback
import sys
from main import generate_meditation_script, generate_meditation_from_text

app = Flask(__name__)
CORS(app)  # Enable Cross-Origin Resource Sharing

# Directory to store generated meditations
UPLOAD_FOLDER = 'generated_meditations'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# In-memory job status tracking
jobs = {}

@app.route('/')
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

def process_meditation_job(job_id, user_worry):
    """
    Background process to generate meditation script and audio.
    Updates job status as it progresses.
    """
    try:
        print(f"Processing job {job_id} with worry: {user_worry[:30]}...")
        
        # Update job status
        jobs[job_id]['status'] = 'generating_script'
        jobs[job_id]['progress'] = 10
        
        # Generate meditation script
        print(f"Generating meditation script for job {job_id}")
        meditation_script = generate_meditation_script(user_worry)
        print(f"Script generated successfully (length: {len(meditation_script)})")
        
        jobs[job_id]['meditation_script'] = meditation_script
        jobs[job_id]['progress'] = 40
        
        # Update job status
        jobs[job_id]['status'] = 'generating_audio'
        
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
        
        # Generate the meditation audio
        print(f"Generating meditation audio for job {job_id}")
        generate_meditation_from_text(
            meditation_script,
            background_path,
            output_path
        )
        
        # Check if audio was generated successfully
        if not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
            print(f"Error: Audio file was not generated at {output_path}")
            jobs[job_id]['status'] = 'error'
            jobs[job_id]['error'] = "Failed to generate audio file"
            return
            
        print(f"Audio generated successfully and saved to {output_path}")
        
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
def meditation_status(job_id):
    """
    API endpoint to check the status of a meditation generation job.
    Returns the current status, progress, and results if ready.
    """
    if job_id not in jobs:
        return jsonify({'error': 'Job not found'}), 404
    
    job = jobs[job_id]
    
    # For completed jobs, include the meditation script and audio URL
    if job['status'] == 'completed':
        return jsonify({
            'status': 'completed',
            'progress': 100,
            'meditation_script': job['meditation_script'],
            'audio_url': job['audio_url']
        })
    
    # For error jobs, include the error message
    elif job['status'] == 'error':
        return jsonify({
            'status': 'error',
            'error': job.get('error', 'Unknown error')
        })
    
    # For pending or in-progress jobs
    return jsonify({
        'status': job['status'],
        'progress': job['progress']
    })

@app.route('/api/meditation-audio/<job_id>', methods=['GET'])
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
    Simple health check endpoint
    """
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=False) 