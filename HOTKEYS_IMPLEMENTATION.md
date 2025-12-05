# Global Hotkeys Implementation

## What Changed

Replaced the broken `NSEvent.addGlobalMonitorForEvents()` approach with `CGEventTap`, which is the only reliable way to capture keyboard events system-wide.

## Hotkeys

- **⌃⌥O** (Control + Option + O) → Cycle focus modes (rectangle → square → center column → circle)
- **⌃⌥P** (Control + Option + P) → Cycle sizes (S → M → L)
- **⌃⌥L** (Control + Option + L) → Turn off overlay
- **⌃⌥F** (Control + Option + F) → Toggle focus message

## Required Permissions

The app now requires **two** permissions for global hotkeys to work:

1. **Accessibility** - Already requested by the app
2. **Input Monitoring** - Will be requested automatically when the event tap is created

### How to Grant Permissions

1. Run the app
2. macOS will show a system prompt for **Input Monitoring** permission
3. Click "Open System Settings" 
4. Enable "Pace" in **System Settings > Privacy & Security > Input Monitoring**
5. **Restart the app** for changes to take effect

## Technical Details

### Why NSEvent Monitors Don't Work

- `NSEvent.addGlobalMonitorForEvents()` does NOT receive `keyDown` events when other apps are focused
- This is by design - it's not a secure API for global hotkeys
- Only works for mouse events (which is why the mouse tracker works)

### Why CGEventTap Works

- `CGEventTap` operates at the system level (CGSession)
- Captures events before they reach applications
- Requires Input Monitoring permission (more secure)
- Used by all professional apps (Raycast, Alfred, Magnet, Rectangle)

### Implementation

Created `GlobalHotkeyManager` class in `paceApp.swift`:
- Uses `CGEvent.tapCreate()` with `.cgSessionEventTap`
- Filters for Control + Option modifier combination
- Dispatches actions to main thread
- Swallows handled events (returns `nil`)
- Passes through all other events

## Testing

1. Build and run the app
2. Grant Input Monitoring permission when prompted
3. Restart the app
4. Click into another app (Chrome, Finder, etc.)
5. Press ⌃⌥O - should cycle focus modes even when other app is focused
6. Check console for: `✅ Global hotkey manager initialized with CGEventTap`

## Console Output

Success:
```
✅ Global hotkey manager initialized with CGEventTap
🎹 ⌃⌥O Cycling focus mode
```

Failure (no permission):
```
❌ Failed to create CGEventTap - Input Monitoring permission may be required
⚠️ Hotkey manager failed to initialize - check Input Monitoring permissions
```

## Distribution Notes

For release builds:
- App must be code-signed
- Hardened runtime enabled (default)
- No special entitlements needed
- Notarization works fine with CGEventTap
