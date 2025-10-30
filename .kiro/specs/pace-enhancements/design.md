# Design Document

## Overview

This design document outlines the architecture and implementation approach for enhancing the Pace macOS reading focus tool with three major features: square focus window mode, persistent notes functionality, and AI-powered text clarification. The design maintains the existing overlay-based architecture while adding new UI components, keyboard shortcuts, context menu integration, and external API connectivity.

## Architecture

### High-Level Architecture

The enhanced Pace app will maintain its current SwiftUI + AppKit hybrid architecture with the following additions:

```
PaceApp (SwiftUI App)
├── AppDelegate (NSApplicationDelegate)
│   ├── OverlayWindow (NSWindow)
│   │   └── OverlayContentView (SwiftUI)
│   │       ├── FocusAreaView (New - handles different focus shapes)
│   │       ├── NotesFooterView (New - toggleable notes)
│   │       └── ClarificationFooterView (New - AI responses)
│   ├── FocusWindow (existing)
│   ├── NotesManager (New - persistence)
│   ├── OpenAIService (New - API integration)
│   └── ContextMenuManager (New - system integration)
```

### Key Architectural Decisions

1. **Focus Shape Abstraction**: Create a protocol-based system for different focus shapes (horizontal band, square) to allow easy extension
2. **Footer Component Stack**: Implement a vertical stack system for multiple footer components that can appear/disappear independently
3. **Persistent Storage**: Use UserDefaults for notes content and focus mode preferences for simplicity
4. **Context Menu Integration**: Leverage NSServicesMenu for system-wide text selection integration
5. **Async API Handling**: Use Swift's async/await pattern for OpenAI API calls with proper error handling

## Components and Interfaces

### 1. Focus Shape System

```swift
protocol FocusShape {
    func createMask(in rect: CGRect, at position: CGPoint) -> Path
    var displayName: String { get }
}

enum FocusMode: String, CaseIterable {
    case horizontalBand = "horizontal"
    case smallWindow = "small"
    case bigWindow = "big" 
    case square = "square"
}
```

**Implementation Details:**
- `HorizontalBandShape`: Current implementation
- `SquareShape`: New 30% width × 50% height square following mouse
- `WindowShape`: Existing small/big window implementations
- Focus shapes will be selectable via menu and persist user preference

### 2. Footer Component System

```swift
struct FooterStackView: View {
    @ObservedObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack(spacing: 8) {
            if appDelegate.showClarificationFooter {
                ClarificationFooterView(appDelegate: appDelegate)
            }
            if appDelegate.showNotesFooter {
                NotesFooterView(appDelegate: appDelegate)
            }
        }
        .position(appDelegate.footerPosition)
    }
}
```

**Smart Footer Positioning:**
- Position calculated dynamically based on current focus area location
- When focus area is in top half: footers appear 60px below focus area
- When focus area is in bottom half: footers appear 60px + footer height above focus area
- Both footers centered horizontally at calculated position
- Clarification footer stacks above notes footer when both visible
- 8pt spacing between footers
- Position updates only when notes footer is toggled, not during mouse movement

### 3. Notes Management

```swift
class NotesManager: ObservableObject {
    @Published var notesContent: String = ""
    @Published var isNotesVisible: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let notesKey = "PaceNotesContent"
    
    func loadNotes()
    func saveNotes()
    func toggleNotesVisibility(currentFocusPosition: CGPoint, screenBounds: CGRect) -> CGPoint
    func calculateFooterPosition(focusPosition: CGPoint, screenBounds: CGRect) -> CGPoint
}
```

**Storage Strategy:**
- Use UserDefaults for immediate persistence
- Auto-save on text changes with 0.5 second debounce
- Load notes content on app launch

**Smart Positioning Strategy:**
- Calculate footer position based on current focus area location when toggled
- Disable mouse tracking for focus area when notes are visible
- Re-enable mouse tracking when notes are dismissed
- Return calculated position for footer placement

### 4. OpenAI Integration

```swift
class OpenAIService: ObservableObject {
    private let apiKey: String = "YOUR_API_KEY_HERE" // Placeholder
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func clarifyText(_ text: String) async -> Result<String, OpenAIError>
}

enum OpenAIError: Error {
    case apiKeyError
    case networkError
    case rateLimitError
    case generalError(String)
}
```

**API Integration Details:**
- Use GPT-4o model for best performance
- Read prompt template from `clarification-prompt.md` file in app bundle
- Implement exponential backoff for rate limiting
- 30-second timeout for requests

**Prompt Template System:**
- Create `clarification-prompt.md` file containing the system prompt for OpenAI
- Load prompt content at app startup and cache in memory
- Allow runtime reloading of prompt file for easy editing during development
- Template will include placeholder for selected text: `{{SELECTED_TEXT}}`
- Example prompt structure: "Please provide a clear, concise explanation of the following text: {{SELECTED_TEXT}}"

