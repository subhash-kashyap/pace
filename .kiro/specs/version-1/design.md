# Pace Application - Design Document v1.0

## Overview

Pace is a macOS menu bar application that enhances reading focus by dimming non-essential screen areas. The application provides 4 focus shapes (Rectangle, Center Column, Square, Circle) with 3 size options (S, M, L), plus a Flash Mode for periodic break reminders. The design emphasizes simplicity, smooth animations, and minimal system resource usage.

## Architecture

### High-Level Component Structure

```
PaceApp (SwiftUI App)
└── AppDelegate (NSApplicationDelegate)
    ├── OverlayWindow (reading focus overlay)
    ├── FocusWindow (full-screen focus message editor)
    ├── FlashWindow (periodic flash border)
    ├── StatusItem (menu bar icon and menu)
    └── FocusConfiguration (mode and size settings)
```

### Window Hierarchy

```
Window Levels (bottom to top):
- Normal windows (user applications)
- OverlayWindow (.screenSaver level)
- FlashWindow (.screenSaver level)
- FocusWindow (.statusBar level)
```

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

**Design Rationale:**
- 1.5x progression provides noticeable but not jarring size differences
- 2.25x for large (1.5²) maintains geometric consistency
- Simple S/M/L labels are intuitive and language-agnostic

### FocusMode Enum

```swift
enum FocusMode: String, CaseIterable {
    case rectangle = "rectangle"
    case centerColumn = "centerColumn"
    case square = "square"
    case circle = "circle"
    
    var displayName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .centerColumn: return "Center Column"
        case .square: return "Square"
        case .circle: return "James Bond"
        }
    }
}
```

**Mode Characteristics:**
- **Rectangle**: Full-width horizontal bar, follows mouse vertically
- **Center Column**: 70% width horizontal bar (centered), follows mouse vertically, ideal for blog/article reading
- **Square**: Rectangular area, follows mouse in both directions
- **Circle**: Circular area, follows mouse in both directions

### FocusConfiguration

```swift
struct FocusConfiguration {
    var mode: FocusMode
    var size: FocusSize
    
    private static let baseRectangleHeight: CGFloat = 200
    private static let baseSquareWidthRatio: CGFloat = 0.3
    private static let baseSquareHeightRatio: CGFloat = 0.5
    
    // Calculated properties
    var rectangleHeight: CGFloat {
        baseRectangleHeight * size.multiplier
    }
    
    var centerColumnSize: CGSize {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        return CGSize(
            width: screenSize.width * 0.7,
            height: baseRectangleHeight * size.multiplier
        )
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
- Rectangle: 200pt height, full screen width
- Center Column: 200pt height, 70% screen width (centered)
- Square: 30% screen width × 50% screen height
- Circle: 50% screen height diameter

**Persistence:**
- Stored in UserDefaults with keys: `PaceFocusMode`, `PaceFocusSize`
- Legacy migration converts old "small"/"big" modes to Rectangle + S/M

## Focus Shape Protocol

```swift
protocol FocusShape {
    func createMask(in rect: CGRect, at position: CGPoint) -> Path
    var displayName: String { get }
}
```

### Shape Implementations

**RectangleShape:**
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

**CenterColumnShape:**
```swift
struct CenterColumnShape: FocusShape {
    let size: CGSize
    
    func createMask(in rect: CGRect, at position: CGPoint) -> Path {
        var path = Path()
        path.addRect(CGRect(
            x: (rect.width - size.width) / 2,  // Center horizontally
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        ))
        return path
    }
}
```

**SquareShape:**
```swift
struct SquareShape: FocusShape {
    let size: CGSize
    
    func createMask(in rect: CGRect, at position: CGPoint) -> Path {
        var path = Path()
        path.addRect(CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        ))
        return path
    }
}
```

**CircleShape:**
```swift
struct CircleShape: FocusShape {
    let diameter: CGFloat
    
