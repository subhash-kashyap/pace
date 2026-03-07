import SwiftUI
import AppKit

struct OverlayContentView: View {
    @StateObject private var mouseTracker = GlobalMouseTracker()
    @ObservedObject var appDelegate: AppDelegate

    private func mousePosition(in geo: GeometryProxy) -> CGPoint {
        if appDelegate.focusConfiguration.mode == .square || appDelegate.focusConfiguration.mode == .circle {
            return CGPoint(x: mouseTracker.mouseX, y: mouseTracker.mouseY)
        }
        // Rectangle and Box follow mouse vertically only.
        return CGPoint(x: geo.size.width / 2, y: mouseTracker.mouseY)
    }

    private func focusPath(in rect: CGRect, at position: CGPoint) -> Path {
        let config = appDelegate.focusConfiguration
        switch config.mode {
        case .rectangle:
            return RectangleShape(height: config.rectangleHeight).createMask(in: rect, at: position)
        case .centerColumn:
            return BoxShape(size: config.boxSize).createMask(in: rect, at: position)
        case .square:
            return SquareShape(size: config.squareSize).createMask(in: rect, at: position)
        case .circle:
            return CircleShape(diameter: config.circleDiameter).createMask(in: rect, at: position)
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .local)
            let position = mousePosition(in: geo)
            let cutout = focusPath(in: frame, at: position)

            Path { path in
                path.addRect(frame)
                path.addPath(cutout)
            }
            .fill(
                appDelegate.focusConfiguration.backgroundStyle.color,
                style: FillStyle(eoFill: true)
            )
        }
        .edgesIgnoringSafeArea(.all)
        .allowsHitTesting(false)
        .onAppear {
            mouseTracker.setTrackingEnabled(appDelegate.isOverlayVisible)
            NSApp.activate(ignoringOtherApps: true) // ensures global events fire immediately
        }
        .onChange(of: appDelegate.isOverlayVisible) { isVisible in
            mouseTracker.setTrackingEnabled(isVisible)
        }
        .onDisappear {
            mouseTracker.setTrackingEnabled(false)
        }
    }
}

struct TimerBubbleView: View {
    @ObservedObject var appDelegate: AppDelegate
    @State private var showingCustomInput = false
    @State private var customMinutes = ""
    
    private var timeString: String {
        let hours = Int(appDelegate.timeRemaining) / 3600
        let minutes = (Int(appDelegate.timeRemaining) % 3600) / 60
        let seconds = Int(appDelegate.timeRemaining) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Main Timer Bubble
            HStack(spacing: 12) {
                // Play/Pause/Stop indicators or actual buttons
                HStack(spacing: 10) {
                    if appDelegate.isTimerFinishedFlashActive {
                        Button(action: {
                            appDelegate.stopFinishedFlash()
                        }) {
                            Text("STOP")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                    } else {
                        Button(action: {
                            if appDelegate.timerStatus == .playing {
                                appDelegate.pauseTimer()
                            } else if appDelegate.timerStatus == .paused {
                                appDelegate.resumeTimer()
                            } else {
                                appDelegate.startTimer(duration: 25 * 60)
                            }
                        }) {
                            Image(systemName: appDelegate.timerStatus == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if appDelegate.timerStatus != .stopped {
                            Button(action: {
                                appDelegate.stopTimer()
                            }) {
                                Image(systemName: "square.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Text(timeString)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(minWidth: 80)
                
                Button(action: {
                    appDelegate.removeTimer()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(appDelegate.isTimerFinishedFlashActive ? Color.red : Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Preset Options (Only show when not finished)
            if !appDelegate.isTimerFinishedFlashActive {
                HStack(spacing: 8) {
                    TimerPresetButton(label: "1m") { appDelegate.startTimer(duration: 60) }
                    TimerPresetButton(label: "5m") { appDelegate.startTimer(duration: 5 * 60) }
                    TimerPresetButton(label: "25m") { appDelegate.startTimer(duration: 25 * 60) }
                    TimerPresetButton(label: "1h") { appDelegate.startTimer(duration: 3600) }
                    
                    Button(action: {
                        showingCustomInput.toggle()
                    }) {
                        Text("Custom")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if showingCustomInput {
                    HStack {
                        TextField("Mins", text: $customMinutes)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                            .foregroundColor(.white)
                            .frame(width: 50)
                        
                        Button("Start") {
                            if let mins = Double(customMinutes) {
                                appDelegate.startTimer(duration: mins * 60)
                                showingCustomInput = false
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                }
            }
        }
        .animation(.spring(), value: appDelegate.isTimerFinishedFlashActive)
        .animation(.spring(), value: showingCustomInput)
    }
}

struct TimerPresetButton: View {
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
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

    init() {}

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

            self.mouseY = flippedY
            self.mouseX = adjustedX
        }

        timer.tolerance = updateInterval / 2.0
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        self.timer = timer
    }

    func setTrackingEnabled(_ enabled: Bool) {
        if enabled {
            startTracking()
        } else {
            stopTracking()
        }
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
        textView.textColor = .white                 // White text
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
