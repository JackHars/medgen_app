# Contributing to Oneiro

Thank you for your interest in contributing to Oneiro! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. Please read it before contributing.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in the Issues section
2. If not, create a new issue with:
   - A clear title and description
   - Steps to reproduce the bug
   - Expected behavior
   - Actual behavior
   - Screenshots or recordings if applicable
   - Your environment details (OS, Python version, Flutter version)

### Suggesting Enhancements

1. Check if the enhancement has been suggested in the Issues section
2. If not, create a new issue with:
   - A clear title and description
   - Why this enhancement would be useful
   - Any specific implementation ideas
   - Screenshots or mockups if applicable

### Pull Requests

1. Fork the repository
2. Create a new branch for your feature/fix:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-fix-name
   ```
3. Make your changes
4. Run tests and ensure everything works
5. Commit your changes with clear commit messages
6. Push to your fork
7. Create a Pull Request

### Development Setup

1. Set up the development environment:
   ```bash
   # Backend
   cd backend
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt

   # Frontend
   flutter pub get
   ```

2. Run tests:
   ```bash
   # Backend tests
   cd backend
   python -m pytest

   # Frontend tests
   flutter test
   ```

### Code Style

#### Python
- Follow PEP 8 guidelines
- Use type hints
- Add docstrings for functions and classes
- Keep functions focused and small
- Use meaningful variable names

#### Dart/Flutter
- Follow the official [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable names
- Add comments for complex logic
- Keep widgets focused and small
- Use const constructors when possible

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line
- Consider starting the commit message with an applicable emoji:
  - 🎨 `:art:` when improving the format/structure of the code
  - 🐎 `:racehorse:` when improving performance
  - 🚱 `:non-potable_water:` when plugging memory leaks
  - 📝 `:memo:` when writing docs
  - 🐛 `:bug:` when fixing a bug
  - 🔥 `:fire:` when removing code or files
  - 💚 `:green_heart:` when fixing the CI build
  - ✅ `:white_check_mark:` when adding tests
  - 🔒 `:lock:` when dealing with security
  - ⬆️ `:arrow_up:` when upgrading dependencies
  - ⬇️ `:arrow_down:` when downgrading dependencies

## Project Structure

```
oneiro/
├── backend/
│   ├── models/         # AI model files
│   ├── samples/        # Sample audio files
│   ├── server.py       # Flask server
│   └── main.py         # Core logic
├── lib/
│   ├── services/       # API and audio services
│   └── main.dart       # Main app entry point
└── test/              # Test files
```

## Questions?

If you have any questions, feel free to:
1. Open an issue
2. Join our discussions
3. Contact the maintainers

Thank you for contributing to Oneiro! 