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
                // Use the selected background style
                Rectangle()
                    .fill(appDelegate.focusConfiguration.backgroundStyle.color)
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
                    .animation(.easeOut(duration: 0.3), value: appDelegate.focusConfiguration.backgroundStyle)
                
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

struct FocusModeView: View {
    @ObservedObject var appDelegate: AppDelegate
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        print("❌ Close button clicked")
                        appDelegate.toggleFocusMode()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                }
                
                Spacer()
                
                VStack(spacing: 20) {
                    Text("Write a focused message")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    
                    SimpleTextView(text: $appDelegate.focusText)
                        .frame(width: 700, height: 450)
                }
                
                Spacer()
            }
        }
        .onAppear {
            print("🟢 FocusModeView appeared")
        }
    }
}

struct SimpleTextView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .black           // Black background
        textView.textColor = .white                 // White text
        textView.insertionPointColor = .white       // White cursor
        textView.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.usesAdaptiveColorMappingForDarkAppearance = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular),
            .paragraphStyle: paragraphStyle
        ]
        textView.typingAttributes = attrs

        // Initialize text
        textView.string = text

        // Wrap in scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = textView.backgroundColor
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.backgroundColor = textView.backgroundColor.cgColor

        // Ensure textView is focused
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SimpleTextView
        init(_ parent: SimpleTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