    func createMask(in rect: CGRect, at position: CGPoint) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(
            x: position.x - diameter / 2,
            y: position.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        return path
    }
}
```

## Window Implementations

### OverlayWindow

**Purpose:** Displays the reading focus overlay with dimmed background and clear focus area

**Configuration:**
- Level: `.screenSaver` (above normal windows, below status bar)
- Style: Borderless, full-size content view
- Behavior: Ignores mouse events, transparent background
- Collection behavior: Can join all spaces, full-screen auxiliary

**Content:** `OverlayContentView` (SwiftUI view)

**Key Features:**
- 0.99 opacity black background with focus area cut out using `.blendMode(.destinationOut)`
- Smooth animations (0.15s for mouse movement, 0.3s for mode/size changes)
- Uses `GlobalMouseTracker` to poll cursor position at 60fps

### FocusWindow

**Purpose:** Full-screen focus message mode with text editor

**Configuration:**
- Level: `.statusBar` (above overlay)
- Style: Borderless, full-size content view
- Behavior: Can become key window (receives keyboard input)
- Collection behavior: Can join all spaces, full-screen auxiliary

**Content:** `FocusModeView` (SwiftUI view with text editor)

**Key Features:**
- Black background with white text editor
- Close button in top-right corner
- ESC key closes window
- Remembers and restores overlay visibility state

### FlashWindow

**Purpose:** Displays periodic flash border for break reminders

**Configuration:**
- Level: `.screenSaver` (same as overlay)
- Style: Borderless, full-size content view
- Behavior: Ignores mouse events, transparent background
- Collection behavior: Can join all spaces, full-screen auxiliary

**Content:** `FlashBorderView` (SwiftUI view)

**Key Features:**
- 8pt inset stroke border with white-to-red gradient
- Pulses 6 times over 3 seconds (0.5s per pulse)
- Max opacity 0.7, easeInOut animation
- Auto-hides after animation completes

## Menu Bar Interface

### Menu Structure

```
[Pace Icon]
├── Hide Pace View / Show Pace View
├── ─────────────────
├── Rectangle [✓]
├── Center Column
├── Square
├── James Bond
├── ─────────────────
├── Size ▶
│   ├── S [✓]
│   ├── M
│   └── L
├── ─────────────────
├── Show Focus Message / Hide Focus Message
├── ─────────────────
├── Flash [✓] / Flashed at [time]
├── ─────────────────
├── Breathe in - Breathe out, repeat (disabled)
├── ─────────────────
└── Quit Pace
```

### Menu Item Behaviors

**Focus Mode Items:**
- Checkmark indicates active mode
- Clicking switches mode immediately
- Updates overlay in real-time

**Size Submenu:**
- Checkmark indicates active size
- Clicking switches size immediately
- Applies to current focus mode

**Flash Mode:**
- Checkmark when active
- Shows "Flashed at [time]" after each flash
- Toggles 25-minute timer on/off

## Mouse Tracking

### GlobalMouseTracker

**Implementation:**
```swift
class GlobalMouseTracker: ObservableObject {
    @Published var mouseY: CGFloat
    @Published var mouseX: CGFloat
    private var timer: Timer?
    private let updateInterval: TimeInterval = 1.0 / 60.0
}
```

**Design Rationale:**
- Polls cursor position instead of using global event monitor (no accessibility permissions required)
- 60fps update rate provides smooth tracking
- Debouncing: skips updates if movement < 0.5pt
- Animated updates with 0.12s easeOut for smoothness
- Runs on main RunLoop with `.common` and `.eventTracking` modes

## Flash Mode System

### Timer Management

**Implementation:**
```swift
private var flashTimer: Timer?
private var lastFlashTime: Date?

func startFlashTimer() {
    cancelFlashTimer()
    flashTimer = Timer.scheduledTimer(
        withTimeInterval: 25 * 60,
        repeats: true
    ) { [weak self] _ in
        self?.showFlashBorder()
    }
}
```

**Design Rationale:**
- 25-minute interval based on Pomodoro technique
- Repeating timer for continuous operation
- Weak self reference prevents retain cycles
- Timer invalidated on mode toggle or app quit

### Flash Animation

**FlashBorderView:**
```swift
struct FlashBorderView: View {
    @State private var opacity: Double = 0.0
    var onComplete: () -> Void
    
