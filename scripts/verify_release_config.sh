#!/bin/bash

# Verify Release Build Configuration
# Checks if the built app has PostHog API key configured

set -e

echo "🔍 Verifying Release Build Configuration..."
echo ""

# Check if build exists
BUILD_APP="build/Build/Products/Release/Pace.app"

if [ ! -d "$BUILD_APP" ]; then
    echo "❌ Release build not found at $BUILD_APP"
    echo "   Run: ./scripts/build_release.sh first"
    exit 1
fi

echo "📦 Checking: $BUILD_APP"
echo ""

# Check Info.plist for PostHog config
INFO_PLIST="$BUILD_APP/Contents/Info.plist"

if [ -f "$INFO_PLIST" ]; then
    echo "Checking Info.plist..."
    
    API_KEY=$(defaults read "$(pwd)/$INFO_PLIST" POSTHOG_API_KEY 2>/dev/null || echo "")
    HOST=$(defaults read "$(pwd)/$INFO_PLIST" POSTHOG_HOST 2>/dev/null || echo "")
    
    if [ -n "$API_KEY" ] && [ "$API_KEY" != "\$(POSTHOG_API_KEY)" ]; then
        echo "✅ POSTHOG_API_KEY: ${API_KEY:0:10}... (length: ${#API_KEY})"
    else
        echo "❌ POSTHOG_API_KEY: Missing or unresolved variable"
    fi
    
    if [ -n "$HOST" ] && [ "$HOST" != "\$(POSTHOG_HOST)" ]; then
        echo "✅ POSTHOG_HOST: $HOST"
    else
        echo "❌ POSTHOG_HOST: Missing or unresolved variable"
    fi
fi

# Check if Config.plist is bundled
CONFIG_PLIST="$BUILD_APP/Contents/Resources/Config.plist"

if [ -f "$CONFIG_PLIST" ]; then
    echo ""
    echo "Checking Config.plist..."
    
    API_KEY=$(defaults read "$(pwd)/$CONFIG_PLIST" POSTHOG_API_KEY 2>/dev/null || echo "")
    HOST=$(defaults read "$(pwd)/$CONFIG_PLIST" POSTHOG_HOST 2>/dev/null || echo "")
    
    if [ -n "$API_KEY" ] && [[ "$API_KEY" == phc_* ]]; then
        echo "✅ POSTHOG_API_KEY: ${API_KEY:0:10}... (length: ${#API_KEY})"
    else
        echo "❌ POSTHOG_API_KEY: Invalid or missing"
    fi
    
    if [ -n "$HOST" ]; then
        echo "✅ POSTHOG_HOST: $HOST"
    else
        echo "❌ POSTHOG_HOST: Missing"
    fi
else
    echo "⚠️  Config.plist not found in app bundle"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Final verdict
if [ -f "$CONFIG_PLIST" ]; then
    API_KEY=$(defaults read "$(pwd)/$CONFIG_PLIST" POSTHOG_API_KEY 2>/dev/null || echo "")
    if [[ "$API_KEY" == phc_* ]]; then
        echo "✅ Release build is properly configured!"
        echo "   Analytics will work for users"
        exit 0
    fi
fi

echo "❌ Release build is NOT properly configured"
echo "   Users won't be able to send analytics"
echo ""
echo "Fix: Ensure Config.plist is included in Copy Bundle Resources"
exit 1
