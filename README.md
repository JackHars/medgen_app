# Oneiro - AI-Powered Meditation Generator

[![Oneiro Demo](https://vumbnail.com/1068975735.jpg)](https://vimeo.com/1068975735)

Oneiro is a modern web application that generates personalized meditation experiences using advanced AI technology. It combines text-to-speech synthesis with ambient background sounds to create immersive meditation sessions tailored to your specific concerns.

## Features

- 🤖 AI-powered meditation script generation using local Ollama
- 🎙️ High-quality text-to-speech using custom F5-TTS model
- 🌊 Ambient background sound processing with PaulStretch algorithm
- 🎨 Modern, responsive Flutter web interface
- 🔒 Secure API key authentication
- 📱 Progressive Web App (PWA) support
- 🎵 Real-time audio playback with progress tracking
- 💾 Download meditation audio files

## Prerequisites

- Python 3.8 or higher
- Flutter SDK 3.0 or higher
- Ollama installed and running locally
- F5-TTS model files (see Setup section)

## Setup

1. Clone the repository:
```bash
git clone https://github.com/JackHars/medgen_app.git
cd medgen_app
```

2. Set up the Python backend:
```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

3. Download required model files:
- Place F5-TTS model files in `backend/models/`:
  - `experimental.pt` (model checkpoint)
  - `main.txt` (vocabulary file)

4. Set up the Flutter frontend:
```bash
flutter pub get
```

5. Start Ollama:
```bash
ollama serve
ollama pull phi4
```

## Running the Application

1. Start the backend server:
```bash
cd backend
python server.py
```

2. Run the Flutter web app:
```bash
flutter run -d chrome
```

3. Open your browser and navigate to `http://localhost:8080`

## Development

### Backend Structure
- `server.py`: Flask server with API endpoints
- `main.py`: Core meditation generation logic
- `models/`: Directory for AI model files
- `samples/`: Sample audio files for testing

### Frontend Structure
- `lib/`: Flutter source code
  - `services/`: API and audio service implementations
  - `main.dart`: Main application entry point

## API Endpoints

- `POST /api/generate-meditation`: Generate a new meditation
- `GET /api/meditation-status/<job_id>`: Check meditation generation status
- `GET /api/meditation-audio/<job_id>`: Download generated meditation audio
- `GET /api/health`: Health check endpoint
- `GET /api/verify-key`: API key verification

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [F5-TTS](https://github.com/SWivid/F5-TTS) for the text-to-speech model
- [Ollama](https://ollama.ai/) for the local LLM capabilities
- [PaulStretch](https://github.com/paulnasca/paulstretch_python) for the audio stretching algorithm

## Support

For support, please open an issue in the GitHub repository or contact the maintainers.

