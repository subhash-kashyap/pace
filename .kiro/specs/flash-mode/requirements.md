# Requirements Document

## Introduction

This document specifies the Flash Mode feature for the Pace macOS application. Flash Mode displays a calm, pulsing blue border around the screen every 25 minutes to provide visual break reminders.

## Glossary

- **Flash Mode**: A timer-based mode that displays a pulsing blue border at 25-minute intervals
- **Flash Border**: A blue border rendered along all four screen edges
- **Flash Window**: The overlay window that displays the Flash Border
- **Timer**: A 25-minute countdown that triggers the Flash Border display

## Requirements

### Requirement 1

**User Story:** As a user, I want to toggle Flash Mode from the tray menu, so that I can enable or disable periodic visual reminders

#### Acceptance Criteria

1. WHEN the user clicks the Flash Mode menu item, THE Pace Application SHALL toggle Flash Mode on or off
2. WHEN Flash Mode is toggled on, THE Pace Application SHALL display the Flash Border immediately for 5 seconds
3. WHEN Flash Mode is toggled on, THE Pace Application SHALL start a 25-minute timer
4. WHEN Flash Mode is active, THE Pace Application SHALL display a checkmark next to the Flash Mode menu item
5. WHEN Flash Mode is toggled off, THE Pace Application SHALL cancel the timer and remove the checkmark

### Requirement 2

**User Story:** As a user, I want the border to flash every 25 minutes, so that I receive consistent break reminders

#### Acceptance Criteria

1. WHEN the 25-minute timer completes, THE Pace Application SHALL display the Flash Border for 5 seconds
2. WHEN the Flash Border display completes, THE Pace Application SHALL restart the 25-minute timer
3. WHILE Flash Mode is active, THE Pace Application SHALL repeat this cycle continuously
4. WHEN Flash Mode is toggled off, THE Pace Application SHALL stop the timer immediately

### Requirement 3

**User Story:** As a user, I want the border to pulse calmly, so that the reminder is gentle and not disruptive

#### Acceptance Criteria

1. WHEN the Flash Border displays, THE Flash Window SHALL pulse 10 times over 5 seconds
2. WHEN pulsing, THE Flash Border SHALL fade in and out smoothly
3. WHEN the 5-second duration completes, THE Flash Window SHALL hide completely
4. WHILE the Flash Border is visible, THE Flash Window SHALL ignore all mouse events

### Requirement 4

**User Story:** As a user, I want the border to appear on all screen edges, so that I notice it regardless of where I'm looking

#### Acceptance Criteria

1. WHEN the Flash Border displays, THE Flash Window SHALL render a border on all four screen edges
2. WHEN rendering the border, THE Flash Window SHALL use an inset stroke style
3. WHEN rendering the border, THE Flash Window SHALL use blue color
4. WHEN displaying, THE Flash Window SHALL cover the full screen dimensions
5. WHEN displaying, THE Flash Window SHALL appear above normal windows but allow other Pace windows to remain visible
