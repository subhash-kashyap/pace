# Pace Application - Requirements Document v1.0

## Introduction

This document specifies all requirements for the Pace macOS application, a reading focus tool that helps users concentrate by dimming non-essential screen areas. The application includes focus modes with customizable sizes and a Flash Mode for periodic break reminders.

## Glossary

### Core Concepts
- **Pace Application**: A macOS menu bar application that provides reading focus overlays
- **Overlay Window**: A transparent window that dims the screen except for the focus area
- **Focus Area**: The clear, undimmed region where the user can read
- **Focus Mode**: The shape of the reading focus area (Rectangle, Center Column, Square, or Circle)
- **Focus Size**: The size multiplier for the focus area (S, M, or L)
- **Size Multiplier**: The scaling factor applied to base dimensions (1.0x, 1.5x, 2.25x)

### Focus Modes
- **Rectangle Mode**: Horizontal bar focus that spans the full screen width
- **Center Column Mode**: Horizontal bar focus at 70% screen width, centered horizontally (ideal for blog/article reading)
- **Square Mode**: Rectangular focus area that follows the mouse cursor in both directions
- **Circle Mode**: Circular focus area that follows the mouse cursor (aka "Circle")

### Flash Mode
- **Flash Mode**: A timer-based mode that displays a pulsing border at 25-minute intervals
- **Flash Border**: A gradient border (white to red) rendered along all four screen edges
- **Flash Window**: The overlay window that displays the Flash Border
- **Timer**: A 25-minute countdown that triggers the Flash Border display

## Requirements

## Focus Mode Requirements

### Requirement 1: Focus Mode Selection

**User Story:** As a user, I want to choose from 4 distinct focus shapes, so that I can select the best reading experience for my content

#### Acceptance Criteria

1. WHEN the user opens the tray menu, THE Pace Application SHALL display 4 focus mode options: Rectangle, Center Column, Square, and Circle
2. WHEN the user selects a focus mode, THE Pace Application SHALL show a checkmark next to the selected mode
3. WHEN the user switches modes, THE Pace Application SHALL update the overlay immediately
4. WHEN the application starts, THE Pace Application SHALL load the previously selected mode from UserDefaults
5. WHEN Rectangle or Center Column mode is active, THE focus area SHALL follow the mouse vertically only
6. WHEN Square or Circle mode is active, THE focus area SHALL follow the mouse in both directions

### Requirement 2: Focus Size Selection

**User Story:** As a user, I want to adjust the size of my focus area independently from the shape, so that I can customize my reading experience

#### Acceptance Criteria

1. WHEN the user opens the tray menu, THE Pace Application SHALL display a "Size" submenu with options S, M, and L
2. WHEN the user selects a size, THE Pace Application SHALL show a checkmark next to the selected size
3. WHEN the user changes size, THE Pace Application SHALL update the overlay dimensions immediately
4. WHEN the application starts, THE Pace Application SHALL load the previously selected size from UserDefaults
5. WHEN the user changes size, THE Pace Application SHALL apply the size to the currently selected focus mode

### Requirement 3: Size Multipliers

**User Story:** As a user, I want consistent size scaling across all focus modes, so that S/M/L feel predictable

#### Acceptance Criteria

1. WHEN size is set to S, THE Pace Application SHALL use a 1.0x multiplier (base size)
2. WHEN size is set to M, THE Pace Application SHALL use a 1.5x multiplier
3. WHEN size is set to L, THE Pace Application SHALL use a 2.25x multiplier (1.5 × 1.5)
4. WHEN calculating Rectangle height, THE Pace Application SHALL multiply base height (200pt) by the size multiplier
5. WHEN calculating Center Column dimensions, THE Pace Application SHALL use 70% screen width and multiply base height (200pt) by the size multiplier
6. WHEN calculating Square dimensions, THE Pace Application SHALL multiply base dimensions (30% width × 50% height) by the size multiplier
7. WHEN calculating Circle diameter, THE Pace Application SHALL multiply base diameter (50% screen height) by the size multiplier

### Requirement 4: Overlay Visibility Control

**User Story:** As a user, I want to show or hide the overlay, so that I can toggle the reading focus on and off

#### Acceptance Criteria

1. WHEN the user clicks "Hide Pace View" in the tray menu, THE Pace Application SHALL hide the overlay window
2. WHEN the user clicks "Show Pace View" in the tray menu, THE Pace Application SHALL show the overlay window
3. WHEN the overlay is hidden, THE menu item SHALL display "Show Pace View"
4. WHEN the overlay is visible, THE menu item SHALL display "Hide Pace View"
5. WHEN the overlay visibility changes, THE tray icon SHALL update to reflect the state

### Requirement 5: Legacy Migration

**User Story:** As an existing user, I want my previous focus mode settings to be preserved when I update, so that my experience is not disrupted

#### Acceptance Criteria

1. WHEN the application loads with legacy "small" mode saved, THE Pace Application SHALL convert it to Rectangle + S
2. WHEN the application loads with legacy "big" mode saved, THE Pace Application SHALL convert it to Rectangle + M
3. WHEN the application loads with legacy "square" mode saved, THE Pace Application SHALL convert it to Square + S
4. WHEN the application loads with legacy "circle" mode saved, THE Pace Application SHALL convert it to Circle + S
5. WHEN migration occurs, THE Pace Application SHALL save the new format to UserDefaults

