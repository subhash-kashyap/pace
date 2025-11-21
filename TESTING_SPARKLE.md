# Testing Sparkle Auto-Update

## Test 1: Basic Integration Test (No Update Available)

This tests that Sparkle is properly integrated and can check for updates.

### Setup:
1. Make sure your `appcast.xml` is accessible at the URL in Info.plist
2. Current version in Info.plist should match the version in appcast.xml (1.0.0)

### Steps:
1. Build and run Pace from Xcode (Cmd+R)
2. Click the menu bar icon (flashlight)
3. Click "Check for Updates..."
4. **Expected Result**: Dialog saying "You're up to date!" or "No updates available"

### If it fails:
- Check Console.app for Sparkle error messages
- Verify the SUFeedURL in Info.plist is correct and accessible
- Make sure network entitlement is enabled

---

## Test 2: Simulated Update Test (Update Available)

This tests the full update flow by simulating an older version.

### Setup:
1. Temporarily change version in `pace/Info.plist`:
   ```xml
   <key>CFBundleShortVersionString</key>
   <string>0.9.0</string>
   ```
2. Make sure `appcast.xml` has version 1.0.0 (higher than 0.9.0)
3. The appcast.xml should be accessible at the URL in Info.plist

### Steps:
1. Build and run Pace from Xcode
2. Click the menu bar icon
3. Click "Check for Updates..."
4. **Expected Result**: 
   - Dialog appears: "A new version of Pace is available!"
   - Shows version 1.0.0 with release notes
   - Offers "Install Update" button

5. Click "Install Update"
6. **Expected Result**:
   - Download progress shown
   - App quits and relaunches with new version
   - (In this test, it will fail to install since the zip doesn't exist yet)

### Restore:
- Change version back to 1.0.0 in Info.plist

---

## Test 3: Local Appcast Test (Recommended for Development)

Test without needing to publish anything online.

### Setup:

1. Create a local test appcast:
   ```bash
   mkdir -p ~/Desktop/pace-test
   cp appcast.xml ~/Desktop/pace-test/
   ```

2. Edit `pace/Info.plist` to use local file:
   ```xml
   <key>SUFeedURL</key>
   <string>file:///Users/YOUR_USERNAME/Desktop/pace-test/appcast.xml</string>
   ```

3. Set version to 0.9.0 in Info.plist

4. Edit `~/Desktop/pace-test/appcast.xml`:
   - Change version to 1.0.0
   - Change URL to a local file (or leave it, download will just fail)

### Steps:
1. Build and run Pace
2. Click "Check for Updates..."
3. **Expected Result**: Should detect version 1.0.0 is available

### Restore:
- Change SUFeedURL back to your GitHub URL
- Change version back to 1.0.0

---

## Test 4: Full End-to-End Test (With Real Release)

This tests the complete update flow with a real release package.

### Prerequisites:
- You've created a signed release zip (Pace-1.0.0.zip)
- Uploaded it to GitHub Releases or a server
- Updated appcast.xml with correct URL and signature
- Appcast.xml is accessible at the URL in Info.plist

### Steps:

1. **Build version 0.9.0:**
   - Change Info.plist version to 0.9.0
   - Build and Archive in Xcode
   - Export the app to Desktop
   - Quit Xcode

2. **Install and run the old version:**
   - Copy Pace.app to /Applications
   - Run it from /Applications (not from Xcode!)
   - Click menu bar icon → "Check for Updates..."

3. **Expected Flow:**
   - ✅ Dialog: "A new version of Pace is available!"
   - ✅ Shows version 1.0.0 and release notes
   - ✅ Click "Install Update"
   - ✅ Download progress bar appears
   - ✅ "Ready to Install" dialog appears
   - ✅ Click "Install and Relaunch"
   - ✅ App quits
   - ✅ New version launches automatically
   - ✅ Menu shows version 1.0.0 (check About or version in Info.plist)

4. **Verify:**
   - Click "Check for Updates..." again
   - Should say "You're up to date!"

---

## Quick Test Checklist

- [ ] Menu bar icon appears
- [ ] "Check for Updates..." menu item exists
- [ ] Clicking it shows Sparkle dialog (not a crash)
- [ ] With same version: "You're up to date"
- [ ] With older version: "Update available" dialog
- [ ] Release notes display correctly
- [ ] Download progress works
- [ ] Install and relaunch works
- [ ] Automatic checks work (wait 24 hours or change interval)

---

## Debugging Tips

### Check Sparkle Logs:
```bash
# Open Console.app and filter for "Sparkle" or "pace"
# Or check from terminal:
log stream --predicate 'process == "pace"' --level debug
```

### Common Issues:

**"No updates available" when there should be:**
- Check appcast.xml is accessible (open URL in browser)
- Verify version numbers (appcast version > current version)
- Check CFBundleShortVersionString format (must be semantic versioning)

**Update dialog doesn't appear:**
- Check Console.app for Sparkle errors
- Verify SUFeedURL is correct in Info.plist
- Make sure network entitlement is enabled

**Download fails:**
- Verify the enclosure URL in appcast.xml is correct
- Check the file is publicly accessible
- Verify EdDSA signature matches the zip file

**Install fails:**
- Check code signing on the new version
- Verify the zip contains Pace.app at the root level
- Check file permissions

---

## Recommended Test Order

1. **Start with Test 1** - Verify basic integration works
2. **Then Test 3** - Test locally without publishing anything
3. **Then Test 2** - Verify update detection logic
4. **Finally Test 4** - Full end-to-end with real release

This way you can catch issues early without needing to publish anything first!
