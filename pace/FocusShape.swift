import SwiftUI
import Foundation

// MARK: - Focus Shape Protocol
protocol FocusShape {
    func createMask(in rect: CGRect, at position: CGPoint) -> Path
    var displayName: String { get }
}

// MARK: - Focus Size Enum
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

// MARK: - Focus Mode Enum
enum FocusMode: String, CaseIterable {
    case rectangle = "rectangle"
    case centerColumn = "centerColumn"
    case square = "square"
    case circle = "circle"
    
    var displayName: String {
        switch self {
        case .rectangle:
            return "Rectangle"
        case .centerColumn:
            return "Center Column"
        case .square:
            return "Square"
        case .circle:
            return "Circle"
        }
    }
}

// MARK: - Focus Configuration
struct FocusConfiguration {
    var mode: FocusMode
    var size: FocusSize
    
    // New Display Properties
    var opacity: Double
    var blurRadius: Double
    var isDarkMode: Bool
    
    private static let userDefaults = UserDefaults.standard
    private static let focusModeKey = "PaceFocusMode"
    private static let focusSizeKey = "PaceFocusSize"
    
    private static let opacityKey = "PaceFocusOpacity"
    private static let blurRadiusKey = "PaceFocusBlurRadius"
    private static let isDarkModeKey = "PaceFocusIsDarkMode"
    private static let hasMigratedBackgroundStyleKey = "PaceHasMigratedBackgroundStyle"
    private static let backgroundStyleKey = "PaceBackgroundStyle" // For migration reading
    
    // Base dimensions (for small size)
    private static let baseRectangleHeight: CGFloat = 200
    private static let baseSquareWidthRatio: CGFloat = 0.2
    private static let baseSquareHeightRatio: CGFloat = 0.5
    
    static var current: FocusConfiguration {
        get {
            let modeString = userDefaults.string(forKey: focusModeKey) ?? ""
            let sizeString = userDefaults.string(forKey: focusSizeKey) ?? FocusSize.small.rawValue
            
            var mode: FocusMode
            var size: FocusSize = FocusSize(rawValue: sizeString) ?? .small
            
            if let legacyMode = modeString.isEmpty ? nil : FocusMode(rawValue: modeString) {
                mode = legacyMode
            } else {
                switch modeString {
                case "small":
                    mode = .rectangle
                    size = .small
                case "big":
                    mode = .rectangle
                    size = .medium
                default:
                    mode = .circle
                    size = .medium
                }
            }
            
            // Default Values
            var opacity: Double = 0.7
            var blurRadius: Double = 0.0
            var isDarkMode: Bool = true
            
            // Migration from BackgroundStyle
            if !userDefaults.bool(forKey: hasMigratedBackgroundStyleKey) {
                if let bgString = userDefaults.string(forKey: backgroundStyleKey) {
                    switch bgString {
                    case "black":
                        opacity = 1.0; isDarkMode = true
                    case "black70":
                        opacity = 0.7; isDarkMode = true
                    case "white":
                        opacity = 1.0; isDarkMode = false
                    case "white70":
                        opacity = 0.7; isDarkMode = false
                    default: break
                    }
                }
                userDefaults.set(true, forKey: hasMigratedBackgroundStyleKey)
                
                // Save migrated values immediately
                userDefaults.set(opacity, forKey: opacityKey)
                userDefaults.set(blurRadius, forKey: blurRadiusKey)
                userDefaults.set(isDarkMode, forKey: isDarkModeKey)
            } else {
                if userDefaults.object(forKey: opacityKey) != nil {
                    opacity = userDefaults.double(forKey: opacityKey)
                }
                if userDefaults.object(forKey: blurRadiusKey) != nil {
                    blurRadius = userDefaults.double(forKey: blurRadiusKey)
                }
                if userDefaults.object(forKey: isDarkModeKey) != nil {
                    isDarkMode = userDefaults.bool(forKey: isDarkModeKey)
                }
            }
            
            return FocusConfiguration(mode: mode, size: size, opacity: opacity, blurRadius: blurRadius, isDarkMode: isDarkMode)
        }
        set {
            userDefaults.set(newValue.mode.rawValue, forKey: focusModeKey)
            userDefaults.set(newValue.size.rawValue, forKey: focusSizeKey)
            userDefaults.set(newValue.opacity, forKey: opacityKey)
            userDefaults.set(newValue.blurRadius, forKey: blurRadiusKey)
            userDefaults.set(newValue.isDarkMode, forKey: isDarkModeKey)
        }
    }
    
    // Calculated properties based on mode and size
    var rectangleHeight: CGFloat {
        Self.baseRectangleHeight * size.multiplier
    }
    
    var centerColumnSize: CGSize {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        return CGSize(
            width: screenSize.width * 0.7,  // 70% of screen width
            height: Self.baseRectangleHeight * size.multiplier
        )
    }
    
    var squareSize: CGSize {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        return CGSize(
            width: screenSize.width * Self.baseSquareWidthRatio * size.multiplier,
            height: screenSize.height * Self.baseSquareHeightRatio * size.multiplier
        )
    }
    
    var circleDiameter: CGFloat {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        return screenSize.height * Self.baseSquareHeightRatio * size.multiplier
    }
}

// MARK: - Horizontal Band Shape
struct HorizontalBandShape: FocusShape {
    let height: CGFloat
    
    var displayName: String { "Horizontal Band" }
    
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

// MARK: - Square Shape
struct SquareShape: FocusShape {
    let size: CGSize
    
    var displayName: String { "Square" }
    
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

// MARK: - Rectangle Shape (replaces Window/HorizontalBand)
struct RectangleShape: FocusShape {
    let height: CGFloat
    
    var displayName: String { "Rectangle" }
    
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

// MARK: - Center Column Shape
struct CenterColumnShape: FocusShape {
    let size: CGSize
    
    var displayName: String { "Center Column" }
    
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

// MARK: - Circle Shape
struct CircleShape: FocusShape {
    let diameter: CGFloat
    
    var displayName: String { "Circle" }
    
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