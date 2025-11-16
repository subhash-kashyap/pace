# Design Document: Focus Mode Size Enhancement

## Overview

This enhancement refactors the focus mode system from 4 discrete modes (Small Window, Big Window, Square, Circle) into a more flexible 3-mode × 3-size matrix. Users select a focus shape (Rectangle, Square, Circle) and independently adjust its size (S, M, L), providing 9 total combinations while simplifying the menu structure.

## Architecture

### Component Structure

```
FocusConfiguration
├── mode: FocusMode (rectangle, square, circle)
├── size: FocusSize (small, medium, large)
├── rectangleHeight: CGFloat (calculated)
├── squareSize: CGSize (calculated)
└── circleDiameter: CGFloat (calculated)

FocusMode enum
├── rectangle
├── square
└── circle

FocusSize enum
├── small (1.0x multiplier)
├── medium (1.5x multiplier)
└── large (2.25x multiplier)

FocusShape protocol implementations
├── RectangleShape (replaces WindowShape + HorizontalBandShape)
├── SquareShape (updated to use calculated size)
└── CircleShape (updated to use calculated diameter)
```

### Integration Points

- **Menu Bar**: Refactored to show 3 mode items + 1 size submenu
- **UserDefaults**: Two keys: `PaceFocusMode` and `PaceFocusSize`
- **Legacy Migration**: Converts old mode strings to new mode+size combinations
- **View Layer**: `OverlayContentView` uses calculated dimensions from configuration

## Data Models

### FocusSize Enum

```swift
enum FocusSize: String, CaseIterable {
    case small = "S"
    case medium = "M"
    case large = "L"
    
    var displayName: String { rawValue }
    
    var multiplier: CGFloat {
        switch self {
        case .small: return 1.0
        case .medium: return 1.5
        case .large: return 2.25  // 1.5 * 1.5
        }
    }
}
```

**Rationale for 2.25x:**
- Provides noticeable difference between sizes
- Maintains consistent 1.5x ratio between adjacent sizes
- Results in L being 2.25x larger than S (1.5 × 1.5)

### FocusMode Enum (Refactored)

```swift
enum FocusMode: String, CaseIterable {
    case rectangle = "rectangle"
    case square = "square"
    case circle = "circle"
    
    var displayName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .square: return "Square Focus"
        case .circle: return "James Bond"
        }
    }
}
```

**Changes:**
- Removed: `smallWindow`, `bigWindow`
- Added: `rectangle` (consolidates both window modes)
- Kept: `square`, `circle` (renamed from legacy values)

### FocusConfiguration (Refactored)

```swift
struct FocusConfiguration {
    var mode: FocusMode
    var size: FocusSize
    
    // Calculated properties
    var rectangleHeight: CGFloat {
        baseRectangleHeight * size.multiplier
    }
    
    var squareSize: CGSize {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        return CGSize(
            width: screenSize.width * baseSquareWidthRatio * size.multiplier,
            height: screenSize.height * baseSquareHeightRatio * size.multiplier
        )
    }
    
    var circleDiameter: CGFloat {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        return screenSize.height * baseSquareHeightRatio * size.multiplier
    }
}
```

**Base Dimensions:**
- Rectangle: 200pt height
- Square: 30% screen width × 50% screen height
- Circle: 50% screen height diameter

**Removed Properties:**
- `bandHeight: CGFloat` (now calculated as `rectangleHeight`)
- Legacy migration handled in `current` getter

## Implementation Details

### Menu Structure

**Before:**
```
- Small Window ✓
- Big Window
- Square Focus
- James Bond
```

**After:**
```
- Rectangle ✓
- Square Focus
- James Bond
---
- Size ▶
  - S ✓
  - M
  - L
```

### Menu Implementation

```swift
// Mode items
for mode in FocusMode.allCases {
    let modeItem = NSMenuItem(title: mode.displayName, 
                              action: #selector(selectFocusMode(_:)), 
                              keyEquivalent: "")
    modeItem.representedObject = mode
    modeItem.state = (mode == focusConfiguration.mode) ? .on : .off
    focusModeMenuItems[mode] = modeItem
    menu.addItem(modeItem)
}

// Size submenu
let sizeMenu = NSMenu()
for size in FocusSize.allCases {
    let sizeItem = NSMenuItem(title: size.displayName, 
                              action: #selector(selectFocusSize(_:)), 
                              keyEquivalent: "")
    sizeItem.representedObject = size
    sizeItem.state = (size == focusConfiguration.size) ? .on : .off
    focusSizeMenuItems[size] = sizeItem
    sizeMenu.addItem(sizeItem)
}

let sizeMenuItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
sizeMenuItem.submenu = sizeMenu
menu.addItem(sizeMenuItem)
```

### Legacy Migration

```swift
static var current: FocusConfiguration {
    get {
        let modeString = userDefaults.string(forKey: focusModeKey) ?? ""
        let sizeString = userDefaults.string(forKey: focusSizeKey) ?? FocusSize.small.rawValue
        
        var mode: FocusMode
        var size: FocusSize = FocusSize(rawValue: sizeString) ?? .small
        
        if let legacyMode = modeString.isEmpty ? nil : FocusMode(rawValue: modeString) {
            mode = legacyMode
        } else {
            // Handle legacy modes
            switch modeString {
            case "small":
                mode = .rectangle
                size = .small
            case "big":
                mode = .rectangle
                size = .medium
            default:
                mode = .rectangle
                size = .small
            }
        }
        
        return FocusConfiguration(mode: mode, size: size)
    }
}
```

