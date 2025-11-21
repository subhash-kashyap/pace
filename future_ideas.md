# Future Ideas for Pace

## Invert Mode
Light overlay with dark focus area instead of dark overlay with clear focus. This could be useful for:
- Reading on bright backgrounds
- Reducing eye strain in well-lit environments
- Alternative visual style preference

**Implementation considerations:**
- Toggle between normal and inverted mode
- Adjust opacity levels for light overlay
- Ensure readability in both modes

## Pause/Freeze Focus
Lock the focus area in place temporarily to stop following the mouse. Useful for:
- Reading a specific section without mouse movement interference
- Taking screenshots of focused content
- Presenting or sharing screen with stable focus area

**Implementation considerations:**
- Keyboard shortcut to toggle freeze (e.g., Space bar)
- Visual indicator when frozen
- Remember last position when unfrozen

## Keyboard Shortcuts
Show and configure keyboard shortcuts for quick mode switching and controls:
- Quick switch between Rectangle/Square/Circle modes
- Cycle through sizes (S/M/L)
- Toggle overlay on/off
- Freeze/unfreeze focus
- Toggle Flash Mode

**Implementation considerations:**
- Global hotkeys (work even when app not focused)
- Customizable key bindings
- Shortcuts panel in menu or settings window
- Avoid conflicts with common system shortcuts

## Auto-hide on Idle
Automatically hide overlay when mouse hasn't moved for X seconds:
- Reduces distraction when not actively reading
- Automatically reappears when mouse moves
- Configurable timeout duration

**Implementation considerations:**
- Default timeout: 3-5 seconds
- Smooth fade out/in animations
- Option to disable auto-hide
- Settings for timeout duration

## Multi-monitor Support
Choose which screen(s) to show the overlay on:
- Show on primary monitor only
- Show on all monitors
- Show on specific selected monitor
- Follow mouse across monitors

**Implementation considerations:**
- Detect all connected displays
- Create overlay window per monitor
- Sync focus mode/size across displays
- Handle monitor connect/disconnect events
- Menu option to select monitor behavior

## Reading Guide Line
Add a horizontal or vertical line through the focus area (like a ruler):
- Horizontal line for line-by-line reading
- Vertical line for column reading
- Crosshair mode (both lines)
- Customizable line color and thickness

**Implementation considerations:**
- Toggle guide line on/off
- Choose orientation (horizontal/vertical/both)
- Adjust line opacity and color
- Line follows focus area center
- Option to offset line position within focus area
