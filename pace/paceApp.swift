import SwiftUI
import AppKit
import Sparkle

@main
struct PaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize analytics
        AnalyticsManager.shared.configure()
    }
    
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
    var onboardingWindow: OnboardingWindow?
    var statusItem: NSStatusItem?
    
    @Published var isOnboardingActive: Bool = false
    private var toggleMenuItem: NSMenuItem?
    private var focusMenuItem: NSMenuItem?
    private var flashMenuItem: NSMenuItem?
    private var focusModeMenuItems: [FocusMode: NSMenuItem] = [:]
    private var focusSizeMenuItems: [FocusSize: NSMenuItem] = [:]
    private var backgroundStyleMenuItems: [BackgroundStyle: NSMenuItem] = [:]
    private var flashTimer: Timer?
    private var lastFlashTime: Date?
    
    // Track whether the overlay was visible before entering focus mode
    private var prevOverlayWasVisible: Bool = false
    
    // Analytics tracking
    private var overlayShownTime: Date?
    private var focusModeShownTime: Date?
    
    // Sparkle updater
    private var updaterController: SPUStandardUpdaterController?

    @Published var focusText: String = ""
    @Published var isFocusModeActive: Bool = false
    @Published var isFlashModeActive: Bool = false
    @Published var focusConfiguration: FocusConfiguration = FocusConfiguration.current
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Track app opened
        AnalyticsManager.shared.trackAppOpened()
        
        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        // Load saved configuration
        focusConfiguration = FocusConfiguration.current
        
        setupMenuBar()
        
        overlayWindow = OverlayWindow(appDelegate: self)
        focusWindow = FocusWindow(appDelegate: self)
        flashWindow = FlashWindow()
        
        // Check if user has seen onboarding
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        
        onboardingWindow = OnboardingWindow(appDelegate: self)
        
        if !hasSeenOnboarding {
            // Show onboarding, don't show overlay yet
            isOnboardingActive = true
            onboardingWindow?.orderFront(nil)
            onboardingWindow?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            updateMenuState(overlayVisible: false)
            updateModeMenusEnabled(enabled: false)
        } else {
            // Show overlay immediately for returning users
            overlayWindow?.orderFront(nil)
            overlayShownTime = Date()
            updateMenuState(overlayVisible: true)
            updateModeMenusEnabled(enabled: true)
            
            // Track initial mode
            AnalyticsManager.shared.trackModeActivated(
                mode: focusConfiguration.mode.rawValue,
                size: focusConfiguration.size.rawValue
            )
            AnalyticsManager.shared.trackPaceViewShown()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Track app closed and any active sessions
        if let startTime = overlayShownTime, overlayWindow?.isVisible == true {
            let duration = Date().timeIntervalSince(startTime)
            AnalyticsManager.shared.trackPaceViewHidden(duration: duration)
        }
        
        if let startTime = focusModeShownTime, isFocusModeActive {
            let duration = Date().timeIntervalSince(startTime)
            AnalyticsManager.shared.trackFocusModeHidden(duration: duration)
        }
        
        AnalyticsManager.shared.trackModeDeactivated(mode: focusConfiguration.mode.rawValue)
        AnalyticsManager.shared.trackAppClosed()
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "flashlight.on.fill", accessibilityDescription: "Pace")
            button.toolTip = "Pace - Reading Focus Tool"
        }
        
        let menu = NSMenu()
        
        // Add "Turn Off" as first option
        toggleMenuItem = NSMenuItem(title: "Turn Off", action: #selector(toggleOverlay), keyEquivalent: "")
        toggleMenuItem?.state = .off  // Will be updated based on overlay visibility
        menu.addItem(toggleMenuItem!)
        
        // Add focus mode options
        focusModeMenuItems.removeAll()
        for mode in FocusMode.allCases {
            let modeItem = NSMenuItem(title: mode.displayName, action: #selector(selectFocusMode(_:)), keyEquivalent: "")
            modeItem.representedObject = mode
            modeItem.state = (mode == focusConfiguration.mode) ? .on : .off
            focusModeMenuItems[mode] = modeItem
            menu.addItem(modeItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add size selector submenu
        let sizeMenu = NSMenu()
        focusSizeMenuItems.removeAll()
        for size in FocusSize.allCases {
            let sizeItem = NSMenuItem(title: size.displayName, action: #selector(selectFocusSize(_:)), keyEquivalent: "")
            sizeItem.representedObject = size
            sizeItem.state = (size == focusConfiguration.size) ? .on : .off
            focusSizeMenuItems[size] = sizeItem
            sizeMenu.addItem(sizeItem)
        }
        
        let sizeMenuItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeMenuItem.submenu = sizeMenu
        menu.addItem(sizeMenuItem)
        
        // Add background style selector submenu
        let bgMenu = NSMenu()
        backgroundStyleMenuItems.removeAll()
        for bgStyle in BackgroundStyle.allCases {
            let bgItem = NSMenuItem(title: bgStyle.displayName, action: #selector(selectBackgroundStyle(_:)), keyEquivalent: "")
            bgItem.representedObject = bgStyle
            bgItem.state = (bgStyle == focusConfiguration.backgroundStyle) ? .on : .off
            backgroundStyleMenuItems[bgStyle] = bgItem
            bgMenu.addItem(bgItem)
        }
        
        let bgMenuItem = NSMenuItem(title: "BG", action: nil, keyEquivalent: "")
        bgMenuItem.submenu = bgMenu
        menu.addItem(bgMenuItem)
        
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
        
        // Add Extras submenu
        let extrasMenu = NSMenu()
        
        let howToUseItem = NSMenuItem(title: "How to Use", action: #selector(showOnboarding), keyEquivalent: "")
        extrasMenu.addItem(howToUseItem)
        
        let checkForUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        extrasMenu.addItem(checkForUpdatesItem)
        
        let extrasMenuItem = NSMenuItem(title: "Extras", action: nil, keyEquivalent: "")
        extrasMenuItem.submenu = extrasMenu
        menu.addItem(extrasMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit Pace", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func selectFocusMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? FocusMode else { return }
        
        // Track mode change
        AnalyticsManager.shared.trackModeDeactivated(mode: focusConfiguration.mode.rawValue)
        
        focusConfiguration.mode = mode
        FocusConfiguration.current = focusConfiguration
        
        AnalyticsManager.shared.trackModeActivated(
            mode: mode.rawValue,
            size: focusConfiguration.size.rawValue
        )
        
        // Show overlay if it's hidden
        if overlayWindow?.isVisible != true {
            overlayShownTime = Date()
            AnalyticsManager.shared.trackPaceViewShown()
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
        }
        
        updateFocusModeMenu()
    }
    
    @objc func selectFocusSize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? FocusSize else { return }
        
        // Track size change (as a mode update)
        AnalyticsManager.shared.trackModeDeactivated(mode: focusConfiguration.mode.rawValue)
        
        focusConfiguration.size = size
        FocusConfiguration.current = focusConfiguration
        
        AnalyticsManager.shared.trackModeActivated(
            mode: focusConfiguration.mode.rawValue,
            size: size.rawValue
        )
        
        // Show overlay if it's hidden
        if overlayWindow?.isVisible != true {
            overlayShownTime = Date()
            AnalyticsManager.shared.trackPaceViewShown()
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
        }
        
        updateFocusSizeMenu()
    }
    
    func updateFocusModeMenu() {
        let overlayVisible = overlayWindow?.isVisible == true
        for (mode, item) in focusModeMenuItems {
            // Only show checkmark on active mode if overlay is visible
            item.state = (overlayVisible && mode == focusConfiguration.mode) ? .on : .off
        }
    }
    
    func updateFocusSizeMenu() {
        for (size, item) in focusSizeMenuItems {
            item.state = (size == focusConfiguration.size) ? .on : .off
        }
    }
    
    func updateBackgroundStyleMenu() {
        for (bgStyle, item) in backgroundStyleMenuItems {
            item.state = (bgStyle == focusConfiguration.backgroundStyle) ? .on : .off
        }
    }
    
    @objc func selectBackgroundStyle(_ sender: NSMenuItem) {
        guard let bgStyle = sender.representedObject as? BackgroundStyle else { return }
        
        focusConfiguration.backgroundStyle = bgStyle
        FocusConfiguration.current = focusConfiguration
        
        // Show overlay if it's hidden
        if overlayWindow?.isVisible != true {
            overlayShownTime = Date()
            AnalyticsManager.shared.trackPaceViewShown()
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
        }
        
        updateBackgroundStyleMenu()
    }
    
    func updateMenuState(overlayVisible: Bool) {
        if overlayVisible {
            // Overlay is visible - uncheck "Turn Off", check the active mode
            toggleMenuItem?.state = .off
        } else {
            // Overlay is hidden - check "Turn Off", uncheck all modes
            toggleMenuItem?.state = .on
        }
        updateFocusModeMenu()
    }
    
    @objc func toggleOverlay() {
        if let window = overlayWindow {
            if window.isVisible {
                // Track hide
                if let startTime = overlayShownTime {
                    let duration = Date().timeIntervalSince(startTime)
                    AnalyticsManager.shared.trackPaceViewHidden(duration: duration)
                }
                window.orderOut(nil)
                updateMenuState(overlayVisible: false)
                updateModeMenusEnabled(enabled: false)
            } else {
                // Track show
                overlayShownTime = Date()
                AnalyticsManager.shared.trackPaceViewShown()
                
                if isFocusModeActive {
                    focusWindow?.orderOut(nil)
                    isFocusModeActive = false
                }
                window.orderFront(nil)
                updateMenuState(overlayVisible: true)
                updateModeMenusEnabled(enabled: true)
            }
        }
    }
    
    func updateModeMenusEnabled(enabled: Bool) {
        // Mode, size, and background menu items are always enabled now
        // Users can click them to both show overlay and change settings in one action
        for (_, item) in focusModeMenuItems {
            item.isEnabled = true
        }
        
        for (_, item) in focusSizeMenuItems {
            item.isEnabled = true
        }
        
        for (_, item) in backgroundStyleMenuItems {
            item.isEnabled = true
        }
    }
    
    @objc func toggleFocusMode() {
        guard let focusWindow = focusWindow else {
            print("⚠️ focusWindow is nil!")
            return
        }

        if isFocusModeActive {
            print("❌ Hiding focus mode")
            
            // Track focus mode hidden
            if let startTime = focusModeShownTime {
                let duration = Date().timeIntervalSince(startTime)
                AnalyticsManager.shared.trackFocusModeHidden(duration: duration)
            }
            
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
            
            // Track focus mode shown
            focusModeShownTime = Date()
            AnalyticsManager.shared.trackFocusModeShown()

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
        
        // Track flash mode toggle
        AnalyticsManager.shared.trackFlashModeToggled(isActive: isFlashModeActive)
        
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
        
        // Track flash triggered
        AnalyticsManager.shared.trackFlashTriggered()
        
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
    
    @objc func showOnboarding() {
        guard let onboardingWindow = onboardingWindow else { return }
        
        // Hide overlay if visible
        if overlayWindow?.isVisible == true {
            overlayWindow?.orderOut(nil)
            updateMenuState(overlayVisible: false)
        }
        
        // Show onboarding
        isOnboardingActive = true
        onboardingWindow.orderFront(nil)
        onboardingWindow.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeOnboarding() {
        isOnboardingActive = false
        onboardingWindow?.orderOut(nil)
        
        // Show overlay for the first time (only on initial onboarding)
        if overlayWindow?.isVisible != true && !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
            // Set default to Circle mode with Medium size and Black 70% background
            focusConfiguration.mode = .circle
            focusConfiguration.size = .medium
            focusConfiguration.backgroundStyle = .black70
            FocusConfiguration.current = focusConfiguration
            updateFocusModeMenu()
            updateFocusSizeMenu()
            updateBackgroundStyleMenu()
            
            overlayWindow?.orderFront(nil)
            overlayShownTime = Date()
            updateMenuState(overlayVisible: true)
            updateModeMenusEnabled(enabled: true)
            
            // Track initial mode
            AnalyticsManager.shared.trackModeActivated(
                mode: focusConfiguration.mode.rawValue,
                size: focusConfiguration.size.rawValue
            )
            AnalyticsManager.shared.trackPaceViewShown()
        } else {
            // Restore overlay if it was visible before
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
            updateModeMenusEnabled(enabled: true)
        }
    }
    
    @objc func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
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

class OnboardingWindow: NSWindow {
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
        self.backgroundColor = .white
        self.isOpaque = true
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.setFrame(screenRect, display: true)
        
        self.contentView = NSHostingView(rootView: OnboardingContainerView(appDelegate: appDelegate))
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        // Close onboarding when ESC is pressed
        if event.keyCode == 53 {
            appDelegate?.closeOnboarding()
        } else {
            super.keyDown(with: event)
        }
    }
}

struct OnboardingContainerView: View {
    @ObservedObject var appDelegate: AppDelegate
    @State private var currentPage: Int = 1
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        appDelegate.closeOnboarding()
                        currentPage = 1  // Reset to first page
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.black.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                }
                
                Spacer()
                
                OnboardingView(
                    currentPage: $currentPage,
                    onComplete: {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        appDelegate.closeOnboarding()
                        currentPage = 1  // Reset to first page
                    }
                )
                
                Spacer()
            }
        }
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
