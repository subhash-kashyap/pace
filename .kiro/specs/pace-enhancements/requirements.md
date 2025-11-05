# Requirements Document

## Introduction

Flash Mode provides timed visual break reminders via a pulsing blue border around the screen.

## Glossary

- **Flash Mode**: A mode that displays a blue border every 25 minutes
- **Flash Border**: A blue border on all screen edges
- **Pace Application**: The macOS reading focus application

## Requirements

### Requirement 1

**User Story:** As a user, I want to toggle Flash Mode from the tray menu, so that I can control break reminders

#### Acceptance Criteria

1. WHEN the user clicks Flash Mode in the tray menu, THE Pace Application SHALL toggle Flash Mode on or off
2. WHEN Flash Mode activates, THE Pace Application SHALL show the Flash Border for 5 seconds
3. WHEN Flash Mode activates, THE Pace Application SHALL start a 25-minute timer
4. WHEN Flash Mode is on, THE Pace Application SHALL show a checkmark next to Flash Mode in the menu
5. WHEN Flash Mode deactivates, THE Pace Application SHALL cancel the timer

### Requirement 2

**User Story:** As a user, I want the border to flash every 25 minutes, so that I get regular break reminders

#### Acceptance Criteria

1. WHEN the timer reaches 25 minutes, THE Pace Application SHALL show the Flash Border for 5 seconds
2. WHEN the Flash Border finishes, THE Pace Application SHALL restart the 25-minute timer
3. WHILE Flash Mode is on, THE Pace Application SHALL repeat this cycle
4. WHEN Flash Mode turns off, THE Pace Application SHALL stop the timer

### Requirement 3

**User Story:** As a user, I want the border to pulse gently, so that it doesn't startle me

#### Acceptance Criteria

1. WHEN the Flash Border shows, THE Pace Application SHALL pulse it 10 times over 5 seconds
2. WHEN pulsing, THE Flash Border SHALL fade in and out smoothly
3. WHEN 5 seconds pass, THE Pace Application SHALL hide the Flash Border
4. WHILE the Flash Border is visible, THE Pace Application SHALL let mouse clicks pass through

### Requirement 4

**User Story:** As a user, I want the border on all screen edges, so that I notice it

#### Acceptance Criteria

1. WHEN the Flash Border shows, THE Pace Application SHALL draw it on all four screen edges
2. WHEN drawing the border, THE Pace Application SHALL use an inset stroke style
3. WHEN drawing the border, THE Pace Application SHALL use blue color
4. WHEN showing the border, THE Pace Application SHALL cover the full screen
