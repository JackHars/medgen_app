#!/bin/bash

# Define colors for console output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Oneiro Meditation Generator...${NC}"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is required but not installed.${NC}"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter is required but not installed.${NC}"
    exit 1
fi

# Function to stop all background processes when script is terminated
cleanup() {
    echo -e "\n${YELLOW}Shutting down services...${NC}"
    kill $BACKEND_PID 2>/dev/null
    kill $FLUTTER_PID 2>/dev/null
    exit 0
}

# Set trap to call cleanup function when script is terminated
trap cleanup INT TERM

# Start Python backend server
echo -e "${GREEN}Starting Python backend server...${NC}"
cd backend
echo -e "${YELLOW}Installing Python dependencies...${NC}"
pip install -r requirements.txt
echo -e "${GREEN}Starting server on http://localhost:5000${NC}"
python3 server.py &
BACKEND_PID=$!
cd ..

# Wait a moment for the backend to start
sleep 2

# Install Flutter dependencies
echo -e "${YELLOW}Installing Flutter dependencies...${NC}"
flutter pub get

# Start Flutter web app
echo -e "${GREEN}Starting Flutter web application...${NC}"
flutter run -d chrome &
FLUTTER_PID=$!

# Wait for user to press Ctrl+C
echo -e "${GREEN}Both services are running. Press Ctrl+C to stop.${NC}"
wait 