### 5. Context Menu Integration

```swift
class ContextMenuManager: NSObject {
    weak var appDelegate: AppDelegate?
    
    func setupServicesMenu()
    func handleClarifyText(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>)
}
```

**System Integration:**
- Register as macOS service for text selection
- Only active when Pace overlay is visible
- Graceful handling when no text selected

## Data Models

### 1. Focus Configuration

```swift
struct FocusConfiguration {
    var mode: FocusMode
    var bandHeight: CGFloat // For existing modes
    var squareSize: CGSize // For square mode
    
    static var current: FocusConfiguration {
        get { /* Load from UserDefaults */ }
        set { /* Save to UserDefaults */ }
    }
}
```

### 2. Footer State

```swift
struct FooterState {
    var notesVisible: Bool = false
    var notesContent: String = ""
    var clarificationVisible: Bool = false
    var clarificationContent: String = ""
    var clarificationLoading: Bool = false
    var clarificationError: String? = nil
    var footerPosition: CGPoint = .zero
    var mouseTrackingEnabled: Bool = true
}
```

## Error Handling

### OpenAI API Errors
- **API Key Error**: Display "API key error" in clarification footer
- **Network/Timeout**: Display "Error, try later" in clarification footer  
- **Rate Limiting**: Implement exponential backoff, show loading state
- **Invalid Response**: Log error, show generic error message

### Keyboard Shortcut Conflicts
- Check for existing Cmd+\ usage in system
- Provide alternative shortcut if conflict detected
- Allow user to customize shortcut in future versions

### Context Menu Registration
- Graceful fallback if services registration fails
- Log warnings for debugging
- Continue app functionality without context menu if needed

## Testing Strategy

### Unit Tests
- Focus shape calculations and positioning
- Notes persistence and loading
- OpenAI service response parsing
- Error handling for various failure scenarios

### Integration Tests  
- Keyboard shortcut handling across different focus modes
- Footer stacking and positioning with different combinations
- Context menu integration with text selection
- API integration with mock responses

### Manual Testing
- Multi-monitor support for focus shapes and footers
- Performance with large notes content
- Context menu behavior across different applications
- Accessibility compliance for new UI components

## Mouse Tracking Integration

### Smart Focus Area Behavior

The enhanced notes system introduces intelligent mouse tracking control to improve the note-taking experience:

**Tracking States:**
- **Active Tracking**: Focus area follows mouse cursor in real-time (default behavior)
- **Locked Position**: Focus area remains stationary at current position (when notes active)

**State Transitions:**
1. **Notes Activation (Cmd+\)**: 
   - Capture current mouse/focus position
   - Calculate optimal footer position based on focus location
   - Disable mouse tracking for focus area
   - Display footer at calculated position
   
2. **Notes Deactivation (Cmd+\ again)**:
   - Hide footer immediately
   - Re-enable mouse tracking for focus area
   - Focus area resumes following mouse cursor

**Position Calculation Logic:**
```swift
func calculateFooterPosition(focusPosition: CGPoint, screenBounds: CGRect) -> CGPoint {
    let footerHeight: CGFloat = 80 // 3 lines + padding
    let offset: CGFloat = 60
    
    if focusPosition.y < screenBounds.height / 2 {
        // Focus in top half - position footer below
        return CGPoint(x: screenBounds.midX, y: focusPosition.y + offset)
    } else {
        // Focus in bottom half - position footer above
        return CGPoint(x: screenBounds.midX, y: focusPosition.y - offset - footerHeight)
    }
}
```

## Implementation Phases

### Phase 1: Focus Shape System
- Implement focus shape protocol and enum
- Create square focus shape implementation
- Add menu options for focus mode selection
- Implement persistence for focus mode preference

### Phase 2: Notes Footer
- Create NotesFooterView with proper styling
- Implement keyboard shortcut handling (Cmd+\)
- Add NotesManager for persistence
- Integrate footer into overlay window

### Phase 3: AI Clarification
- Create `clarification-prompt.md` template file with editable prompt
- Implement OpenAI service with error handling and prompt loading
- Create ClarificationFooterView with dismiss button
- Set up context menu integration
- Add footer stacking system

### Phase 4: Integration & Polish
- Ensure all components work together seamlessly
- Performance optimization for smooth animations
- Comprehensive error handling and user feedback
- Documentation and prompt template creation

## Security Considerations

- Store OpenAI API key securely (placeholder for user implementation)
- Validate and sanitize text sent to OpenAI API
- Implement request size limits to prevent abuse
- Log API usage for monitoring and debugging

## Performance Considerations

- Debounce notes auto-save to prevent excessive disk writes
- Cache OpenAI responses for identical text selections
- Optimize footer rendering to maintain smooth mouse tracking
- Lazy loading of context menu registration