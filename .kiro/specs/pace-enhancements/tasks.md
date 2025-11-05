# Implementation Plan

- [x] 1. Add Flash Mode properties to AppDelegate
  - Add `flashWindow`, `flashMenuItem`, `flashTimer`, and `isFlashModeActive` properties to AppDelegate class
  - Initialize flashWindow in `applicationDidFinishLaunching`
  - _Requirements: 1.1, 1.3_

- [x] 2. Create FlashWindow class
  - [x] 2.1 Implement FlashWindow as NSWindow subclass
    - Configure window with borderless style, full screen dimensions
    - Set window level to `.screenSaver`
    - Configure to ignore mouse events and be transparent
    - Set collection behavior for all spaces
    - _Requirements: 3.4, 4.1, 4.4_
  
  - [x] 2.2 Initialize FlashWindow with FlashBorderView content
    - Create NSHostingView with FlashBorderView
    - Set as window's contentView
    - _Requirements: 4.1_

- [x] 3. Create FlashBorderView SwiftUI component
  - [x] 3.1 Implement FlashBorderView structure
    - Create SwiftUI view with opacity state
    - Add pulseCount state tracker
    - Add onComplete callback parameter
    - _Requirements: 3.1, 3.2_
  
  - [x] 3.2 Implement border rendering
    - Use Rectangle with stroke modifier for all four edges
    - Apply blue color
    - Use inset stroke style with 10pt width
    - Make view fill entire screen with edgesIgnoringSafeArea
    - _Requirements: 4.1, 4.2, 4.3_
  
  - [x] 3.3 Implement pulse animation
    - Create repeating animation that pulses opacity from 0.0 to 0.8 and back
    - Configure to run 10 times over 5 seconds (0.5s per pulse)
    - Use easeInOut timing curve
    - Call onComplete callback after 10 pulses
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 4. Implement Flash Mode menu integration
  - [x] 4.1 Add Flash Mode menu item
    - Add flashMenuItem to setupMenuBar after focus mode separator
    - Set title to "Flash Mode"
    - Connect to toggleFlashMode action
    - _Requirements: 1.1_
  
  - [x] 4.2 Implement toggleFlashMode method
    - Toggle isFlashModeActive boolean
    - Update menu item checkmark state
    - Call showFlashBorder if activating
    - Call startFlashTimer if activating
    - Call cancelFlashTimer if deactivating
    - _Requirements: 1.1, 1.2, 1.3, 1.5_

- [ ] 5. Implement timer management
  - [x] 5.1 Implement startFlashTimer method
    - Cancel any existing timer first
    - Create Timer with 25-minute interval (25 * 60 seconds)
    - Set repeats to true
    - Call showFlashBorder in timer callback
    - _Requirements: 1.3, 2.1, 2.2_
  
  - [x] 5.2 Implement cancelFlashTimer method
    - Invalidate timer if it exists
    - Set flashTimer to nil
    - _Requirements: 1.5, 2.3, 2.4_
  
  - [x] 5.3 Implement showFlashBorder method
    - Order flashWindow to front
    - Trigger FlashBorderView animation
    - Hide window after animation completes via callback
    - _Requirements: 1.2, 2.2, 3.3_

- [x] 6. Wire up animation completion
  - Implement callback in FlashBorderView that hides FlashWindow after animation
  - Ensure window is properly hidden after 5 seconds
  - _Requirements: 3.3_
