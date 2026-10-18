#!/bin/bash

# Build and run Pace from the terminal

set -e

# Terminal colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔨 Building Pace...${NC}"

# Create build directory
mkdir -p build

# Build the project
xcodebuild -project pace.xcodeproj \
           -scheme pace \
           -configuration Debug \
           -derivedDataPath build \
           build | grep -E "FAILED|error:|warning:" || true

# Check if build succeeded
APP_PATH="build/Build/Products/Debug/pace.app"

if [ -d "$APP_PATH" ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    
    # Kill existing instance if running
    echo -e "${BLUE}🔄 Restarting app...${NC}"
    # Kill by exact name and also by matching path to be sure
    pkill -x pace || true
    pkill -f "build/Build/Products/Debug/pace.app" || true
    
    # Open the app binary directly to show logs in terminal
    echo -e "${BLUE}🔍 App started. Showing logs below:${NC}"
    "$APP_PATH/Contents/MacOS/pace"
else
    echo -e "${RED}❌ Build failed or app not found at $APP_PATH${NC}"
    exit 1
fi
