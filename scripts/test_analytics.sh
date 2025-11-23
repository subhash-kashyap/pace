#!/bin/bash

echo "🧪 Testing PostHog Analytics Integration"
echo ""
echo "This script will:"
echo "1. Kill any running Pace app"
echo "2. Launch Pace with console logging"
echo "3. Show PostHog-related logs"
echo ""

# Kill existing pace process
pkill -9 pace 2>/dev/null

# Clear console
clear

echo "🚀 Launching Pace..."
echo "📝 Watching for PostHog logs..."
echo ""

# Launch app and watch logs
open /Users/local/Library/Developer/Xcode/DerivedData/pace-bieudzerwgoyxjbqokgjmrxfsmuw/Build/Products/Debug/pace.app &

# Wait a moment for app to start
sleep 2

# Show logs
echo "=== Console Logs (last 30 seconds) ==="
log show --predicate 'process == "pace"' --last 30s --style syslog 2>&1 | grep -v "com.apple" | head -50

echo ""
echo "=== Checking for PostHog activity ==="
log show --predicate 'process == "pace"' --last 30s 2>&1 | grep -i "posthog\|tracking\|analytics" | head -20

echo ""
echo "✅ If you see '🔧 Configuring PostHog' and '📊 Tracking' messages above, analytics is working!"
echo "⏰ Events should appear in PostHog dashboard within 1-2 minutes"
echo "🌐 Check: https://app.posthog.com"
