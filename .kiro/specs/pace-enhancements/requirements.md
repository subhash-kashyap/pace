# Requirements Document

## Introduction

This document outlines the requirements for enhancing the Pace macOS reading focus tool with three new features: a square focus window option, persistent notes functionality with keyboard shortcuts, and AI-powered text clarification through context menus. These enhancements will improve user productivity by providing additional focus modes, note-taking capabilities, and intelligent text assistance while maintaining the app's core overlay-based focus functionality.

## Glossary

- **Pace_App**: The macOS reading focus application that provides overlay windows to help users focus on content
- **Overlay_Window**: The semi-transparent window that covers the screen with a clear viewing area following the mouse cursor
- **Square_Focus_Mode**: A new focus mode that displays a square-shaped clear viewing area instead of the horizontal band
- **Notes_Footer**: A toggleable textarea component that appears at the bottom center of the overlay window for user notes, with content that persists between sessions
- **Clarification_Footer**: A separate footer component that displays AI-generated explanations of selected text
- **OpenAI_Service**: The external API service used to generate text clarifications using GPT-5-mini model
- **Context_Menu**: The right-click menu that appears when text is selected in other applications

## Requirements

### Requirement 1

**User Story:** As a Pace user, I want a square focus window option so that I can have a different shaped viewing area that better suits certain reading tasks.

#### Acceptance Criteria

1. WHEN the user toggles to square focus mode, THE Pace_App SHALL display a square-shaped clear viewing area that follows the mouse cursor
2. THE Pace_App SHALL size the square viewing area to 30% of screen width and 50% of screen height
3. THE Pace_App SHALL provide a menu option to toggle between horizontal band, small window, big window, and square focus modes
4. THE Pace_App SHALL maintain smooth mouse tracking animation for the square focus area identical to the current horizontal band behavior
5. THE Pace_App SHALL persist the user's focus mode preference between application sessions

### Requirement 2

**User Story:** As a Pace user, I want to take persistent notes while using the overlay mode so that I can capture thoughts and ideas without leaving my focus environment, with intelligent positioning that keeps notes contextually relevant to my reading focus.

#### Acceptance Criteria

1. WHEN the user presses Cmd+\ while in overlay mode, THE Pace_App SHALL toggle the visibility of the Notes_Footer with smart positioning relative to the current focus area
2. WHEN the focus area is in the top half of the screen, THE Pace_App SHALL position the Notes_Footer 60 pixels below the focus area
3. WHEN the focus area is in the bottom half of the screen, THE Pace_App SHALL position the Notes_Footer 60 pixels plus footer height above the focus area
4. WHEN the Notes_Footer becomes visible, THE Pace_App SHALL disable mouse tracking for the focus area to prevent movement during note-taking
5. WHEN the Notes_Footer is hidden, THE Pace_App SHALL re-enable mouse tracking for the focus area immediately
6. WHEN the Notes_Footer is hidden, THE Pace_App SHALL preserve the notes content in memory and on disk
7. THE Pace_App SHALL size the Notes_Footer to 60% of screen width with a fixed height displaying exactly 3 lines of text
8. WHEN the notes content exceeds 3 lines, THE Pace_App SHALL provide vertical scrolling within the Notes_Footer
9. THE Pace_App SHALL style the Notes_Footer with grey background and white text
10. THE Pace_App SHALL persist notes content to disk and restore it when the application restarts
11. THE Pace_App SHALL make the Notes_Footer available only in overlay mode, not in focus message mode

### Requirement 3

**User Story:** As a Pace user, I want to get AI-powered clarifications of selected text so that I can better understand complex content without breaking my focus.

#### Acceptance Criteria

1. WHEN the user selects text in any application while Pace_App overlay is active, THE Pace_App SHALL enable the "Clarify with Pace" option in the system context menu
2. WHEN no text is selected, THE Pace_App SHALL grey out the "Clarify with Pace" context menu option
3. WHEN the user clicks "Clarify with Pace", THE Pace_App SHALL send the selected text to OpenAI_Service using GPT-3.5-mini model
4. WHILE waiting for OpenAI_Service response, THE Pace_App SHALL display "Loading..." message in the Clarification_Footer
5. WHEN OpenAI_Service returns a response, THE Pace_App SHALL display the clarification text in the Clarification_Footer
6. THE Pace_App SHALL position the Clarification_Footer above the Notes_Footer when both are visible
7. THE Pace_App SHALL provide a subtle close button on the Clarification_Footer to dismiss the explanation
8. WHEN OpenAI_Service returns an error, THE Pace_App SHALL display "Error, try later" message in the Clarification_Footer
9. WHEN OpenAI_Service returns an API key error, THE Pace_App SHALL display "API key error" message in the Clarification_Footer
10. THE Pace_App SHALL read the OpenAI prompt template from a separate markdown file for easy editing
11. THE Pace_App SHALL make the clarification feature available only in overlay mode, not in focus message mode

### Requirement 4

**User Story:** As a Pace user, I want the new features to integrate seamlessly with the existing app functionality so that my current workflow is not disrupted.

#### Acceptance Criteria

1. THE Pace_App SHALL maintain all existing overlay window behaviors when new features are active
2. THE Pace_App SHALL ensure Notes_Footer and Clarification_Footer do not interfere with mouse cursor tracking
3. THE Pace_App SHALL allow both Notes_Footer and Clarification_Footer to be visible simultaneously without overlap
4. THE Pace_App SHALL maintain keyboard shortcut functionality for existing features when new shortcuts are added
5. THE Pace_App SHALL preserve existing menu structure while adding new focus mode options