**Migration Map:**
- `"small"` → Rectangle + S
- `"big"` → Rectangle + M
- `"square"` → Square + S (if no size saved)
- `"circle"` → Circle + S (if no size saved)

### Shape Implementations

**RectangleShape (new, replaces WindowShape):**
```swift
struct RectangleShape: FocusShape {
    let height: CGFloat
    
    func createMask(in rect: CGRect, at position: CGPoint) -> Path {
        var path = Path()
        path.addRect(CGRect(
            x: 0,
            y: position.y - height / 2,
            width: rect.width,
            height: height
        ))
        return path
    }
}
```

**SquareShape (updated):**
- Now receives calculated `size` from `focusConfiguration.squareSize`
- No longer calculates dimensions internally

**CircleShape (updated):**
- Now receives calculated `diameter` from `focusConfiguration.circleDiameter`
- No longer uses hardcoded 500pt diameter

### View Layer Updates

```swift
private var currentFocusShape: any FocusShape {
    let config = appDelegate.focusConfiguration
    switch config.mode {
    case .rectangle:
        return RectangleShape(height: config.rectangleHeight)
    case .square:
        return SquareShape(size: config.squareSize)
    case .circle:
        return CircleShape(diameter: config.circleDiameter)
    }
}
```

**Animation Updates:**
```swift
.animation(.easeOut(duration: 0.3), value: appDelegate.focusConfiguration.mode)
.animation(.easeOut(duration: 0.3), value: appDelegate.focusConfiguration.size)
```

Removed: `.animation(.easeOut(duration: 0.3), value: appDelegate.bandHeight)`

## Size Calculation Examples

### Rectangle Mode
- **S:** 200pt × 1.0 = 200pt height
- **M:** 200pt × 1.5 = 300pt height
- **L:** 200pt × 2.25 = 450pt height

### Square Mode (on 1920×1080 screen)
- **S:** 576×540 (30% × 50% of screen)
- **M:** 864×810 (45% × 75% of screen)
- **L:** 1296×1215 (67.5% × 112.5% of screen)*

*Note: L size may exceed screen height for Square/Circle modes on smaller screens

### Circle Mode (on 1920×1080 screen)
- **S:** 540pt diameter
- **M:** 810pt diameter
- **L:** 1215pt diameter

## AppDelegate Changes

**Removed Properties:**
```swift
@Published var bandHeight: CGFloat = 200
@Published var isDoubleHeight: Bool = false
private var focusModeMenuItems: [NSMenuItem] = []
```

**Added Properties:**
```swift
private var focusModeMenuItems: [FocusMode: NSMenuItem] = [:]
private var focusSizeMenuItems: [FocusSize: NSMenuItem] = [:]
```

**Simplified Methods:**
- `selectFocusMode(_:)` - No longer manages bandHeight
- `selectFocusSize(_:)` - New method for size selection
- `updateFocusModeMenu()` - Uses dictionary lookup
- `updateFocusSizeMenu()` - New method for size menu updates

## Testing Strategy

### Manual Testing

1. **Mode Selection:**
   - Select each mode (Rectangle, Square, Circle)
   - Verify checkmark appears on selected mode
   - Verify overlay updates immediately

2. **Size Selection:**
   - Select each size (S, M, L) for each mode
   - Verify checkmark appears on selected size
   - Verify dimensions scale correctly
   - Verify smooth animation transitions

3. **Legacy Migration:**
   - Test with old UserDefaults values
   - Verify correct mode+size combination after migration
   - Verify new values saved to UserDefaults

4. **Persistence:**
   - Change mode and size
   - Quit and restart app
   - Verify settings restored correctly

### Visual Verification

1. **Rectangle Sizes:**
   - S: Narrow horizontal bar
   - M: Medium horizontal bar (1.5× taller)
   - L: Wide horizontal bar (2.25× taller)

2. **Square Sizes:**
   - S: Moderate rectangle following cursor
   - M: Larger rectangle (1.5× dimensions)
   - L: Very large rectangle (2.25× dimensions)

3. **Circle Sizes:**
   - S: Moderate circle following cursor
   - M: Larger circle (1.5× diameter)
   - L: Very large circle (2.25× diameter)

### Edge Cases

1. **Screen Size Variations:**
   - Test on different screen resolutions
   - Verify calculations use actual screen dimensions
   - Verify fallback to 1920×1080 if screen unavailable

2. **Rapid Mode/Size Changes:**
   - Quickly switch between modes
   - Quickly switch between sizes
   - Verify no animation glitches or state inconsistencies

3. **Multiple Screens:**
   - Test with multiple monitors
   - Verify uses main screen for calculations

## Performance Considerations

- Calculations performed on-demand (computed properties)
- No continuous recalculation during mouse movement
- Screen size cached in NSScreen.main
- Animation handled by SwiftUI's optimized engine

## Future Enhancements

Potential additions (not in current scope):
- Custom size slider (requires settings window)
- Per-mode size memory (remember different sizes for each mode)
- Keyboard shortcuts for size adjustment
- Visual size preview in menu
- Additional size options (XS, XL)
