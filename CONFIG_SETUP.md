# Configuration Setup

## PostHog Analytics Setup

The app uses PostHog for analytics. The API key is stored in a Config.plist file that's not committed to git.

### Setup Steps

1. **Create Config.plist:**
   ```bash
   cp pace/Config.plist.template pace/Config.plist
   ```

2. **Add your PostHog API key:**
   - Open `pace/Config.plist` in Xcode or a text editor
   - Replace `your_posthog_api_key_here` with your actual PostHog API key
   - Update the host if needed (default is US region)

3. **Add to Xcode:**
   - Drag `pace/Config.plist` into Xcode's Project Navigator under the `pace` folder
   - Make sure "pace" target is checked

### File Structure

- `pace/Config.plist.template` - Template (committed to git)
- `pace/Config.plist` - Your actual keys (gitignored)
- `pace/Config.swift` - Swift wrapper to read config values
- `pace/AnalyticsManager.swift` - Uses Config.swift to get keys

### Security

- `Config.plist` is in `.gitignore` and will never be committed
- Share the template `Config.plist.template` with your team
- Each developer creates their own `Config.plist`

### For CI/CD

In your CI environment, create `pace/Config.plist` with your keys before building.
