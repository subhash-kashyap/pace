import SwiftUI
import AppKit

struct OverlayContentView: View {
    @StateObject private var mouseTracker = GlobalMouseTracker()
    @ObservedObject var appDelegate: AppDelegate
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Make background very opaque and remove the grid overlay
                Rectangle()
                    .fill(Color.black.opacity(0.99))
                    .mask(
                        Rectangle()
                            .overlay(
                                Rectangle()
                                    .frame(height: appDelegate.bandHeight)
                                    .position(
                                        x: geo.size.width / 2,
                                        y: mouseTracker.mouseY
                                    )
                                    .blendMode(.destinationOut)
                            )
                    )
                    .animation(.easeOut(duration: 0.15), value: mouseTracker.mouseY)
                    .animation(.easeOut(duration: 0.3), value: appDelegate.bandHeight)
                
                // GridOverlay removed
            }
        }
        .edgesIgnoringSafeArea(.all)
        .allowsHitTesting(false)
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

class GlobalMouseTracker: ObservableObject {
    @Published var mouseY: CGFloat = 400
    private var globalMonitor: Any?

    init() {
        startTracking()
    }

    func startTracking() {
        // Remove any existing monitor first
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }

        // Use only the global monitor (receives events regardless of app active state)
        DispatchQueue.main.async {
            self.globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                guard let self = self else { return }
                let screenHeight = NSScreen.main?.frame.height ?? 1080
                let mouseLocation = NSEvent.mouseLocation
                let flippedY = screenHeight - mouseLocation.y

                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.12)) {
                        self.mouseY = flippedY
                    }
                }
            }
        }
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
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
                        // Use a small white 'x' letter instead of the system icon
                        Text("x")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28, alignment: .center)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 12)
                    .padding(.trailing, 12)
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