    var body: some View {
        Rectangle()
            .strokeBorder(
                LinearGradient(
                    gradient: Gradient(colors: [Color.white, Color.red]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 8
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.25).repeatCount(12, autoreverses: true)) {
                    opacity = 0.7
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    onComplete()
                }
            }
    }
}
```

**Animation Details:**
- 12 animation cycles (6 complete pulses) over 3 seconds
- 0.25s per half-cycle (fade in or fade out)
- EaseInOut timing for smooth acceleration/deceleration
- Callback hides window after completion

## Size Calculations

### Rectangle Mode
| Size | Height | Width |
|------|--------|-------|
| S | 200pt | Full screen |
| M | 300pt | Full screen |
| L | 450pt | Full screen |

### Center Column Mode (1920×1080 screen)
| Size | Height | Width |
|------|--------|-------|
| S | 200pt | 1344px (70%) |
| M | 300pt | 1344px (70%) |
| L | 450pt | 1344px (70%) |

### Square Mode (1920×1080 screen)
| Size | Dimensions |
|------|------------|
| S | 576×540 (30% × 50%) |
| M | 864×810 (45% × 75%) |
| L | 1296×1215 (67.5% × 112.5%) |

### Circle Mode (1920×1080 screen)
| Size | Diameter |
|------|----------|
| S | 540pt |
| M | 810pt |
| L | 1215pt |

## Animation System

### Animation Timing

**Mouse Movement:**
- Duration: 0.15s
- Curve: easeOut
- Applied to: mouseX, mouseY changes

**Mode/Size Changes:**
- Duration: 0.3s
- Curve: easeOut
- Applied to: focusConfiguration.mode, focusConfiguration.size

**Flash Pulse:**
- Duration: 0.25s per half-cycle
- Curve: easeInOut
- Applied to: opacity changes

### SwiftUI Animation Implementation

```swift
.animation(.easeOut(duration: 0.15), value: mouseTracker.mouseY)
.animation(.easeOut(duration: 0.15), value: mouseTracker.mouseX)
.animation(.easeOut(duration: 0.3), value: appDelegate.focusConfiguration.mode)
.animation(.easeOut(duration: 0.3), value: appDelegate.focusConfiguration.size)
```

## Performance Considerations

### Optimization Strategies

1. **Computed Properties:** Dimensions calculated on-demand, not stored
2. **Mouse Polling:** 60fps with debouncing reduces unnecessary updates
3. **GPU Acceleration:** SwiftUI animations use Core Animation (GPU-accelerated)
4. **Window Reuse:** Windows created once at startup, shown/hidden as needed
5. **Timer Efficiency:** Single timer for Flash Mode, no continuous polling

### Resource Usage

- **Memory:** ~20-30MB (3 windows + SwiftUI views)
- **CPU:** <1% idle, ~2-3% during animations
- **GPU:** Minimal (simple shapes and gradients)

## Error Handling

### Screen Detection

```swift
let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
```

**Fallback:** Uses 1920×1080 if no screen detected

### Timer Management

- Timer invalidated before creating new one (prevents duplicates)
- Weak self references prevent retain cycles
- Timer automatically invalidated on app quit

### Window Lifecycle

- Windows created at startup, never deallocated
- Show/hide instead of create/destroy for performance
- Window level conflicts avoided by using different levels

## Testing Strategy

### Manual Testing Checklist

**Focus Modes:**
- [ ] Rectangle mode displays full-width bar
- [ ] Center Column mode displays 70% width centered bar
- [ ] Square mode follows mouse in both directions
- [ ] Circle mode follows mouse in both directions
- [ ] All modes respond to S/M/L size changes
- [ ] Smooth animations between modes and sizes

**Flash Mode:**
- [ ] Toggle activates/deactivates Flash Mode
- [ ] Immediate flash on activation
- [ ] Flash occurs every 25 minutes
- [ ] Menu shows "Flashed at [time]" after flash
- [ ] 6 pulses over 3 seconds
- [ ] White-to-red gradient visible

**Focus Message:**
- [ ] Opens full-screen black window
- [ ] Text editor receives focus immediately
- [ ] ESC key closes window
- [ ] Close button works
- [ ] Overlay state restored on close

**Persistence:**
- [ ] Settings saved on quit
- [ ] Settings restored on launch
- [ ] Legacy migration works correctly

### Edge Cases

**Multi-Monitor:**
- Uses main screen for calculations
- Overlay appears on all screens (collection behavior)

**Screen Size Variations:**
- Calculations adapt to actual screen dimensions
- Fallback to 1920×1080 if screen unavailable

**Rapid Interactions:**
- Mode/size changes queue properly
- No animation glitches
- No state inconsistencies

## Future Enhancements

### Planned Features (not in v1.0)

1. **Opacity Control:** Adjust overlay darkness (light/medium/dark)
2. **Animation Speed:** Control mouse tracking speed
3. **Focus Border:** Add subtle border around focus area
4. **Invert Mode:** Light overlay with dark focus area
5. **Pause/Freeze:** Lock focus area in place
6. **Keyboard Shortcuts:** Quick mode switching
7. **Auto-hide on Idle:** Hide overlay when mouse inactive
8. **Multi-monitor Control:** Choose which screens show overlay
9. **Reading Guide Line:** Horizontal/vertical line through focus area
10. **Custom Sizes:** User-defined size values

See `future_ideas.md` for detailed descriptions.

## Technical Debt

### Known Limitations

1. **Single Screen Focus:** Calculations use main screen only
2. **No Accessibility Permissions:** Mouse tracking uses polling instead of global events
3. **Fixed Opacity:** Overlay darkness hardcoded to 0.99
4. **No Keyboard Shortcuts:** All interactions via menu only
5. **No Settings Window:** All configuration via menu items

### Refactoring Opportunities

1. **Extract Menu Builder:** Menu setup code could be modularized
2. **Protocol-based Windows:** Common window configuration could use protocol
3. **Centralized Animation:** Animation values could be constants
4. **Configuration Manager:** Separate class for UserDefaults management
