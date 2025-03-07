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
API_KEY_ARG=""  # For storing API key passed as argument
CUSTOM_BACKEND_IP="192.168.2.116"  # Default backend IP for frontend-only mode
DEBUG_MODE=false  # Advanced debugging mode

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --backend)
      RUN_BACKEND=true
      RUN_FRONTEND=false
      BACKEND_HOST="0.0.0.0"  # Open to LAN when running backend only
      shift
      ;;
    --frontend)
      RUN_BACKEND=false
      RUN_FRONTEND=true
      # Check if the next argument exists and doesn't start with --
      if [[ -n "$2" && ! "$2" == --* ]]; then
        API_KEY_ARG="$2"
        echo -e "${GREEN}API key provided via command line argument${NC}"
        shift  # Extra shift to consume the API key argument
      fi
      shift
      ;;
    --backend-ip)
      # Allow specifying a custom backend IP when running frontend
      if [[ -n "$2" ]]; then
        CUSTOM_BACKEND_IP="$2"
        echo -e "${GREEN}Custom backend IP specified: $CUSTOM_BACKEND_IP${NC}"
        shift  # Extra shift to consume the IP argument
      else
        echo -e "${RED}Error: --backend-ip requires an IP address argument${NC}"
        exit 1
      fi
      shift
      ;;
    --no-auth)
      DISABLE_AUTH=true
      shift
      ;;
    --debug)
      DEBUG_MODE=true
      echo -e "${YELLOW}Advanced debugging mode enabled${NC}"
      shift
      ;;
    -h|--help)
      echo "Usage: ./run_app.sh [OPTIONS]"
      echo "Options:"
      echo "  --backend            Run only the backend server (open to LAN)"
      echo "  --frontend [KEY]     Run only the frontend UI, optionally providing API key"
      echo "  --backend-ip IP      Specify custom backend IP address (default: 192.162.2.116)"
      echo "  --no-auth            Disable API key authentication (not recommended for LAN)"
      echo "  --debug              Enable advanced debugging mode"
      echo "  -h, --help           Show this help message"
      echo ""
      echo "Examples:"
      echo "  ./run_app.sh                                 # Run both frontend and backend locally"
      echo "  ./run_app.sh --backend                       # Run only the backend (LAN accessible)"
      echo "  ./run_app.sh --frontend                      # Run only the frontend, will prompt for API key"
      echo "  ./run_app.sh --frontend APIKEY123            # Run frontend with provided API key"
      echo "  ./run_app.sh --frontend APIKEY123 --backend-ip 10.0.1.5  # Connect to specific backend IP"
      echo ""
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
    sleep 3  # Increased sleep time to ensure log is written
    
    # If we're using authentication and exposing to LAN, extract the API key
    if [[ $BACKEND_HOST == "0.0.0.0" && $DISABLE_AUTH == false ]]; then
        # Extract API key from log file
        if [[ -f backend/backend_output.log ]]; then
            echo -e "${YELLOW}Attempting to extract API key from server log...${NC}"
            
            # Try the new clear format first
            API_KEY=$(grep "API_KEY_VALUE=" backend/backend_output.log | cut -d'=' -f2)
            
            if [[ -n $API_KEY ]]; then
                echo -e "${GREEN}API Key obtained for secure communication${NC}"
                echo -e "${YELLOW}API KEY: ${GREEN}$API_KEY${NC}"
                echo -e "${YELLOW}SAVE THIS KEY! You'll need it to connect the frontend.${NC}"
            else
                # More flexible pattern matching for the API key
                API_KEY=$(grep -E "API Key|api key|Key:|key:" backend/backend_output.log | grep -oE '[a-f0-9]{64}')
                
                if [[ -n $API_KEY ]]; then
                    echo -e "${GREEN}API Key obtained for secure communication${NC}"
                    echo -e "${YELLOW}API KEY: ${GREEN}$API_KEY${NC}"
                    echo -e "${YELLOW}SAVE THIS KEY! You'll need it to connect the frontend.${NC}"
                else
                    echo -e "${YELLOW}First attempt to extract API key failed, trying alternate methods...${NC}"
                    
                    # Try to extract any 64-character hex string that might be the API key
                    API_KEY=$(grep -oE '[a-f0-9]{64}' backend/backend_output.log | head -1)
                    
                    if [[ -n $API_KEY ]]; then
                        echo -e "${GREEN}API Key extracted using pattern matching${NC}"
                        echo -e "${YELLOW}API KEY: ${GREEN}$API_KEY${NC}"
                        echo -e "${YELLOW}SAVE THIS KEY! You'll need it to connect the frontend.${NC}"
                    else
                        # If we still can't extract the key automatically, check if the file exists
                        if [[ -f backend/api_key.txt ]]; then
                            API_KEY=$(cat backend/api_key.txt)
                            echo -e "${GREEN}API Key loaded directly from api_key.txt file${NC}"
                            echo -e "${YELLOW}API KEY: ${GREEN}$API_KEY${NC}"
                            echo -e "${YELLOW}SAVE THIS KEY! You'll need it to connect the frontend.${NC}"
                        else
                            echo -e "${RED}Warning: Could not extract API key from server output${NC}"
                            echo -e "${YELLOW}You may need to manually enter the API key when prompted${NC}"
                            
                            # For debugging only - remove in production
                            echo -e "${YELLOW}Server log contents for debugging:${NC}"
                            cat backend/backend_output.log
                        fi
                    fi
                fi
            fi
        else
            echo -e "${RED}Warning: Backend output log file not found${NC}"
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
        
        # Extract the hostname from IP for better diagnostic messages
        echo -e "${GREEN}Configuring API to connect to $CUSTOM_BACKEND_IP:5000${NC}"
        
        # Test connectivity to the backend server before proceeding
        echo -e "${YELLOW}Testing connectivity to the backend server...${NC}"
        if command -v curl &> /dev/null; then
            # Use curl if available
            echo -e "${YELLOW}Attempting to reach backend health endpoint...${NC}"
            HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "http://$CUSTOM_BACKEND_IP:5000/api/health" --connect-timeout 5)
            if [[ $HEALTH_CHECK == "200" ]]; then
                echo -e "${GREEN}Backend server is reachable at http://$CUSTOM_BACKEND_IP:5000${NC}"
            else
                echo -e "${RED}WARNING: Backend server health check failed with status $HEALTH_CHECK${NC}"
                echo -e "${RED}Make sure the backend is running at http://$CUSTOM_BACKEND_IP:5000${NC}"
                echo -e "${YELLOW}Continuing anyway, but the application may not function correctly...${NC}"
            fi
        elif command -v nc &> /dev/null; then
            # Use netcat as an alternative
            echo -e "${YELLOW}Checking if port 5000 is open on $CUSTOM_BACKEND_IP...${NC}"
            if nc -z -w5 $CUSTOM_BACKEND_IP 5000; then
                echo -e "${GREEN}Port 5000 is open on $CUSTOM_BACKEND_IP${NC}"
            else
                echo -e "${RED}WARNING: Cannot connect to $CUSTOM_BACKEND_IP:5000${NC}"
                echo -e "${RED}Make sure the backend is running and the port is accessible${NC}"
                echo -e "${YELLOW}Check for firewalls or other network restrictions${NC}"
            fi
        else
            echo -e "${YELLOW}Cannot test connection (curl or nc not available)${NC}"
        fi
        
        # Create a backup of the original API service file if it doesn't exist
        if [ ! -f "lib/services/api_service.dart.bak" ]; then
            cp lib/services/api_service.dart lib/services/api_service.dart.bak
            echo -e "${YELLOW}Created backup of API service file at lib/services/api_service.dart.bak${NC}"
        fi
        
        # Update the API base URL to point to the specified IP
        sed -i.tmp "s|static const String baseUrl = 'http://127.0.0.1:5000'|static const String baseUrl = 'http://$CUSTOM_BACKEND_IP:5000'|g" lib/services/api_service.dart
        
        # Add debug logging to help diagnose issues
        echo -e "${YELLOW}Adding verbose logging to API service...${NC}"
        LOG_PATTERN="print('API Error (detailed): \$e');"
        VERBOSE_LOG="print('API Error (detailed): \$e'); print('Connection attempted to: \$baseUrl'); print('Network error details: \${e.toString()}');"
        sed -i.tmp "s|$LOG_PATTERN|$VERBOSE_LOG|g" lib/services/api_service.dart
        
        # If API key is needed, check if we need to ask for it
        if [[ $DISABLE_AUTH == false ]]; then
            # First check if we got an API key from the command line argument
            if [[ -n $API_KEY_ARG ]]; then
                API_KEY=$API_KEY_ARG
                echo -e "${GREEN}Using API key provided via command line${NC}"
            # If we don't have an API key (because we're not running the backend), prompt for it
            elif [[ -z $API_KEY ]]; then
                echo -e "${YELLOW}Please enter the API key from the backend server:${NC}"
                read -r API_KEY
            fi
            
            if [[ -n $API_KEY ]]; then
                # Insert the API key initialization into the API service
                sed -i.tmp "s|static String? apiKey;|static String? apiKey = '$API_KEY';|g" lib/services/api_service.dart
                echo -e "${GREEN}API key configured for authentication${NC}"
                
                # Verify API key length
                if [[ ${#API_KEY} != 64 ]]; then
                    echo -e "${RED}WARNING: API key length (${#API_KEY}) is not 64 characters.${NC}"
                    echo -e "${RED}The key may be incomplete or invalid.${NC}"
                fi
            fi
        fi
        
        rm -f lib/services/api_service.dart.tmp
        
        # If in debug mode, run more extensive network diagnostics
        if [[ $DEBUG_MODE == true ]]; then
            echo -e "${YELLOW}Running advanced network diagnostics...${NC}"
            
            # Check general network connectivity
            echo -e "${YELLOW}Checking general internet connectivity...${NC}"
            if ping -c 1 google.com &> /dev/null; then
                echo -e "${GREEN}Internet connection is working${NC}"
            else
                echo -e "${RED}WARNING: Cannot reach internet. Network may be restricted${NC}"
            fi
            
            # Try to get more details about the backend connection
            echo -e "${YELLOW}Attempting detailed connection to backend...${NC}"
            if command -v curl &> /dev/null; then
                # Show detailed curl output in debug mode
                echo -e "${YELLOW}Sending detailed request to backend health endpoint...${NC}"
                echo -e "${YELLOW}curl -v http://$CUSTOM_BACKEND_IP:5000/api/health${NC}"
                curl -v http://$CUSTOM_BACKEND_IP:5000/api/health
                echo ""  # Add newline after curl output
            fi
            
            # Try traceroute to see the network path
            if command -v traceroute &> /dev/null; then
                echo -e "${YELLOW}Tracing route to backend server...${NC}"
                traceroute -m 5 $CUSTOM_BACKEND_IP
            fi
            
            # Check if we're using the correct API key format and authentication headers
            if [[ -n $API_KEY ]]; then
                echo -e "${YELLOW}Testing API key authentication...${NC}"
                if command -v curl &> /dev/null; then
                    echo -e "${YELLOW}Sending authenticated request to backend verify-key endpoint...${NC}"
                    AUTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" -H "X-API-Key: $API_KEY" "http://$CUSTOM_BACKEND_IP:5000/api/verify-key" --connect-timeout 5)
                    if [[ $AUTH_CHECK == "200" ]]; then
                        echo -e "${GREEN}API key authentication successful${NC}"
                    else
                        echo -e "${RED}WARNING: API key authentication failed with status $AUTH_CHECK${NC}"
                        echo -e "${RED}Make sure the API key is correct and the backend is properly configured${NC}"
                    fi
                fi
            fi
            
            # Make sure we're changing the API service file correctly
            echo -e "${YELLOW}Checking API service modifications...${NC}"
            echo -e "${YELLOW}Configured API base URL: ${GREEN}http://$CUSTOM_BACKEND_IP:5000${NC}"
            echo -e "${YELLOW}Configured API Key: ${GREEN}${API_KEY:0:6}...${API_KEY: -6}${NC}"
            
            # Modify Flutter run command for better debugging
            echo -e "${YELLOW}Launching Flutter in debug mode with verbose logging...${NC}"
            flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080 --verbose &
            FLUTTER_PID=$!
        else
            echo -e "${YELLOW}Launching Flutter in debug mode for better error logging...${NC}"
            flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080 &
            FLUTTER_PID=$!
        fi
    else
        # If we're running both frontend and backend, restore the original API URL if needed
        if [ -f "lib/services/api_service.dart.bak" ]; then
            cp lib/services/api_service.dart.bak lib/services/api_service.dart
            echo -e "${YELLOW}Restored API service file to use localhost${NC}"
        fi
    fi
fi

# Wait for user to press Ctrl+C
if [[ $RUN_BACKEND == true && $RUN_FRONTEND == true ]]; then
    echo -e "${GREEN}Both services are running. Press Ctrl+C to stop.${NC}"
elif [[ $RUN_BACKEND == true ]]; then
    echo -e "${GREEN}Backend service is running. Press Ctrl+C to stop.${NC}"
    
    # If we're running in backend-only mode with authentication, remind the user of the API key
    if [[ $BACKEND_HOST == "0.0.0.0" && $DISABLE_AUTH == false && -n $API_KEY ]]; then
        echo ""
        echo -e "${YELLOW}REMINDER: To connect a frontend to this backend, you'll need:${NC}"
        echo -e "${YELLOW}1. The server's IP address: ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
        echo -e "${YELLOW}2. The API key: ${GREEN}$API_KEY${NC}"
        echo -e "${YELLOW}Run the frontend with: ${GREEN}./run_app.sh --frontend $API_KEY${NC}"
        echo ""
    fi
else
    echo -e "${GREEN}Frontend service is running. Press Ctrl+C to stop.${NC}"
fi

wait 