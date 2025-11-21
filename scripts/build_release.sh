#!/bin/bash

# Build Release Script for Pace
# Creates a distributable .zip file

set -e  # Exit on error

echo "🚀 Building Pace Release..."

# Configuration
PROJECT_NAME="pace"
SCHEME="pace"
BUILD_DIR="build"
RELEASE_DIR="releases"
APP_NAME="Pace.app"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$RELEASE_DIR"

# Build the app
echo "🔨 Building Release configuration..."
xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    clean build

# Find the built app
BUILT_APP="$BUILD_DIR/Build/Products/Release/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
    echo "❌ Error: Built app not found at $BUILT_APP"
    exit 1
fi

echo "✅ Build successful!"

# Get version from Info.plist
VERSION=$(defaults read "$(pwd)/$BUILT_APP/Contents/Info.plist" CFBundleShortVersionString)
BUILD=$(defaults read "$(pwd)/$BUILT_APP/Contents/Info.plist" CFBundleVersion)

echo "📦 Version: $VERSION (Build $BUILD)"

# Create zip file
ZIP_NAME="Pace-${VERSION}.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"

echo "📦 Creating zip archive..."
cd "$BUILD_DIR/Build/Products/Release"
zip -r -y "../../../../$ZIP_PATH" "$APP_NAME"
cd - > /dev/null

# Calculate file size
FILE_SIZE=$(stat -f%z "$ZIP_PATH")
FILE_SIZE_MB=$(echo "scale=2; $FILE_SIZE / 1048576" | bc)

echo ""
echo "✨ Release build complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 File: $ZIP_PATH"
echo "📏 Size: ${FILE_SIZE_MB} MB"
echo "🔢 Version: $VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "1. Test the app: unzip and run $ZIP_PATH"
echo "2. Upload to your website"
echo "3. Update download link to point to $ZIP_NAME"
echo ""
