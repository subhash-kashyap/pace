#!/bin/bash

# PostHog Analytics Integration Verification Script
# This script checks if the PostHog integration is properly set up

echo "🔍 Verifying PostHog Analytics Integration..."
echo ""

# Check if AnalyticsManager.swift exists
if [ -f "pace/AnalyticsManager.swift" ]; then
    echo "✅ AnalyticsManager.swift exists"
else
    echo "❌ AnalyticsManager.swift not found"
    exit 1
fi

# Check if API key has been configured
if grep -q "YOUR_POSTHOG_API_KEY" pace/AnalyticsManager.swift; then
    echo "⚠️  API key not configured yet"
    echo "   → Edit pace/AnalyticsManager.swift and add your PostHog API key"
else
    echo "✅ API key configured"
fi

# Check if PostHog is imported in paceApp.swift
if grep -q "AnalyticsManager" pace/paceApp.swift; then
    echo "✅ AnalyticsManager integrated in paceApp.swift"
else
    echo "❌ AnalyticsManager not found in paceApp.swift"
    exit 1
fi

# Check if Package.resolved contains PostHog
if [ -f "pace.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
    if grep -q "posthog" pace.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved; then
        echo "✅ PostHog package added to project"
    else
        echo "⚠️  PostHog package not found in Package.resolved"
        echo "   → Add PostHog package in Xcode:"
        echo "   → File → Add Package Dependencies → https://github.com/PostHog/posthog-ios"
    fi
else
    echo "⚠️  Package.resolved not found"
    echo "   → Add PostHog package in Xcode first"
fi

# Count tracking calls
TRACKING_CALLS=$(grep -c "AnalyticsManager.shared" pace/paceApp.swift)
echo "✅ Found $TRACKING_CALLS tracking calls in paceApp.swift"

echo ""
echo "📋 Integration Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if ready to build
if grep -q "YOUR_POSTHOG_API_KEY" pace/AnalyticsManager.swift; then
    echo "⚠️  NOT READY - Configure API key first"
    echo ""
    echo "Next steps:"
    echo "1. Sign up at https://app.posthog.com/signup"
    echo "2. Get your API key from Project Settings"
    echo "3. Edit pace/AnalyticsManager.swift line 13"
    echo "4. Add PostHog package in Xcode"
    echo "5. Build and run!"
elif ! grep -q "posthog" pace.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved 2>/dev/null; then
    echo "⚠️  ALMOST READY - Add PostHog package"
    echo ""
    echo "Next steps:"
    echo "1. Open pace.xcodeproj in Xcode"
    echo "2. File → Add Package Dependencies"
    echo "3. URL: https://github.com/PostHog/posthog-ios"
    echo "4. Build and run!"
else
    echo "✅ READY TO BUILD!"
    echo ""
    echo "Next steps:"
    echo "1. Build and run the app"
    echo "2. Use the app for a minute"
    echo "3. Check PostHog dashboard"
    echo "4. See TESTING_ANALYTICS.md for test checklist"
fi

echo ""
echo "📚 Documentation:"
echo "  • QUICK_START.md - 5-minute setup guide"
echo "  • ANALYTICS_EVENTS.md - Event reference"
echo "  • TESTING_ANALYTICS.md - Testing checklist"
echo ""
