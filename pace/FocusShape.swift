import SwiftUI
import Foundation

// MARK: - Focus Shape Protocol
protocol FocusShape {
    func createMask(in rect: CGRect, at position: CGPoint) -> Path
    var displayName: String { get }
}

// MARK: - Focus Mode Enum
enum FocusMode: String, CaseIterable {
    case smallWindow = "small"
    case bigWindow = "big"
    case square = "square"
    case circle = "circle"
    
    var displayName: String {
        switch self {
        case .smallWindow:
            return "Small Window"
        case .bigWindow:
            return "Big Window"
        case .square:
            return "Square Focus"
        case .circle:
            return "James Bond"
        }
    }
}

// MARK: - Focus Configuration
struct FocusConfiguration {
    var mode: FocusMode
    var bandHeight: CGFloat
    var squareSize: CGSize
    
    private static let userDefaults = UserDefaults.standard
    private static let focusModeKey = "PaceFocusMode"
    private static let bandHeightKey = "PaceBandHeight"
    
    static var current: FocusConfiguration {
        get {
            let modeString = userDefaults.string(forKey: focusModeKey) ?? FocusMode.smallWindow.rawValue
            let mode = FocusMode(rawValue: modeString) ?? .smallWindow
            let bandHeight = userDefaults.object(forKey: bandHeightKey) as? CGFloat ?? 200
            
            // Calculate square size as 30% width × 50% height of main screen
            let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
            let squareSize = CGSize(
                width: screenSize.width * 0.3,
                height: screenSize.height * 0.5
            )
            
            return FocusConfiguration(
                mode: mode,
                bandHeight: bandHeight,
                squareSize: squareSize
            )
        }
        set {
            userDefaults.set(newValue.mode.rawValue, forKey: focusModeKey)
            userDefaults.set(newValue.bandHeight, forKey: bandHeightKey)
        }
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
    
    var displayName: String { "Square Focus" }
    
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

// MARK: - Window Shape (for small/big windows)
struct WindowShape: FocusShape {
    let height: CGFloat
    
    var displayName: String { height <= 200 ? "Small Window" : "Big Window" }
    
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

// MARK: - Circle Shape
struct CircleShape: FocusShape {
    let diameter: CGFloat
    
    var displayName: String { "James Bond" }
    
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