### Requirement 6: Smooth Transitions

**User Story:** As a user, I want smooth animations when changing focus modes or sizes, so that the experience feels polished

#### Acceptance Criteria

1. WHEN the user changes focus mode, THE Pace Application SHALL animate the transition over 0.3 seconds
2. WHEN the user changes focus size, THE Pace Application SHALL animate the transition over 0.3 seconds
3. WHEN animating, THE Pace Application SHALL use an easeOut timing curve
4. WHEN the mouse moves, THE Pace Application SHALL animate the focus area position over 0.15 seconds

## Focus Message Requirements

### Requirement 7: Focus Message Mode

**User Story:** As a user, I want to display a full-screen focus message with a text editor, so that I can write without distractions

#### Acceptance Criteria

1. WHEN the user clicks "Show Focus Message" in the tray menu, THE Pace Application SHALL display a full-screen black window with a text editor
2. WHEN Focus Message mode is active, THE menu item SHALL display "Hide Focus Message"
3. WHEN Focus Message mode is active, THE overlay window SHALL be hidden
4. WHEN the user clicks the close button or presses ESC, THE Pace Application SHALL hide the Focus Message window
5. WHEN Focus Message mode closes, THE Pace Application SHALL restore the overlay window if it was previously visible
6. WHEN Focus Message mode is active, THE text editor SHALL have focus and accept keyboard input immediately

## Flash Mode Requirements

### Requirement 8: Flash Mode Toggle

**User Story:** As a user, I want to toggle Flash Mode from the tray menu, so that I can enable or disable periodic visual reminders

#### Acceptance Criteria

1. WHEN the user clicks the Flash Mode menu item, THE Pace Application SHALL toggle Flash Mode on or off
2. WHEN Flash Mode is toggled on, THE Pace Application SHALL display the Flash Border immediately for 3 seconds
3. WHEN Flash Mode is toggled on, THE Pace Application SHALL start a 25-minute timer
4. WHEN Flash Mode is active, THE Pace Application SHALL display a checkmark next to the Flash Mode menu item
5. WHEN Flash Mode is toggled off, THE Pace Application SHALL cancel the timer and remove the checkmark

### Requirement 9: Periodic Flash Display

**User Story:** As a user, I want the border to flash every 25 minutes, so that I receive consistent break reminders

#### Acceptance Criteria

1. WHEN the 25-minute timer completes, THE Pace Application SHALL display the Flash Border for 3 seconds
2. WHEN the Flash Border display completes, THE Pace Application SHALL restart the 25-minute timer
3. WHILE Flash Mode is active, THE Pace Application SHALL repeat this cycle continuously
4. WHEN Flash Mode is toggled off, THE Pace Application SHALL stop the timer immediately
5. WHEN a flash occurs, THE menu item SHALL update to show "Flashed at [time]"

### Requirement 10: Flash Border Animation

**User Story:** As a user, I want the border to pulse calmly, so that the reminder is gentle and not disruptive

#### Acceptance Criteria

1. WHEN the Flash Border displays, THE Flash Window SHALL pulse 6 times over 3 seconds
2. WHEN pulsing, THE Flash Border SHALL fade in and out smoothly with easeInOut timing
3. WHEN the 3-second duration completes, THE Flash Window SHALL hide completely
4. WHILE the Flash Border is visible, THE Flash Window SHALL ignore all mouse events
5. WHEN pulsing, THE Flash Border SHALL reach a maximum opacity of 0.7

### Requirement 11: Flash Border Appearance

**User Story:** As a user, I want the border to appear on all screen edges with a distinctive appearance, so that I notice it regardless of where I'm looking

#### Acceptance Criteria

1. WHEN the Flash Border displays, THE Flash Window SHALL render a border on all four screen edges
2. WHEN rendering the border, THE Flash Window SHALL use an inset stroke style with 8pt width
3. WHEN rendering the border, THE Flash Window SHALL use a linear gradient from white (top-left) to red (bottom-right)
4. WHEN displaying, THE Flash Window SHALL cover the full screen dimensions
5. WHEN displaying, THE Flash Window SHALL appear at screen saver level but allow mouse events to pass through

## Application Lifecycle Requirements

### Requirement 12: Application Startup

**User Story:** As a user, I want the application to start cleanly and restore my previous settings

#### Acceptance Criteria

1. WHEN the application launches, THE Pace Application SHALL run as an accessory app (no dock icon)
2. WHEN the application launches, THE Pace Application SHALL create a menu bar icon
3. WHEN the application launches, THE Pace Application SHALL load saved focus mode and size from UserDefaults
4. WHEN the application launches, THE Pace Application SHALL display the overlay window
5. WHEN the application launches, THE Pace Application SHALL initialize all windows (overlay, focus, flash)

### Requirement 13: Application Termination

**User Story:** As a user, I want to quit the application cleanly from the menu

#### Acceptance Criteria

1. WHEN the user clicks "Quit Pace" in the tray menu, THE Pace Application SHALL terminate
2. WHEN the application quits, THE Pace Application SHALL save current settings to UserDefaults
3. WHEN the application quits, THE Pace Application SHALL clean up all timers and windows
