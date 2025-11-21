#!/bin/bash

# Quick setup for local Sparkle testing
# This creates a local appcast for testing without publishing online

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}Setting up local Sparkle test environment${NC}"
echo ""

# Create test directory
TEST_DIR="$HOME/Desktop/pace-sparkle-test"
mkdir -p "$TEST_DIR"

# Copy appcast
cp appcast.xml "$TEST_DIR/"

echo -e "${GREEN}✓${NC} Created test directory: $TEST_DIR"
echo -e "${GREEN}✓${NC} Copied appcast.xml"
echo ""

# Create a test appcast with version 1.1.0
cat > "$TEST_DIR/appcast.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Pace Updates (Test)</title>
        <link>file:///Users/local/Desktop/pace-sparkle-test/appcast.xml</link>
        <description>Test updates for Pace</description>
        <language>en</language>
        <item>
            <title>Version 1.1.0 (Test)</title>
            <description>
                <![CDATA[
                    <h2>Test Update</h2>
                    <p>This is a test update to verify Sparkle integration.</p>
                    <ul>
                        <li>✅ Update detection working</li>
                        <li>✅ Release notes displaying</li>
                        <li>✅ Sparkle integration successful</li>
                    </ul>
                ]]>
            </description>
            <pubDate>Fri, 21 Nov 2025 12:00:00 +0000</pubDate>
            <sparkle:version>1.1.0</sparkle:version>
            <sparkle:shortVersionString>1.1.0</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>11.5</sparkle:minimumSystemVersion>
            <enclosure 
                url="https://example.com/Pace-1.1.0.zip"
                sparkle:edSignature="test-signature"
                length="1000000"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
EOF

echo -e "${GREEN}✓${NC} Created test appcast with version 1.1.0"
echo ""

# Get current username
USERNAME=$(whoami)
LOCAL_URL="file:///Users/$USERNAME/Desktop/pace-sparkle-test/appcast.xml"

echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Update pace/Info.plist:"
echo -e "   ${BLUE}Change SUFeedURL to:${NC}"
echo "   $LOCAL_URL"
echo ""
echo "2. Change version in pace/Info.plist to 1.0.0 (or lower)"
echo ""
echo "3. Build and run Pace in Xcode"
echo ""
echo "4. Click 'Check for Updates...'"
echo ""
echo -e "${GREEN}Expected result:${NC} Should detect version 1.1.0 is available!"
echo ""
echo -e "${YELLOW}Note:${NC} Download will fail (no actual zip file), but that's OK."
echo "This test verifies update detection is working."
echo ""
echo -e "${YELLOW}To restore:${NC}"
echo "1. Change SUFeedURL back to your GitHub URL"
echo "2. Delete $TEST_DIR"
echo ""
