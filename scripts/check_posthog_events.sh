#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 PostHog Event Checker"
echo "======================="
echo ""

# Get API key from Config.plist
API_KEY=$(grep -A 1 "POSTHOG_API_KEY" pace/Config.plist | grep "string" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

if [ -z "$API_KEY" ] || [ "$API_KEY" == "your_posthog_api_key_here" ]; then
    echo -e "${RED}❌ No valid API key found in Config.plist${NC}"
    exit 1
fi

echo -e "${GREEN}✅ API Key found:${NC} ${API_KEY:0:10}..."
echo ""

# Test connection to PostHog
echo "🌐 Testing connection to PostHog..."
RESPONSE=$(curl -s -X POST https://us.i.posthog.com/capture/ \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"$API_KEY\",
    \"event\": \"test_connection\",
    \"properties\": {
      \"distinct_id\": \"test_user_$(date +%s)\",
      \"source\": \"debug_script\"
    }
  }")

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Successfully sent test event to PostHog${NC}"
    echo ""
    echo "📊 Check your PostHog dashboard:"
    echo "   https://app.posthog.com"
    echo ""
    echo "   Look for event: 'test_connection'"
    echo "   It should appear within 1-2 minutes"
else
    echo -e "${RED}❌ Failed to connect to PostHog${NC}"
    echo "   Check your internet connection"
    echo "   Verify API key is correct"
fi

echo ""
echo "💡 Tips:"
echo "   • Events are batched and sent every 10-30 seconds"
echo "   • Check Console.app for '📊 Tracking:' messages"
echo "   • Run ./scripts/test_analytics.sh for detailed logs"
