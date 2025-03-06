from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import os
import tempfile
import uuid
import threading
import json
from main import generate_meditation_script, generate_meditation_from_text

app = Flask(__name__)
CORS(app)  # Enable Cross-Origin Resource Sharing

# Directory to store generated meditations
UPLOAD_FOLDER = 'generated_meditations'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# In-memory job status tracking
jobs = {}

@app.route('/api/generate-meditation', methods=['POST'])
def generate_meditation():
    """
    API endpoint to generate a meditation from a user's worry.
    Returns a job ID for polling the status.
    """
    try:
        data = request.json
        user_worry = data.get('worry', '')
        
        if not user_worry:
            return jsonify({'error': 'No worry description provided'}), 400
        
        # Create a unique job ID
        job_id = str(uuid.uuid4())
        
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
        
        return jsonify({
            'job_id': job_id,
            'status': 'pending',
            'message': 'Meditation generation started'
        })
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': str(e)}), 500

def process_meditation_job(job_id, user_worry):
    """
    Background process to generate meditation script and audio.
    Updates job status as it progresses.
    """
    try:
        # Update job status
        jobs[job_id]['status'] = 'generating_script'
        jobs[job_id]['progress'] = 10
        
        # Generate meditation script
        meditation_script = generate_meditation_script(user_worry)
        jobs[job_id]['meditation_script'] = meditation_script
        jobs[job_id]['progress'] = 40
        
        # Update job status
        jobs[job_id]['status'] = 'generating_audio'
        
        # Create output file path
        filename = f"{job_id}.wav"
        output_path = os.path.join(UPLOAD_FOLDER, filename)
        
        # Use sample background file path (change this to your actual background file)
        background_path = "samples/breakfill.wav"
        
        # Generate the meditation audio
        generate_meditation_from_text(
            meditation_script,
            background_path,
            output_path
        )
        
        # Set the audio URL for client-side retrieval
        audio_url = f"/api/meditation-audio/{job_id}"
        jobs[job_id]['audio_url'] = audio_url
        jobs[job_id]['progress'] = 100
        jobs[job_id]['status'] = 'completed'
        
    except Exception as e:
        print(f"Error in meditation job {job_id}: {str(e)}")
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
    app.run(host='0.0.0.0', port=5000, debug=True) 