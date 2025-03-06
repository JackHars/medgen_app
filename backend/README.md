# Oneiro Backend Server

This is the backend server for the Oneiro meditation generator application. It provides API endpoints for generating meditation scripts and audio.

## Requirements

- Python 3.8+
- Ollama (for text generation)
- F5-TTS (for text-to-speech conversion)

## Setup

1. Install the required Python packages:

```bash
pip install -r requirements.txt
```

2. Make sure Ollama is installed and running:

```bash
ollama serve
ollama pull phi4  # or whatever model you want to use
```

3. Create necessary directories:

```bash
mkdir -p samples
mkdir -p generated_meditations
```

4. Place background audio files in the `samples` directory:
   - `breakfill.wav` - Default ambient background
   - `ref.wav` - Reference audio for voice cloning
   - `ref.reference.txt` - Transcription of the reference audio

## Running the Server

Start the API server:

```bash
python server.py
```

The server will be available at `http://localhost:5000`.

## API Endpoints

### Generate Meditation

```
POST /api/generate-meditation

Request body:
{
  "worry": "Your worry or stress description"
}

Response:
{
  "job_id": "unique-job-id",
  "status": "pending",
  "message": "Meditation generation started"
}
```

### Check Meditation Status

```
GET /api/meditation-status/<job_id>

Response (in progress):
{
  "status": "generating_script" | "generating_audio",
  "progress": 10-100
}

Response (completed):
{
  "status": "completed",
  "progress": 100,
  "meditation_script": "Full meditation script text",
  "audio_url": "/api/meditation-audio/<job_id>"
}

Response (error):
{
  "status": "error",
  "error": "Error message"
}
```

### Get Meditation Audio

```
GET /api/meditation-audio/<job_id>

Response: WAV audio file
```

### Health Check

```
GET /api/health

Response:
{
  "status": "ok"
}
```

## Integration with Frontend

The Flutter frontend communicates with this backend server using HTTP requests. The frontend is responsible for:

1. Sending the user's worry description to the `/api/generate-meditation` endpoint
2. Polling the `/api/meditation-status/<job_id>` endpoint to check the status
3. Playing or downloading the generated audio from the `/api/meditation-audio/<job_id>` endpoint 