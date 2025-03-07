#!/bin/bash
#
# Oneiro Meditation Generator Launcher
# 
# This script can launch:
# - Both the Python backend API and Flutter web frontend (default)
# - Just the Python backend API (--backend-only flag)
# - Just the Flutter web frontend (--frontend-only flag)
#
# When running in backend-only mode, the API is accessible over LAN.
# When running both or just frontend, the API is only accessible from localhost.
#

# Define colors for console output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
RUN_BACKEND=true
RUN_FRONTEND=true
BACKEND_HOST="127.0.0.1"  # Default to localhost only
DISABLE_AUTH=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --backend-only)
      RUN_BACKEND=true
      RUN_FRONTEND=false
      BACKEND_HOST="0.0.0.0"  # Open to LAN when running backend only
      shift
      ;;
    --frontend-only)
      RUN_BACKEND=false
      RUN_FRONTEND=true
      shift
      ;;
    --no-auth)
      DISABLE_AUTH=true
      shift
      ;;
    -h|--help)
      echo "Usage: ./run_app.sh [OPTIONS]"
      echo "Options:"
      echo "  --backend-only    Run only the backend server (open to LAN)"
      echo "  --frontend-only   Run only the frontend UI"
      echo "  --no-auth         Disable API key authentication (not recommended for LAN)"
      echo "  -h, --help        Show this help message"
      echo ""
      echo "If run without options, both backend and frontend will run on the same machine (localhost only)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run './run_app.sh --help' for usage information"
      exit 1
      ;;
  esac
done

echo -e "${YELLOW}Starting Oneiro Meditation Generator...${NC}"

# Function to stop all background processes when script is terminated
cleanup() {
    echo -e "\n${YELLOW}Shutting down services...${NC}"
    if [[ -n $BACKEND_PID ]]; then
        kill $BACKEND_PID 2>/dev/null
    fi
    if [[ -n $FLUTTER_PID ]]; then
        kill $FLUTTER_PID 2>/dev/null
    fi
    
    # Restore the original API service file if it was modified
    if [ -f "lib/services/api_service.dart.bak" ]; then
        echo -e "${YELLOW}Restoring original API service configuration...${NC}"
        cp lib/services/api_service.dart.bak lib/services/api_service.dart
        echo -e "${GREEN}API service configuration restored${NC}"
    fi
    
    exit 0
}

# Set trap to call cleanup function when script is terminated
trap cleanup INT TERM

# Check required dependencies based on what we're running
if [[ $RUN_BACKEND == true ]]; then
    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: Python 3 is required for the backend but not installed.${NC}"
        exit 1
    fi
fi

if [[ $RUN_FRONTEND == true ]]; then
    # Check if Flutter is installed
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}Error: Flutter is required for the frontend but not installed.${NC}"
        exit 1
    fi
fi

# Variable to store the API key if needed
API_KEY=""

