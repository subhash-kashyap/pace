#!/bin/bash

echo "🔍 Verifying PostHog Integration..."
echo ""

# Check if PostHog is in project.pbxproj
if grep -q "posthog-ios" pace.xcodeproj/project.pbxproj; then
    echo "✅ PostHog package found in Xcode project"
else
    echo "❌ PostHog package NOT found in Xcode project"
    echo "   → Add it via: File → Add Package Dependencies"
    echo "   → URL: https://github.com/PostHog/posthog-ios"
    exit 1
fi

# Check if Config.plist exists and has API key
if [ -f "pace/Config.plist" ]; then
    if grep -q "phc_" pace/Config.plist; then
        echo "✅ PostHog API key found in Config.plist"
    else
        echo "⚠️  Config.plist exists but API key looks invalid"
    fi
else
    echo "❌ Config.plist not found"
    exit 1
fi

# Check if AnalyticsManager imports PostHog
if grep -q "import PostHog" pace/AnalyticsManager.swift; then
    echo "✅ AnalyticsManager imports PostHog"
else
    echo "❌ AnalyticsManager doesn't import PostHog"
    exit 1
fi

# Check if analytics is configured in paceApp
if grep -q "AnalyticsManager.shared.configure()" pace/paceApp.swift; then
    echo "✅ Analytics configured in app initialization"
else
    echo "❌ Analytics not configured in app initialization"
    exit 1
fi

echo ""
echo "📊 Next steps:"
echo "1. Build and run the app"
echo "2. Interact with the app (toggle views, change modes)"
echo "3. Check PostHog dashboard in 1-2 minutes"
echo "   → https://app.posthog.com"
