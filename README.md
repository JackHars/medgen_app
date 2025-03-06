# Oneiro - AI-Powered Meditation Generator

A modern, cosmic-themed Flutter web application that creates personalized guided meditations to help you journey through mindful dreams.

## Features

- Modern, dark UI with cosmic-zen aesthetic
- Sleek, single-line input for describing your concerns
- AI-powered meditation generation
- Responsive design with animated starfield background
- Beautiful typography and smooth animations

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version recommended)
- Dart SDK
- Chrome browser (for web development)

### Installation

1. Clone the repository:
```bash
git clone <your-repository-url>
cd gensite
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application in Chrome:
```bash
flutter run -d chrome
```

## How It Works

Oneiro combines modern design with AI technology to create a dreamlike space for meditation. Users can describe their current state of mind, and the application generates a personalized meditation tailored to their needs.

In the development version, the app provides contextually appropriate meditations based on keyword analysis. In production, this would connect to an AI service for truly personalized meditation generation.

## Design System

### Colors
- Primary: `Color(0xFF8B5CF6)` - Purple for spiritual energy
- Secondary: `Color(0xFFEC4899)` - Pink for emotional warmth
- Background: `Color(0xFF0F172A)` - Deep space blue
- Surface: `Color(0xFF1E293B)` - Lighter cosmic blue

### Typography
- Font: Inter (Google Fonts)
- Headings: 48px/24px with custom line height
- Body: 16px with 1.8 line height
- Subtle text: White with reduced opacity

### UI Elements
- Floating cards with subtle borders
- Animated starfield background
- Gradient overlays
- Smooth hover states and transitions

## Connecting to Your Meditation API

The application is set up to communicate with a backend API. To connect to your meditation generation service:

1. Open `lib/services/api_service.dart`
2. Update the `baseUrl` constant with your API URL
3. Modify the `processText` method to match your API's request/response format

## Building for Production

```bash
flutter build web
```

The built files will be available in the `build/web` directory and can be deployed to any web hosting service.

## License

This project is licensed under the MIT License.