# Start Python backend server if needed
if [[ $RUN_BACKEND == true ]]; then
    echo -e "${GREEN}Starting Python backend server...${NC}"
    cd backend
    echo -e "${YELLOW}Installing Python dependencies...${NC}"
    pip install -r requirements.txt
    
    # Build the command with the appropriate arguments
    BACKEND_CMD="python3 server.py --host $BACKEND_HOST"
    
    # Add --no-auth flag if authentication is disabled
    if [[ $DISABLE_AUTH == true ]]; then
        BACKEND_CMD="$BACKEND_CMD --no-auth"
        echo -e "${RED}WARNING: Running without API key authentication${NC}"
    fi
    
    # Use the appropriate host based on configuration
    if [[ $BACKEND_HOST == "0.0.0.0" ]]; then
        echo -e "${GREEN}Starting server on http://0.0.0.0:5000 (open to LAN)${NC}"
        
        if [[ $DISABLE_AUTH == false ]]; then
            echo -e "${YELLOW}API key authentication enabled for security${NC}"
        fi
        
        echo -e "${YELLOW}Note: Frontend is assumed to be running elsewhere${NC}"
        
        # Get the machine's IP address for easier access
        IP_ADDR=$(hostname -I | awk '{print $1}')
        if [[ -n $IP_ADDR ]]; then
            echo -e "${GREEN}Access the API at: http://$IP_ADDR:5000${NC}"
        fi
    else
        echo -e "${GREEN}Starting server on http://127.0.0.1:5000 (localhost only)${NC}"
    fi
    
    # Start the backend and capture its output to get the API key
    $BACKEND_CMD > backend_output.log 2>&1 &
    BACKEND_PID=$!
    cd ..

    # Wait a moment for the backend to start
    sleep 2
    
    # If we're using authentication and exposing to LAN, extract the API key
    if [[ $BACKEND_HOST == "0.0.0.0" && $DISABLE_AUTH == false ]]; then
        # Extract API key from log file
        if [[ -f backend/backend_output.log ]]; then
            API_KEY=$(grep "API Key is required for remote access" backend/backend_output.log | sed 's/.*Key: \(.*\)/\1/')
            if [[ -n $API_KEY ]]; then
                echo -e "${GREEN}API Key obtained for secure communication${NC}"
            else
                echo -e "${RED}Warning: Could not extract API key from server output${NC}"
            fi
        fi
    fi
fi

# Start Flutter web app if needed
if [[ $RUN_FRONTEND == true ]]; then
    # Install Flutter dependencies
    echo -e "${YELLOW}Installing Flutter dependencies...${NC}"
    flutter pub get

    # Start Flutter web app
    echo -e "${GREEN}Starting Flutter web application in production mode...${NC}"
    
    # Check if we're in frontend-only mode or running on a different machine
    if [[ $RUN_BACKEND == false ]]; then
        echo -e "${YELLOW}Note: Running in frontend-only mode${NC}"
        echo -e "${GREEN}Configuring API to connect to 192.162.2.116:5000${NC}"
        
        # Create a backup of the original API service file if it doesn't exist
        if [ ! -f "lib/services/api_service.dart.bak" ]; then
            cp lib/services/api_service.dart lib/services/api_service.dart.bak
            echo -e "${YELLOW}Created backup of API service file at lib/services/api_service.dart.bak${NC}"
        fi
        
        # Update the API base URL to point to the specified IP
        sed -i.tmp "s|static const String baseUrl = 'http://127.0.0.1:5000'|static const String baseUrl = 'http://192.162.2.116:5000'|g" lib/services/api_service.dart
        
        # If API key is needed, check if we need to ask for it
        if [[ $DISABLE_AUTH == false ]]; then
            # If we don't have an API key (because we're not running the backend), prompt for it
            if [[ -z $API_KEY ]]; then
                echo -e "${YELLOW}Please enter the API key from the backend server:${NC}"
                read -r API_KEY
            fi
            
            if [[ -n $API_KEY ]]; then
                # Insert the API key initialization into the API service
                sed -i.tmp "s|static String? apiKey;|static String? apiKey = '$API_KEY';|g" lib/services/api_service.dart
                echo -e "${GREEN}API key configured for authentication${NC}"
            fi
        fi
        
        rm -f lib/services/api_service.dart.tmp
    else
        # If we're running both frontend and backend, restore the original API URL if needed
        if [ -f "lib/services/api_service.dart.bak" ]; then
            cp lib/services/api_service.dart.bak lib/services/api_service.dart
            echo -e "${YELLOW}Restored API service file to use localhost${NC}"
        fi
    fi
    
    flutter run --release -d chrome --web-hostname 127.0.0.1 --web-port 8080 &
    FLUTTER_PID=$!
fi

# Wait for user to press Ctrl+C
if [[ $RUN_BACKEND == true && $RUN_FRONTEND == true ]]; then
    echo -e "${GREEN}Both services are running. Press Ctrl+C to stop.${NC}"
elif [[ $RUN_BACKEND == true ]]; then
    echo -e "${GREEN}Backend service is running. Press Ctrl+C to stop.${NC}"
else
    echo -e "${GREEN}Frontend service is running. Press Ctrl+C to stop.${NC}"
fi

wait 