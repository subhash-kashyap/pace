#!/bin/bash

# Pace Release Creation Script
# This script helps create a signed release package for Sparkle updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Pace Release Creator${NC}"
echo "================================"

# Check if version is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Version number required${NC}"
    echo "Usage: ./create_release.sh <version> <path-to-app> <private-key-path>"
    echo "Example: ./create_release.sh 1.0.0 ~/Desktop/Pace.app ~/.sparkle_private_key"
    exit 1
fi

VERSION=$1
APP_PATH=${2:-"$HOME/Desktop/Pace.app"}
PRIVATE_KEY=${3:-"$HOME/.sparkle_private_key"}

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    echo "Please export your app from Xcode first"
    exit 1
fi

# Check if private key exists
if [ ! -f "$PRIVATE_KEY" ]; then
    echo -e "${YELLOW}Warning: Private key not found at $PRIVATE_KEY${NC}"
    echo "You'll need to sign the update manually"
fi

OUTPUT_DIR="./releases"
mkdir -p "$OUTPUT_DIR"

ZIP_NAME="Pace-${VERSION}.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

echo ""
echo -e "${GREEN}Creating release package...${NC}"
echo "Version: $VERSION"
echo "App: $APP_PATH"
echo "Output: $ZIP_PATH"
echo ""

# Create zip
echo "Creating zip archive..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

# Get file size
FILE_SIZE=$(stat -f%z "$ZIP_PATH")
echo -e "${GREEN}✓${NC} Created zip: $ZIP_PATH ($FILE_SIZE bytes)"

# Sign if private key exists
if [ -f "$PRIVATE_KEY" ]; then
    echo ""
    echo "Signing update..."
    
    # Check if sign_update exists
    if command -v sign_update &> /dev/null; then
        SIGNATURE=$(sign_update "$ZIP_PATH" -f "$PRIVATE_KEY")
        echo -e "${GREEN}✓${NC} Signed update"
        echo ""
        echo -e "${YELLOW}EdDSA Signature:${NC}"
        echo "$SIGNATURE"
    else
        echo -e "${YELLOW}Warning: sign_update command not found${NC}"
        echo "Download Sparkle tools from: https://github.com/sparkle-project/Sparkle/releases"
        echo "Then run: sign_update $ZIP_PATH -f $PRIVATE_KEY"
    fi
else
    echo ""
    echo -e "${YELLOW}Skipping signing (no private key)${NC}"
fi

echo ""
echo -e "${GREEN}Release package created!${NC}"
echo ""
echo "Next steps:"
echo "1. Upload $ZIP_PATH to GitHub Releases or your server"
echo "2. Update appcast.xml with:"
echo "   - Version: $VERSION"
echo "   - URL: <your-download-url>/$ZIP_NAME"
echo "   - Length: $FILE_SIZE"
echo "   - EdDSA signature (from above)"
echo "3. Commit and push appcast.xml"
echo ""
