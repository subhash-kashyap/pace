import SwiftUI
import AppKit

struct OverlayContentView: View {
    @StateObject private var mouseTracker = GlobalMouseTracker()
    @ObservedObject var appDelegate: AppDelegate
    
    private var currentFocusShape: any FocusShape {
        let config = appDelegate.focusConfiguration
        switch config.mode {
        case .rectangle:
            return RectangleShape(height: config.rectangleHeight)
        case .centerColumn:
            return CenterColumnShape(size: config.centerColumnSize)
        case .square:
            return SquareShape(size: config.squareSize)
        case .circle:
            return CircleShape(diameter: config.circleDiameter)
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                let config = appDelegate.focusConfiguration
                let baseColor = config.isDarkMode ? Color.black : Color.white
                
                Group {
                    if config.blurRadius > 0 {
                        ZStack {
                            VisualEffectView(material: config.isDarkMode ? .hudWindow : .light, blendingMode: .behindWindow)
                            Rectangle().fill(baseColor.opacity(config.opacity))
                        }
                    } else {
                        Rectangle().fill(baseColor.opacity(config.opacity))
                    }
                }
                .mask(
                        Rectangle()
                            .overlay(
                                Path { path in
                                    let mousePosition: CGPoint
                                    if appDelegate.focusConfiguration.mode == .square || appDelegate.focusConfiguration.mode == .circle {
                                        mousePosition = CGPoint(x: mouseTracker.mouseX, y: mouseTracker.mouseY)
                                    } else {
                                        // Rectangle and Center Column follow mouse vertically only
                                        mousePosition = CGPoint(x: geo.size.width / 2, y: mouseTracker.mouseY)
                                    }
                                    
                                    let focusPath = currentFocusShape.createMask(
                                        in: geo.frame(in: .local),
                                        at: mousePosition
                                    )
                                    path.addPath(focusPath)
                                }
                                .blendMode(.destinationOut)
                            )
                    )
                    .animation(.easeOut(duration: 0.15), value: mouseTracker.mouseY)
                    .animation(.easeOut(duration: 0.15), value: mouseTracker.mouseX)
                    .animation(.easeOut(duration: 0.3), value: appDelegate.focusConfiguration.mode)
                    .animation(.easeOut(duration: 0.3), value: appDelegate.focusConfiguration.size)
                    .animation(.easeOut(duration: 0.3), value: appDelegate.focusConfiguration.opacity)
                    .animation(.easeOut(duration: 0.3), value: appDelegate.focusConfiguration.isDarkMode)
                    .animation(.easeOut(duration: 0.3), value: appDelegate.focusConfiguration.blurRadius)
                
                // GridOverlay removed
            }
        }
        .edgesIgnoringSafeArea(.all)
        .allowsHitTesting(false)
        .onAppear {
            mouseTracker.restartTracking()
            NSApp.activate(ignoringOtherApps: true) // ensures global events fire immediately
        }
    }
}

struct GridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 50
        
        for x in stride(from: 0, through: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        for y in stride(from: 0, through: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

// Poll the cursor instead of using a global monitor so we do not require accessibility permissions.
class GlobalMouseTracker: ObservableObject {
    @Published var mouseY: CGFloat = 400
    @Published var mouseX: CGFloat = 960
    private var timer: Timer?
    private let updateInterval: TimeInterval = 1.0 / 60.0

    init() {
        startTracking()
    }

    func startTracking() {
        stopTracking()

        let timer = Timer(timeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let mouseLocation = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            let screenFrame = screen?.frame ?? NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
            let flippedY = screenFrame.maxY - mouseLocation.y
            let adjustedX = mouseLocation.x - screenFrame.minX

            if abs(self.mouseY - flippedY) < 0.5 && abs(self.mouseX - adjustedX) < 0.5 {
                return
            }

            withAnimation(.easeOut(duration: 0.12)) {
                self.mouseY = flippedY
                self.mouseX = adjustedX
            }
        }

        timer.tolerance = updateInterval / 2.0
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        self.timer = timer
    }

    func restartTracking() {
        startTracking()
    }

    deinit {
        stopTracking()
    }

    private func stopTracking() {
        timer?.invalidate()
        timer = nil
    }
}

