# Implementation Plan

- [x] 1. Set up focus shape system and square focus mode

  - Create FocusShape protocol and FocusMode enum for different focus window shapes
  - Implement SquareShape class that creates 30% width × 50% height square following mouse cursor
  - Add focus mode selection to menu bar with persistence using UserDefaults
  - Update OverlayContentView to use new focus shape system instead of hardcoded rectangle
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ] 2. Implement notes footer with smart positioning and mouse tracking control

  - Create NotesManager class for handling notes persistence, visibility state, and position calculation
  - Implement smart footer positioning logic that places footer 60px below focus area when in top half of screen, or 60px + footer height above focus area when in bottom half
  - Add mouse tracking disable/enable functionality that locks focus area position when notes are active
  - Implement NotesFooterView with grey background, white text, 60% screen width, and 3-line height with scrolling
  - Add Cmd+\ keyboard shortcut handling to toggle notes footer with position calculation and mouse tracking control
  - Integrate UserDefaults for notes content persistence between app sessions
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11_

- [ ] 3. Create AI clarification system foundation

  - Create clarification-prompt.md template file with editable OpenAI prompt including {{SELECTED_TEXT}} placeholder
  - Implement OpenAIService class with GPT-4o integration and proper error handling for API key, network, and rate limit errors
  - Create ClarificationFooterView with loading states, error messages, and subtle dismiss button
  - Add prompt template loading system that reads from clarification-prompt.md file
  - _Requirements: 3.3, 3.4, 3.5, 3.8, 3.9, 3.10_

- [ ] 4. Implement context menu integration

  - Create ContextMenuManager class to register "Clarify with Pace" as macOS system service
  - Add text selection detection and context menu option that is greyed out when no text is selected
  - Integrate context menu with OpenAI service to send selected text and display response in clarification footer
  - Ensure context menu only works when Pace overlay is active and in overlay mode only
  - _Requirements: 3.1, 3.2, 3.11_

- [ ] 5. Create footer stacking system with smart positioning

  - Implement FooterStackView that uses calculated position from NotesManager instead of fixed bottom positioning
  - Position clarification footer above notes footer when both are visible using smart positioning logic
  - Add proper spacing (8pt between footers) and center alignment at calculated position
  - Ensure both footers can be visible simultaneously without overlap and respect mouse tracking lock state
  - Update overlay window to integrate footer stack at dynamically calculated position
  - _Requirements: 3.6, 4.2, 4.3_

- [ ] 6. Integration and final polish
  - Update menu system to include new focus mode options while preserving existing functionality
  - Ensure all keyboard shortcuts work correctly without conflicts with existing app features
  - Verify notes and clarification features work only in overlay mode, not in focus message mode
  - Add proper error handling and user feedback for all new features
  - Test multi-monitor support and performance with new components
  - _Requirements: 4.1, 4.4, 4.5_
