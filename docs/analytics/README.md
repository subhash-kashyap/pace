# PostHog Analytics Integration

Complete analytics for tracking daily users, time in Pace view, and mode usage.

## Quick Setup (5 minutes)

### 1. Add PostHog Package
```
Xcode → File → Add Package Dependencies
URL: https://github.com/PostHog/posthog-ios
```

### 2. Get API Key
- Sign up at https://app.posthog.com/signup
- Copy your project API key

### 3. Configure
Edit `pace/AnalyticsManager.swift` line 13:
```swift
let config = PostHogConfig(apiKey: "phc_your_key_here")
```

### 4. Build & Run
Done! Analytics are now tracking.

## What Gets Tracked

### Your 3 Key Metrics

**1. Daily Active Users**
- Event: `app_opened`
- View: Insights → app_opened → Unique users → Group by day

**2. Time in Pace View**
- Event: `pace_view_hidden` 
- Property: `view_duration_seconds`
- View: Insights → pace_view_hidden → Average of view_duration_seconds

**3. Mode Usage & Duration**
- Events: `mode_activated`, `mode_deactivated`
- Properties: `mode` (rectangle/centerColumn/square/circle), `size` (S/M/L), `duration_seconds`
- View: mode_activated → Break down by mode (popularity)
- View: mode_deactivated → Average of duration_seconds → Break down by mode (time)

### All Events

| Event | Properties | When |
|-------|-----------|------|
| `app_opened` | - | App launches |
| `app_closed` | `session_duration_seconds` | App quits |
| `pace_view_shown` | - | Overlay shown |
| `pace_view_hidden` | `view_duration_seconds` | Overlay hidden |
| `mode_activated` | `mode`, `size` | Mode selected |
| `mode_deactivated` | `mode`, `duration_seconds` | Mode ended |
| `focus_mode_shown` | - | Focus message opened |
| `focus_mode_hidden` | `duration_seconds` | Focus message closed |
| `flash_mode_toggled` | `is_active` | Flash on/off |
| `flash_triggered` | - | Flash played |

## Testing

1. Run the app
2. Toggle Pace view on/off
3. Switch between modes
4. Check PostHog dashboard in 1-2 minutes

Run verification:
```bash
./verify_analytics.sh
```

## Sample Dashboards

### Daily Active Users
```
Event: app_opened
Unique users
Last 30 days
Group by: Day
```

### Average Session Time
```
Event: app_closed
Average of: session_duration_seconds
Formula: value / 60 (minutes)
```

### Most Popular Mode
```
Event: mode_activated
Total count
Break down by: mode
```

### Time Per Mode
```
Event: mode_deactivated
Average of: duration_seconds
Break down by: mode
Formula: value / 60 (minutes)
```

## Privacy

✅ No personal data  
✅ No text content  
✅ No screen content  
✅ Only usage patterns

## Troubleshooting

**No events?**
- Verify API key starts with `phc_`
- Check internet connection
- Wait 1-2 minutes

**Build errors?**
- Clean build folder (Cmd+Shift+K)
- Verify PostHog package is linked

**Debug mode:**
```swift
config.debug = true  // in AnalyticsManager.swift
```

## Resources

- PostHog Docs: https://posthog.com/docs
- iOS SDK: https://posthog.com/docs/libraries/ios
