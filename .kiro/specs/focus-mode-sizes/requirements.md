# Requirements Document: Focus Mode Size Enhancement

## Introduction

This enhancement consolidates the focus mode options from 4 separate modes (Small Window, Big Window, Square, Circle) into 3 focus shapes (Rectangle, Square, Circle) with 3 configurable sizes (S, M, L) each, providing a cleaner and more flexible user experience.

## Glossary

- **Focus Mode**: The shape of the reading focus area (Rectangle, Square, or Circle)
- **Focus Size**: The size multiplier for the focus area (S, M, or L)
- **Rectangle Mode**: Horizontal bar focus that spans the full screen width
- **Square Mode**: Rectangular focus area that follows the mouse cursor
- **Circle Mode**: Circular focus area that follows the mouse cursor (aka "James Bond")
- **Size Multiplier**: The scaling factor applied to base dimensions (1.0x, 1.5x, 2.25x)

## Requirements

### Requirement 1: Consolidated Focus Modes

**User Story:** As a user, I want to choose from 3 distinct focus shapes instead of 4 overlapping options, so that the menu is cleaner and more intuitive

#### Acceptance Criteria

1. WHEN the user opens the tray menu, THE Pace Application SHALL display 3 focus mode options: Rectangle, Square, and Circle
2. WHEN the user selects a focus mode, THE Pace Application SHALL show a checkmark next to the selected mode
3. WHEN the user switches modes, THE Pace Application SHALL update the overlay immediately
4. WHEN the application starts, THE Pace Application SHALL load the previously selected mode from UserDefaults

### Requirement 2: Size Selection

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
5. WHEN calculating Square dimensions, THE Pace Application SHALL multiply base dimensions (30% width × 50% height) by the size multiplier
6. WHEN calculating Circle diameter, THE Pace Application SHALL multiply base diameter (50% screen height) by the size multiplier

### Requirement 4: Legacy Migration

**User Story:** As an existing user, I want my previous focus mode settings to be preserved when I update, so that my experience is not disrupted

#### Acceptance Criteria

1. WHEN the application loads with legacy "small" mode saved, THE Pace Application SHALL convert it to Rectangle + S
2. WHEN the application loads with legacy "big" mode saved, THE Pace Application SHALL convert it to Rectangle + M
3. WHEN the application loads with legacy "square" mode saved, THE Pace Application SHALL convert it to Square + S
4. WHEN the application loads with legacy "circle" mode saved, THE Pace Application SHALL convert it to Circle + S
5. WHEN migration occurs, THE Pace Application SHALL save the new format to UserDefaults

### Requirement 5: Smooth Transitions

**User Story:** As a user, I want smooth animations when changing focus modes or sizes, so that the experience feels polished

#### Acceptance Criteria

1. WHEN the user changes focus mode, THE Pace Application SHALL animate the transition over 0.3 seconds
2. WHEN the user changes focus size, THE Pace Application SHALL animate the transition over 0.3 seconds
3. WHEN animating, THE Pace Application SHALL use an easeOut timing curve
4. WHEN the mouse moves, THE Pace Application SHALL animate the focus area position over 0.15 seconds

