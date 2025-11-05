import SwiftUI
import AppKit

@main
struct PaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var overlayWindow: OverlayWindow?
    var focusWindow: FocusWindow?
    var flashWindow: FlashWindow?
    var statusItem: NSStatusItem?
    private var toggleMenuItem: NSMenuItem?
    private var focusMenuItem: NSMenuItem?
    private var flashMenuItem: NSMenuItem?
    private var focusModeMenuItems: [NSMenuItem] = []
    private var flashTimer: Timer?
    private var lastFlashTime: Date?
    
    // Track whether the overlay was visible before entering focus mode
    private var prevOverlayWasVisible: Bool = false

    @Published var bandHeight: CGFloat = 200
    @Published var isDoubleHeight: Bool = false
    @Published var focusText: String = ""
    @Published var isFocusModeActive: Bool = false
    @Published var isFlashModeActive: Bool = false
    @Published var focusConfiguration: FocusConfiguration = FocusConfiguration.current
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Load saved configuration
        focusConfiguration = FocusConfiguration.current
        bandHeight = focusConfiguration.bandHeight
        isDoubleHeight = bandHeight > 200
        
        setupMenuBar()
        
        overlayWindow = OverlayWindow(appDelegate: self)
        overlayWindow?.orderFront(nil)
        
        focusWindow = FocusWindow(appDelegate: self)
        flashWindow = FlashWindow()
        
        updateMenuState(overlayVisible: true)
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "flashlight.on.fill", accessibilityDescription: "Pace")
            button.toolTip = "Pace - Reading Focus Tool"
        }
        
        let menu = NSMenu()
        
        toggleMenuItem = NSMenuItem(title: "Hide Pace View", action: #selector(toggleOverlay), keyEquivalent: "")
        menu.addItem(toggleMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add focus mode options directly to main menu
        focusModeMenuItems.removeAll()
        for mode in FocusMode.allCases {
            let menuItem = NSMenuItem(title: mode.displayName, action: #selector(selectFocusMode(_:)), keyEquivalent: "")
            menuItem.representedObject = mode
            menuItem.state = (mode == focusConfiguration.mode) ? .on : .off
            focusModeMenuItems.append(menuItem)
            menu.addItem(menuItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        focusMenuItem = NSMenuItem(title: "Show Focus Message", action: #selector(toggleFocusMode), keyEquivalent: "")
        menu.addItem(focusMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        flashMenuItem = NSMenuItem(title: "Flash", action: #selector(toggleFlashMode), keyEquivalent: "")
        menu.addItem(flashMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        let breatheOutItem = NSMenuItem(title: "Breathe in - Breathe out, repeat", action: nil, keyEquivalent: "")
        breatheOutItem.isEnabled = false
        menu.addItem(breatheOutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit Pace", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func selectFocusMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? FocusMode else { return }
        
        focusConfiguration.mode = mode
        
        // Update band height based on mode
        if mode == .smallWindow {
            focusConfiguration.bandHeight = 200
            bandHeight = 200
            isDoubleHeight = false
        } else if mode == .bigWindow {
            focusConfiguration.bandHeight = 400
            bandHeight = 400
            isDoubleHeight = true
        }
        
        // Save configuration
        FocusConfiguration.current = focusConfiguration
        
        // Update menu checkmarks
        updateFocusModeMenu()
    }
    
    func updateFocusModeMenu() {
        for item in focusModeMenuItems {
            if let mode = item.representedObject as? FocusMode {
                item.state = (mode == focusConfiguration.mode) ? .on : .off
            }
        }
    }
    
    func updateMenuState(overlayVisible: Bool) {
        if overlayVisible {
            toggleMenuItem?.title = "Hide Pace View"
            statusItem?.button?.image = NSImage(systemSymbolName: "flashlight.on.fill", accessibilityDescription: "Pace On")
        } else {
            toggleMenuItem?.title = "Show Pace View"
            statusItem?.button?.image = NSImage(systemSymbolName: "flashlight.off.fill", accessibilityDescription: "Pace Off")
        }
    }
    
    @objc func toggleOverlay() {
        if let window = overlayWindow {
            if window.isVisible {
                window.orderOut(nil)
                updateMenuState(overlayVisible: false)
            } else {
                if isFocusModeActive {
                    focusWindow?.orderOut(nil)
                    isFocusModeActive = false
                }
                window.orderFront(nil)
                updateMenuState(overlayVisible: true)
            }
        }
    }
    
    @objc func toggleFocusMode() {
        guard let focusWindow = focusWindow else {
            print("⚠️ focusWindow is nil!")
            return
        }

        if isFocusModeActive {
            print("❌ Hiding focus mode")
            focusWindow.orderOut(nil)
            isFocusModeActive = false
            focusMenuItem?.title = "Show Focus Message"

            // Restore overlay if it was visible before entering focus mode
            if prevOverlayWasVisible {
                overlayWindow?.orderFront(nil)
                updateMenuState(overlayVisible: true)
                NSApp.activate(ignoringOtherApps: true)       // 🪄 Reactivate app
            }
        } else {
            print("✅ Showing focus mode")

            // remember whether overlay is visible so we can restore it on close
            prevOverlayWasVisible = (overlayWindow?.isVisible == true)

            if overlayWindow?.isVisible == true {
                overlayWindow?.orderOut(nil)
                updateMenuState(overlayVisible: false)
            }
            focusWindow.orderFront(nil)
            focusWindow.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            print("🎯 Window level: \(focusWindow.level.rawValue)")
            print("🎯 Is key window: \(focusWindow.isKeyWindow)")
            print("🎯 First responder: \(focusWindow.firstResponder.debugDescription)")
            isFocusModeActive = true
            focusMenuItem?.title = "Hide Focus Message"
        }
    }
    
    @objc func toggleFlashMode() {
        // Toggle the Flash Mode state
        isFlashModeActive.toggle()
        
        // Update menu item checkmark state
        flashMenuItem?.state = isFlashModeActive ? .on : .off
        
        if isFlashModeActive {
            // Activating Flash Mode
            showFlashBorder()
            startFlashTimer()
        } else {
            // Deactivating Flash Mode
            cancelFlashTimer()
            // Reset menu title when deactivated
            flashMenuItem?.title = "Flash"
        }
    }
    
    func updateFlashMenuTitle() {
        guard let lastFlash = lastFlashTime else {
            flashMenuItem?.title = "Flash"
            return
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: lastFlash)
        flashMenuItem?.title = "Flashed at \(timeString)"
    }
    
    func showFlashBorder() {
        guard let flashWindow = flashWindow else { return }
        
        // Update last flash time
        lastFlashTime = Date()
        updateFlashMenuTitle()
        
        // Create new FlashBorderView with completion callback
        let flashView = FlashBorderView(onComplete: { [weak self] in
            // Hide window after animation completes
            self?.flashWindow?.orderOut(nil)
        })
        
        // Update window content with new view (to restart animation)
        flashWindow.contentView = NSHostingView(rootView: flashView)
        
        // Order flashWindow to front
        flashWindow.orderFront(nil)
    }
    
    func startFlashTimer() {
        // Cancel any existing timer first
        cancelFlashTimer()
        
        // Create Timer with 25-minute interval (25 * 60 seconds)
        flashTimer = Timer.scheduledTimer(
            withTimeInterval: 25 * 60,
            repeats: true
        ) { [weak self] _ in
            // Call showFlashBorder in timer callback
            self?.showFlashBorder()
        }
    }
    
    func cancelFlashTimer() {
        // Invalidate timer if it exists
        flashTimer?.invalidate()
        // Set flashTimer to nil
        flashTimer = nil
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

class OverlayWindow: NSWindow {
    convenience init(appDelegate: AppDelegate) {
        let screenRect = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        self.init(
            contentRect: screenRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Put overlay above the Dock and menubar
        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.acceptsMouseMovedEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.setFrame(screenRect, display: true)
        
        self.contentView = NSHostingView(rootView: OverlayContentView(appDelegate: appDelegate))
    }
}

class FocusWindow: NSWindow {
    // keep a weak reference to the app delegate so the window can signal ESC
    weak var appDelegate: AppDelegate?
    
    convenience init(appDelegate: AppDelegate) {
        let screenRect = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        self.init(
            contentRect: screenRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.appDelegate = appDelegate
        
        self.level = .statusBar
        self.backgroundColor = .black
        self.isOpaque = true
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.setFrame(screenRect, display: true)
        
        self.contentView = NSHostingView(rootView: FocusModeView(appDelegate: appDelegate))
    }
    
    // CRITICAL: Allow window to become key so it can receive keyboard input
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // Close focus mode when the user presses ESC
    override func keyDown(with event: NSEvent) {
        // 53 is the keyCode for ESC
        if event.keyCode == 53 {
            appDelegate?.toggleFocusMode()
        } else {
            super.keyDown(with: event)
        }
    }
}

class FlashWindow: NSWindow {
    convenience init() {
        let screenRect = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        self.init(
            contentRect: screenRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window to be above everything but transparent and non-interactive
        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.setFrame(screenRect, display: true)
        
        // Initialize with FlashBorderView
        self.contentView = NSHostingView(rootView: FlashBorderView(onComplete: {}))
    }
}

// FlashBorderView - Task 3.1: Structure with state and callback
struct FlashBorderView: View {
    @State private var opacity: Double = 0.0
    @State private var pulseCount: Int = 0
    var onComplete: () -> Void
    
    var body: some View {
        // Border stroke with gradient from top-left (white) to bottom-right (red)
        Rectangle()
            .strokeBorder(
                LinearGradient(
                    gradient: Gradient(colors: [Color.white, Color.red]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 8
            )
            .opacity(opacity)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                startPulseAnimation()
            }
    }
    
    // Task 3.3: Implement pulse animation
    private func startPulseAnimation() {
        // Reset state
        opacity = 0.0
        pulseCount = 0
        
        // Create repeating animation: 6 pulses over 3 seconds = 0.5s per pulse
        // Each pulse is 0.25s fade in + 0.25s fade out
        withAnimation(.easeInOut(duration: 0.25).repeatCount(12, autoreverses: true)) {
            opacity = 0.7  // More opaque so it's clearly visible
        }
        
        // Call onComplete after 3 seconds (6 complete pulses)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            onComplete()
        }
    }
}
