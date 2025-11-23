# PostHog Analytics Debugging Guide

## Quick Diagnosis

Run this command to test your analytics setup:
```bash
./scripts/test_analytics.sh
```

## Common Issues & Solutions

### 1. No Events in PostHog Dashboard

**Possible Causes:**

#### A. PostHog SDK Not Configured Properly
- **Check:** Look for `🔧 Configuring PostHog...` in Console.app
- **Fix:** Make sure `AnalyticsManager.shared.configure()` is called in `paceApp.swift` init

#### B. API Key Not Loading
- **Check:** Console should show API key starting with `phc_`
- **Fix:** Verify `Config.plist` has correct API key
- **Fix:** Verify `Config.local.xcconfig` has correct API key

#### C. Network Blocked
- **Check:** `pace.entitlements` has `com.apple.security.network.client` = true
- **Check:** macOS Firewall isn't blocking the app
- **Fix:** System Settings → Network → Firewall → Allow Pace

#### D. Events Not Being Sent
- **Check:** Look for `📊 Tracking:` messages in Console.app
- **Fix:** Events are queued and sent in batches. With debug mode, they send immediately.

### 2. How to View Logs

#### Option 1: Console.app (Recommended)
1. Open Console.app (Applications → Utilities → Console)
2. In the search bar, type: `process:pace`
3. Click "Start" to stream logs
4. Launch Pace app
5. Look for messages with 🔧 and 📊 emojis

#### Option 2: Terminal
```bash
# Stream live logs
log stream --predicate 'process == "pace"' --level debug

# View recent logs
log show --predicate 'process == "pace"' --last 5m
```

### 3. Verify Configuration

Check your config files:

```bash
# Check Config.plist
cat pace/Config.plist | grep -A 1 "POSTHOG"

# Check Config.local.xcconfig
cat pace/Config.local.xcconfig | grep POSTHOG

# Verify PostHog package is linked
grep -q "posthog-ios" pace.xcodeproj/project.pbxproj && echo "✅ Package linked" || echo "❌ Package missing"
```

### 4. Test Events Manually

Add this to your code temporarily to force an event:

```swift
// In paceApp.swift init() after configure()
AnalyticsManager.shared.configure()
PostHogSDK.shared.capture("test_event", properties: ["test": "value"])
PostHogSDK.shared.flush()
NSLog("🧪 Test event sent!")
```

### 5. Check PostHog Dashboard

1. Go to https://app.posthog.com
2. Navigate to "Events" or "Live Events"
3. Events appear within 1-2 minutes
4. Look for events like:
   - `app_opened`
   - `pace_view_shown`
   - `mode_activated`

### 6. Debug Mode Settings

Current debug settings in `AnalyticsManager.swift`:

```swift
config.debug = true              // Enable verbose logging
config.flushAt = 1               // Send after 1 event (immediate)
config.flushIntervalSeconds = 10 // Flush every 10 seconds
```

For production, change to:
```swift
config.debug = false
config.flushAt = 20              // Send after 20 events
config.flushIntervalSeconds = 30 // Flush every 30 seconds
```

## Expected Log Output

When working correctly, you should see:

```
🔧 Configuring PostHog...
   API Key: phc_64VWTZ... (length: 43)
   Host: https://us.i.posthog.com
✅ PostHog configured successfully
📊 Tracking: app_opened
📊 Tracking: mode_activated (circle, medium)
📊 Tracking: pace_view_shown
```

## Still Not Working?

1. **Clean build:** Cmd+Shift+K in Xcode, then rebuild
2. **Check PostHog status:** https://status.posthog.com
3. **Verify API key:** Log into PostHog → Project Settings → API Keys
4. **Check host URL:** Should be `https://us.i.posthog.com` (or your region)
5. **Test with curl:**
   ```bash
   curl -X POST https://us.i.posthog.com/capture/ \
     -H "Content-Type: application/json" \
     -d '{
       "api_key": "YOUR_API_KEY",
       "event": "test_event",
       "properties": {"distinct_id": "test_user"}
     }'
   ```

## Contact

If none of these solutions work, check:
- PostHog iOS SDK docs: https://posthog.com/docs/libraries/ios
- PostHog community: https://posthog.com/questions
