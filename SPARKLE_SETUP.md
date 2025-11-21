# Sparkle Auto-Update Setup Guide

Sparkle has been integrated into Pace! Here's what you need to do to complete the setup.

## 1. Generate EdDSA Keys

First, you need to generate a key pair for signing your updates:

```bash
# Install Sparkle's command-line tools (if not already installed)
# You can download from: https://github.com/sparkle-project/Sparkle/releases

# Generate keys
./bin/generate_keys

# This will output:
# - A public key (add to Info.plist)
# - A private key (keep secret, use for signing releases)
```

## 2. Update Info.plist

Replace the placeholder in `pace/Info.plist`:

```xml
<key>SUPublicEDKey</key>
<string>YOUR_ACTUAL_PUBLIC_KEY_HERE</string>
```

Also update the feed URL to point to your actual repository:

```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/YOUR_USERNAME/pace/main/appcast.xml</string>
```

## 3. Build and Archive

In Xcode:
1. Select "Any Mac" as the destination
2. Product → Archive
3. Once archived, click "Distribute App"
4. Choose "Copy App"
5. Save the exported app

## 4. Create Release Package

```bash
# Create a zip of your app
cd /path/to/exported/app
ditto -c -k --sequesterRsrc --keepParent Pace.app Pace-1.0.0.zip

# Sign the zip with your private key
./bin/sign_update Pace-1.0.0.zip -f YOUR_PRIVATE_KEY

# This outputs the EdDSA signature you'll need for appcast.xml
```

## 5. Update appcast.xml

Update the `appcast.xml` file with:
- The correct download URL (GitHub releases or your hosting)
- The EdDSA signature from step 4
- The file size (in bytes): `ls -l Pace-1.0.0.zip`

```xml
<enclosure 
    url="https://github.com/YOUR_USERNAME/pace/releases/download/v1.0.0/Pace-1.0.0.zip"
    sparkle:edSignature="YOUR_SIGNATURE_HERE"
    length="FILE_SIZE_IN_BYTES"
    type="application/octet-stream"
/>
```

## 6. Publish Release

### Using GitHub Releases:

1. Create a new release on GitHub (tag: v1.0.0)
2. Upload `Pace-1.0.0.zip` as a release asset
3. Commit and push the updated `appcast.xml` to your main branch

### Using Custom Hosting:

1. Upload `Pace-1.0.0.zip` to your server
2. Upload `appcast.xml` to your server
3. Make sure both are publicly accessible

## 7. Test Updates

To test the update mechanism:

1. Build and run the current version
2. Click "Check for Updates..." in the menu
3. It should find no updates (since you're on the latest)

To test an actual update:
1. Change the version in Info.plist to 0.9.0
2. Build and run
3. Click "Check for Updates..."
4. It should offer to update to 1.0.0

## Future Releases

For each new release:

1. Update version in `pace/Info.plist`:
   - `CFBundleShortVersionString` (e.g., "1.1.0")
   - `CFBundleVersion` (increment build number)

2. Build, archive, and export the app

3. Create and sign the zip:
   ```bash
   ditto -c -k --sequesterRsrc --keepParent Pace.app Pace-1.1.0.zip
   ./bin/sign_update Pace-1.1.0.zip -f YOUR_PRIVATE_KEY
   ```

4. Add a new `<item>` to the top of `appcast.xml` with the new version info

5. Upload the zip and push the updated appcast.xml

## Security Notes

- **Never commit your private key to the repository**
- Store it securely (password manager, encrypted storage)
- The public key in Info.plist is safe to commit
- Users will only install updates signed with your private key

## Automatic Update Checks

The app is configured to:
- Check for updates automatically every 24 hours
- Allow users to manually check via the menu
- Show update notifications when available

You can adjust these settings in `pace/Info.plist`:
- `SUScheduledCheckInterval`: seconds between checks (86400 = 24 hours)
- `SUEnableAutomaticChecks`: set to false to disable auto-checks

## Resources

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Sparkle 2 Migration Guide](https://sparkle-project.org/documentation/sparkle-2/)
- [Publishing Updates](https://sparkle-project.org/documentation/publishing/)
