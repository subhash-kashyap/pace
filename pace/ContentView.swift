import SwiftUI
import AppKit

struct OverlayContentView: View {
    @StateObject private var mouseTracker = GlobalMouseTracker()
    let bandHeight: CGFloat = 200
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Black overlay with transparent band
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .mask(
                        // Create mask that cuts out the focus band
                        Rectangle()
                            .overlay(
                                Rectangle()
                                    .frame(height: bandHeight)
                                    .position(
                                        x: geo.size.width / 2,
                                        y: mouseTracker.mouseY
                                    )
                                    .blendMode(.destinationOut)
                            )
                    )
                    .animation(.easeOut(duration: 0.15), value: mouseTracker.mouseY)
                
                // Optional: Subtle grid overlay
                GridOverlay()
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false) // Ensures click-through for the entire SwiftUI view
    }
}

struct GridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 50
        
        // Vertical lines
        for x in stride(from: 0, through: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // Horizontal lines
        for y in stride(from: 0, through: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

// Global mouse tracking that works across the entire screen
class GlobalMouseTracker: ObservableObject {
    @Published var mouseY: CGFloat = 400
    private var globalMonitor: Any?
    
    init() {
        startTracking()
    }
    
    func startTracking() {
        // Monitor mouse movements globally (even when app isn't focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            let screenHeight = NSScreen.main?.frame.height ?? 1080
            let mouseLocation = NSEvent.mouseLocation
            
            // Convert to SwiftUI coordinates (flip Y axis)
            let flippedY = screenHeight - mouseLocation.y
            
            DispatchQueue.main.async {
                self?.mouseY = flippedY
            }
        }
        
        // Also monitor when the app is focused
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            let screenHeight = NSScreen.main?.frame.height ?? 1080
            let mouseLocation = NSEvent.mouseLocation
            let flippedY = screenHeight - mouseLocation.y
            
            DispatchQueue.main.async {
                self?.mouseY = flippedY
            }
            return event
        }
    }
    
    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

