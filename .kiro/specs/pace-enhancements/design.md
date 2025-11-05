# Design Document: Flash Mode

## Overview

Flash Mode adds a timer-based visual notification system to Pace. It displays a pulsing blue border around the screen every 25 minutes to remind users to take breaks. The feature integrates with the existing menu bar system and runs independently of other Pace modes.

## Architecture

### Component Structure

```
AppDelegate (existing)
├── flashWindow: FlashWindow? (new)
├── flashMenuItem: NSMenuItem? (new)
├── flashTimer: Timer? (new)
└── isFlashModeActive: Bool (new)

FlashWindow (new)
└── contentView: FlashBorderView

FlashBorderView (new)
└── SwiftUI view with border animation
```

### Integration Points

- **Menu Bar**: Add Flash Mode toggle item to existing tray menu in `setupMenuBar()`
- **Window Management**: FlashWindow operates independently alongside OverlayWindow and FocusWindow
- **Timer Management**: 25-minute timer managed by AppDelegate
- **Lifecycle**: Flash mode state persists only during app session (no UserDefaults needed)

## Components and Interfaces

### 1. AppDelegate Extensions

Add to existing AppDelegate class:

```swift
// Properties
var flashWindow: FlashWindow?
private var flashMenuItem: NSMenuItem?
private var flashTimer: Timer?
@Published var isFlashModeActive: Bool = false

// Methods
@objc func toggleFlashMode()
func startFlashTimer()
func cancelFlashTimer()
func showFlashBorder()
```

**Responsibilities:**
- Toggle Flash Mode on/off
- Manage 25-minute timer lifecycle
- Trigger flash border display
- Update menu item state

### 2. FlashWindow (new class)

```swift
class FlashWindow: NSWindow {
    convenience init()
}
```

**Configuration:**
- Window level: `.screenSaver` (same as OverlayWindow)
- Style: borderless, full screen
- Behavior: ignores mouse events, transparent background
- Collection behavior: `.canJoinAllSpaces`, `.fullScreenAuxiliary`

**Responsibilities:**
- Host FlashBorderView
- Remain hidden until triggered
- Show/hide on demand

### 3. FlashBorderView (new SwiftUI view)

```swift
struct FlashBorderView: View {
    @State private var opacity: Double = 0.0
    @State private var pulseCount: Int = 0
    var onComplete: () -> Void
}
```

**Visual Specifications:**
- Border color: Blue (`.blue` or custom RGB)
- Border width: 8-12 points (start with 10pt)
- Border style: Inset stroke on all four edges
- Animation: 10 pulses over 5 seconds (0.5s per pulse)

**Animation Logic:**
- Pulse: opacity 0.0 → 0.8 → 0.0 (ease in/out)
- Duration: 5 seconds total
- Callback: `onComplete()` when animation finishes

**Responsibilities:**
- Render blue border on all screen edges
- Execute pulse animation
- Notify when animation completes

## Data Models

No persistent data models needed. Runtime state only:

```swift
// In AppDelegate
isFlashModeActive: Bool  // Current mode state
flashTimer: Timer?       // Active timer reference
```

## Implementation Details

### Menu Integration

Add Flash Mode item after Focus Mode separator:

```swift
menu.addItem(NSMenuItem.separator())
flashMenuItem = NSMenuItem(
    title: "Flash Mode", 
    action: #selector(toggleFlashMode), 
    keyEquivalent: ""
)
menu.addItem(flashMenuItem!)
```

Update checkmark based on `isFlashModeActive`.

### Timer Behavior

```swift
func startFlashTimer() {
    cancelFlashTimer()
    flashTimer = Timer.scheduledTimer(
        withTimeInterval: 25 * 60,  // 25 minutes
        repeats: true
    ) { [weak self] _ in
        self?.showFlashBorder()
    }
}

func cancelFlashTimer() {
    flashTimer?.invalidate()
    flashTimer = nil
}
```

### Flash Trigger Flow

1. User clicks "Flash Mode" menu item
2. `toggleFlashMode()` called
3. If activating:
   - Set `isFlashModeActive = true`
   - Update menu checkmark
   - Call `showFlashBorder()` immediately
   - Call `startFlashTimer()`
4. If deactivating:
   - Set `isFlashModeActive = false`
   - Remove menu checkmark
   - Call `cancelFlashTimer()`

### Border Display Flow

1. `showFlashBorder()` called
2. Order FlashWindow front
3. FlashBorderView starts pulse animation
4. After 5 seconds, animation completes
5. Callback hides FlashWindow
6. Timer continues running (if mode still active)

### Window Layering

All windows use `.screenSaver` level to avoid conflicts:
- OverlayWindow: `.screenSaver`
- FocusWindow: `.statusBar`
- FlashWindow: `.screenSaver` (new)

FlashWindow appears above OverlayWindow due to order, but both ignore mouse events.

## Error Handling

### Timer Edge Cases

- **App quit**: Timer automatically invalidated by system
- **Mode toggled rapidly**: `cancelFlashTimer()` called before creating new timer
- **Timer fires during animation**: No issue, animations queue naturally

### Window Edge Cases

- **No screen available**: Use fallback rect (1920x1080)
- **Multiple screens**: Use main screen only
- **Window creation fails**: Graceful degradation (mode activates but no visual)

### Animation Edge Cases

- **Window hidden mid-animation**: Animation completes in background, no issue
- **Rapid show/hide**: SwiftUI handles state transitions automatically

## Testing Strategy

### Manual Testing

1. **Activation**: Click Flash Mode, verify immediate flash + checkmark
2. **Timer**: Wait 25 minutes, verify automatic flash
3. **Deactivation**: Click Flash Mode again, verify no more flashes
4. **Animation**: Count 10 pulses over ~5 seconds
5. **Coexistence**: Enable Flash Mode + other modes, verify no conflicts
6. **Mouse events**: Verify clicks pass through flash border

### Edge Case Testing

1. Toggle Flash Mode on/off rapidly
2. Quit app while flash is animating
3. Trigger flash while other windows are visible
4. Change focus modes while Flash Mode is active

### Visual Testing

1. Verify border appears on all four edges
2. Verify blue color is visible on various backgrounds
3. Verify inset stroke appearance
4. Verify smooth fade in/out transitions

## Performance Considerations

- Timer runs on main thread (standard for UI timers)
- Animation uses SwiftUI's built-in engine (GPU-accelerated)
- Window remains in memory but hidden (minimal overhead)
- No polling or continuous updates when not animating

## Future Enhancements

Potential future additions (not in current scope):
- Configurable timer interval
- Configurable border color
- Configurable pulse count/duration
- Configurable border width
- Persistent mode state across app launches
