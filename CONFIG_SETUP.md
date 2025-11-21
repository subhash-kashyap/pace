# Configuration Setup

## PostHog Analytics Setup

The app uses PostHog for analytics. The API key is stored in a local config file that's not committed to git.

### Setup Steps

1. **Copy the template config:**
   ```bash
   cp pace/Config.xcconfig pace/Config.local.xcconfig
   ```

2. **Add your PostHog API key:**
   - Open `pace/Config.local.xcconfig`
   - Replace `your_posthog_api_key_here` with your actual PostHog API key
   - Update the host if needed (default is US region)

3. **Configure Xcode project:**
   - Open `pace.xcodeproj` in Xcode
   - Select the project in the navigator
   - Select the "pace" target
   - Go to "Info" tab
   - Under "Configurations", set the configuration file:
     - Debug: `pace/Config.local.xcconfig`
     - Release: `pace/Config.local.xcconfig`

### File Structure

- `pace/Config.xcconfig` - Template (committed to git)
- `pace/Config.local.xcconfig` - Your actual keys (gitignored)
- `pace/Config.swift` - Swift wrapper to read config values
- `pace/AnalyticsManager.swift` - Uses Config.swift to get keys

### Security

- `Config.local.xcconfig` is in `.gitignore` and will never be committed
- Share the template `Config.xcconfig` with your team
- Each developer creates their own `Config.local.xcconfig`

### For CI/CD

In your CI environment, create `pace/Config.local.xcconfig` with:
```
POSTHOG_API_KEY = ${POSTHOG_API_KEY}
POSTHOG_HOST = https://us.i.posthog.com
```

And set `POSTHOG_API_KEY` as an environment variable in your CI system.
