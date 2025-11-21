# Release Checklist

Quick reference for publishing a new version of Pace.

## Pre-Release

- [ ] Update version in `pace/Info.plist`:
  - [ ] `CFBundleShortVersionString` (e.g., "1.1.0")
  - [ ] `CFBundleVersion` (increment build number)
- [ ] Test all features work correctly
- [ ] Update release notes in `appcast.xml`

## Build

- [ ] Open project in Xcode
- [ ] Select "Any Mac" as destination
- [ ] Product → Archive
- [ ] Distribute App → Copy App
- [ ] Save to Desktop or known location

## Package & Sign

```bash
# Run the release script
./scripts/create_release.sh 1.1.0 ~/Desktop/Pace.app ~/.sparkle_private_key

# Or manually:
ditto -c -k --sequesterRsrc --keepParent Pace.app Pace-1.1.0.zip
sign_update Pace-1.1.0.zip -f ~/.sparkle_private_key
```

## Publish

### GitHub Releases (Recommended)

- [ ] Create new release on GitHub
  - Tag: `v1.1.0`
  - Title: `Pace 1.1.0`
  - Description: Copy from appcast.xml release notes
- [ ] Upload `Pace-1.1.0.zip` as release asset
- [ ] Copy download URL from uploaded asset

### Update Appcast

- [ ] Edit `appcast.xml`
- [ ] Add new `<item>` at the top with:
  - [ ] Version number
  - [ ] Release date
  - [ ] Release notes
  - [ ] Download URL (from GitHub release)
  - [ ] EdDSA signature (from sign_update output)
  - [ ] File size in bytes
- [ ] Commit and push `appcast.xml`

## Verify

- [ ] Download and install the release manually
- [ ] Build an older version (change version to 1.0.0)
- [ ] Run it and click "Check for Updates..."
- [ ] Verify update is detected and installs correctly

## Post-Release

- [ ] Announce on social media / website
- [ ] Update README if needed
- [ ] Close related GitHub issues

## Example appcast.xml Entry

```xml
<item>
    <title>Version 1.1.0</title>
    <description>
        <![CDATA[
            <h2>What's New</h2>
            <ul>
                <li>New feature X</li>
                <li>Fixed bug Y</li>
            </ul>
        ]]>
    </description>
    <pubDate>Wed, 20 Nov 2025 12:00:00 +0000</pubDate>
    <sparkle:version>1.1.0</sparkle:version>
    <sparkle:shortVersionString>1.1.0</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>11.5</sparkle:minimumSystemVersion>
    <enclosure 
        url="https://github.com/YOUR_USERNAME/pace/releases/download/v1.1.0/Pace-1.1.0.zip"
        sparkle:edSignature="YOUR_SIGNATURE_HERE"
        length="FILE_SIZE_IN_BYTES"
        type="application/octet-stream"
    />
</item>
```
