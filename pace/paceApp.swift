import SwiftUI
import AppKit
import Sparkle
import Carbon

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

// MARK: - Global Hotkey Manager (Carbon API)
class GlobalHotkeyManager {
    weak var appDelegate: AppDelegate?
    
    // IDs for our hotkeys
    private enum HotkeyID: UInt32 {
        case cycleMode = 1
        case cycleSize = 2
        case turnOff = 3
        case toggleFocus = 4
        case cycleBackground = 5
    }
    
    // Helper to store event handler reference
    private var eventHandler: EventHandlerRef?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        setupHotkeys()
    }
    
    private func setupHotkeys() {
        // Define hotkeys
        // Common modifiers: cmdKey, shiftKey, optionKey, controlKey
        let modifiers = UInt32(optionKey | controlKey)
        
        // ⌃⌥O - Cycle focus modes (KeyCode 31)
        register(id: .cycleMode, keyCode: 31, modifiers: modifiers)
        
        // ⌃⌥P - Cycle sizes (KeyCode 35)
        register(id: .cycleSize, keyCode: 35, modifiers: modifiers)
        
        // ⌃⌥K - Turn off overlay (KeyCode 40)
        register(id: .turnOff, keyCode: 40, modifiers: modifiers)
        
        // ⌃⌥L - Cycle background (KeyCode 37)
        register(id: .cycleBackground, keyCode: 37, modifiers: modifiers)
        
        // ⌃⌥F - Focus message (KeyCode 3)
        register(id: .toggleFocus, keyCode: 3, modifiers: modifiers)
        
        // Install event handler
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]
        
        // Use a C closure for the callback
        // We need to pass 'self' as userData to access instance methods
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            // Reconstruct 'self' from userData
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            return manager.handleEvent(event: event)
        }, 1, eventSpec, selfPointer, &eventHandler)
        
        print("✅ Global hotkey manager initialized with Carbon API")
    }
    
    private func register(id: HotkeyID, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x50414345), id: id.rawValue) // PACE signature
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            print("❌ Failed to register hotkey ID: \(id)")
        }
    }
    
    private func handleEvent(event: EventRef?) -> OSStatus {
        guard let event = event else { return noErr }
        
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        guard status == noErr else { return status }
        
        // Check our signature
        guard hotKeyID.signature == OSType(0x50414345) else { return noErr }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let appDelegate = self.appDelegate else { return }
            
            switch HotkeyID(rawValue: hotKeyID.id) {
            case .cycleMode:
                print("🎹 ⌃⌥O Cycling focus mode")
                appDelegate.cycleNextFocusMode()
                
            case .cycleSize:
                print("🎹 ⌃⌥P Cycling size")
                appDelegate.cycleNextFocusSize()
                
            case .turnOff:
                print("🎹 ⌃⌥K Turning off overlay")
                appDelegate.turnOffOverlay()
                
            case .cycleBackground:
                print("🎹 ⌃⌥L Cycling background")
                appDelegate.cycleBackgroundStyle()
                
            case .toggleFocus:
                print("🎹 ⌃⌥F Toggling focus message")
                appDelegate.toggleFocusMode()
                
            case .none:
                break
            }
        }
        
        return noErr
    }
    
    deinit {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var overlayWindow: OverlayWindow?
    var focusWindow: FocusWindow?
    var flashWindow: FlashWindow?
    var onboardingWindow: OnboardingWindow?
    var sidePanelWindow: SidePanelWindow?
    var statusItem: NSStatusItem?
    private var hotkeyManager: GlobalHotkeyManager?
    
    @Published var isOnboardingActive: Bool = false
    @Published var isSidePanelExpanded: Bool = false
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
        
        // Initialize global hotkey manager (Carbon - No permission needed!)
        hotkeyManager = GlobalHotkeyManager(appDelegate: self)
        
        setupMenuBar()
        
        overlayWindow = OverlayWindow(appDelegate: self)
        focusWindow = FocusWindow(appDelegate: self)
        flashWindow = FlashWindow()
        sidePanelWindow = SidePanelWindow(appDelegate: self)
        
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
        
        // Always show side panel (collapsed by default)
        sidePanelWindow?.orderFront(nil)
    }

    func initializeHotkeyManager() {
        // No-op for now, kept for compatibility if needed, but we init in didFinishLaunching now
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
    
    func createMenuTitle(_ title: String, shortcut: String? = nil) -> NSAttributedString {
        if let shortcut = shortcut {
            let fullString = "\(title)    \(shortcut)"
            let attributedString = NSMutableAttributedString(string: fullString)
            
            // Make the shortcut gray
            let shortcutRange = (fullString as NSString).range(of: shortcut)
            attributedString.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: shortcutRange)
            
            // Right align the shortcut using a paragraph style
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: 200)]
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
            
            return attributedString
        }
        return NSAttributedString(string: title)
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
        toggleMenuItem?.attributedTitle = createMenuTitle("Turn Off", shortcut: "⌃⌥K")
        toggleMenuItem?.state = .off  // Will be updated based on overlay visibility
        menu.addItem(toggleMenuItem!)
        
        // Add focus mode options
        focusModeMenuItems.removeAll()
        for (index, mode) in FocusMode.allCases.enumerated() {
            let modeItem = NSMenuItem(title: mode.displayName, action: #selector(selectFocusMode(_:)), keyEquivalent: "")
            if index == 0 {
                modeItem.attributedTitle = createMenuTitle(mode.displayName, shortcut: "⌃⌥O")
            }
            modeItem.representedObject = mode
            modeItem.state = (mode == focusConfiguration.mode) ? .on : .off
            focusModeMenuItems[mode] = modeItem
            menu.addItem(modeItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add size selector submenu
        let sizeMenu = NSMenu()
        focusSizeMenuItems.removeAll()
        for (index, size) in FocusSize.allCases.enumerated() {
            let sizeItem = NSMenuItem(title: size.displayName, action: #selector(selectFocusSize(_:)), keyEquivalent: "")
            if index == 0 {
                sizeItem.attributedTitle = createMenuTitle(size.displayName, shortcut: "⌃⌥P")
            }
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
        for (index, bgStyle) in BackgroundStyle.allCases.enumerated() {
            let bgItem = NSMenuItem(title: bgStyle.displayName, action: #selector(selectBackgroundStyle(_:)), keyEquivalent: "")
            if index == 0 {
                bgItem.attributedTitle = createMenuTitle(bgStyle.displayName, shortcut: "⌃⌥L")
            }
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
        focusMenuItem?.attributedTitle = createMenuTitle("Show Focus Message", shortcut: "⌃⌥F")
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
        
        menu.addItem(NSMenuItem(title: "Quit Pace", action: #selector(quitApp), keyEquivalent: ""))
        
        statusItem?.menu = menu
    }
    
    @objc func selectFocusMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? FocusMode else { return }
        applyFocusMode(mode)
    }
    
    func applyFocusMode(_ mode: FocusMode) {
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
        applyFocusSize(size)
    }
    
    func applyFocusSize(_ size: FocusSize) {
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
        applyBackgroundStyle(bgStyle)
    }
    
    func applyBackgroundStyle(_ bgStyle: BackgroundStyle) {
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
    
    func cycleBackgroundStyle() {
        // Show overlay if hidden
        if overlayWindow?.isVisible != true {
            overlayShownTime = Date()
            AnalyticsManager.shared.trackPaceViewShown()
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
        }
        
        // Get next bg style in cycle
        let allStyles = BackgroundStyle.allCases
        guard let currentIndex = allStyles.firstIndex(of: focusConfiguration.backgroundStyle) else { return }
        let nextIndex = (currentIndex + 1) % allStyles.count
        let nextStyle = allStyles[nextIndex]
        
        applyBackgroundStyle(nextStyle)
    }
    
    // MARK: - Keyboard Hotkey Methods
    
    @objc func cycleNextFocusMode() {
        // Show overlay if hidden
        if overlayWindow?.isVisible != true {
            overlayShownTime = Date()
            AnalyticsManager.shared.trackPaceViewShown()
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
        }
        
        // Get next mode in cycle
        let allModes = FocusMode.allCases
        guard let currentIndex = allModes.firstIndex(of: focusConfiguration.mode) else { return }
        let nextIndex = (currentIndex + 1) % allModes.count
        let nextMode = allModes[nextIndex]
        
        applyFocusMode(nextMode)
    }
    
    @objc func cycleNextFocusSize() {
        // Show overlay if hidden
        if overlayWindow?.isVisible != true {
            overlayShownTime = Date()
            AnalyticsManager.shared.trackPaceViewShown()
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
        }
        
        // Get next size in cycle
        let allSizes = FocusSize.allCases
        guard let currentIndex = allSizes.firstIndex(of: focusConfiguration.size) else { return }
        let nextIndex = (currentIndex + 1) % allSizes.count
        let nextSize = allSizes[nextIndex]
        
        applyFocusSize(nextSize)
    }
    
    @objc func turnOffOverlay() {
        if overlayWindow?.isVisible == true {
            // Track hide
            if let startTime = overlayShownTime {
                let duration = Date().timeIntervalSince(startTime)
                AnalyticsManager.shared.trackPaceViewHidden(duration: duration)
            }
            overlayWindow?.orderOut(nil)
            updateMenuState(overlayVisible: false)
            updateModeMenusEnabled(enabled: false)
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
    
    // Check for updates...
    @objc func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func toggleSidePanel() {
        isSidePanelExpanded.toggle()
    }
    
    func collapseSidePanel() {
        isSidePanelExpanded = false
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
    // Use performKeyEquivalent to intercept before responder chain
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 53 is the keyCode for ESC
        if event.keyCode == 53 {
            appDelegate?.toggleFocusMode()
            return true
        }
        return super.performKeyEquivalent(with: event)
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

class SidePanelWindow: NSWindow {
    weak var appDelegate: AppDelegate?
    
    convenience init(appDelegate: AppDelegate) {
        // Position at right edge, vertically centered
        // Use small dimensions for collapsed state, will expand when needed
        let collapsedWidth: CGFloat = 20  // Small width for collapsed bar
        let collapsedHeight: CGFloat = 100  // Height for collapsed bar
        let screenRect = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // Window covers full height but positioned at right edge
        // Content will be centered vertically via VStack spacers
        let windowRect = CGRect(x: screenRect.maxX - 270, y: 0, width: 270, height: screenRect.height)
        
        self.init(
            contentRect: windowRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.appDelegate = appDelegate
        
        // CRITICAL: Use mainMenu level (highest) to be above .screenSaver overlay
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        self.contentView = NSHostingView(rootView: SidePanelView(appDelegate: appDelegate))
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}

struct SidePanelView: View {
    @ObservedObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack {
            Spacer()  // Push to vertical center
            
            HStack(spacing: 0) {
                Spacer()
                
                if appDelegate.isSidePanelExpanded {
                    ExpandedSidePanel(appDelegate: appDelegate)
                        .transition(.move(edge: .trailing))
                } else {
                    CollapsedSidePanel(appDelegate: appDelegate)
                        .transition(.move(edge: .trailing))
                }
            }
            
            Spacer()  // Push to vertical center
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appDelegate.isSidePanelExpanded)
    }
}

struct CollapsedSidePanel: View {
    @ObservedObject var appDelegate: AppDelegate
    
    // Determine bar color based on background style
    private var barColor: Color {
        switch appDelegate.focusConfiguration.backgroundStyle {
        case .black, .black70:
            return Color.white
        case .white, .white70:
            return Color.black
        }
    }
    
    var body: some View {
        Button(action: {
            appDelegate.toggleSidePanel()
        }) {
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor)
                .frame(width: 8, height: 80)  // Doubled from 40 to 80
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.trailing, 4)
    }
}

struct ExpandedSidePanel: View {
    @ObservedObject var appDelegate: AppDelegate
    @State private var showSizeSubmenu: Bool = false
    @State private var showBGSubmenu: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()  // Center vertically
                
                VStack(alignment: .leading, spacing: 0) {
                // Header with close button
                HStack {
                    Text("Pace")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        appDelegate.collapseSidePanel()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // ScrollView with max height of 40% screen height
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        // Turn Off button
                        SidePanelButton(
                            title: appDelegate.overlayWindow?.isVisible == true ? "Turn Off" : "Turn On",
                            isChecked: appDelegate.overlayWindow?.isVisible != true,
                            shortcut: "⌃⌥K"
                        ) {
                            appDelegate.toggleOverlay()
                            appDelegate.collapseSidePanel()
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 2)
                    
                    // Focus Modes
                    ForEach(Array(FocusMode.allCases.enumerated()), id: \.element) { index, mode in
                        SidePanelButton(
                            title: mode.displayName,
                            isChecked: mode == appDelegate.focusConfiguration.mode && appDelegate.overlayWindow?.isVisible == true,
                            shortcut: index == 0 ? "⌃⌥O" : nil
                        ) {
                            appDelegate.applyFocusMode(mode)
                            appDelegate.collapseSidePanel()
                        }
                    }
                    
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 2)
                        
                            // Size collapsible submenu
                        Button(action: {
                            withAnimation {
                                showSizeSubmenu.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: showSizeSubmenu ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 12)
                                Text("Size")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    
                        if showSizeSubmenu {
                            ForEach(Array(FocusSize.allCases.enumerated()), id: \.element) { index, size in
                                SidePanelButton(
                                    title: size.displayName,
                                    isChecked: size == appDelegate.focusConfiguration.size,
                                    isIndented: true,
                                    shortcut: index == 0 ? "⌃⌥P" : nil
                                ) {
                                    appDelegate.applyFocusSize(size)
                                    appDelegate.collapseSidePanel()
                                }
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 2)
                        
                        // Background collapsible submenu
                        Button(action: {
                            withAnimation {
                                showBGSubmenu.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: showBGSubmenu ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 12)
                                Text("BG")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    
                        if showBGSubmenu {
                            ForEach(Array(BackgroundStyle.allCases.enumerated()), id: \.element) { index, bgStyle in
                                SidePanelButton(
                                    title: bgStyle.displayName,
                                    isChecked: bgStyle == appDelegate.focusConfiguration.backgroundStyle,
                                    isIndented: true,
                                    shortcut: index == 0 ? "⌃⌥L" : nil
                                ) {
                                    appDelegate.applyBackgroundStyle(bgStyle)
                                    appDelegate.collapseSidePanel()
                                }
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 2)
                        
                        // Focus Message
                        SidePanelButton(
                            title: "Show Focus Message",
                            isChecked: false,
                            shortcut: "⌃⌥F"
                        ) {
                            appDelegate.toggleFocusMode()
                            appDelegate.collapseSidePanel()
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 2)
                        
                        // Flash
                        SidePanelButton(
                            title: appDelegate.isFlashModeActive ? "Flash (Active)" : "Flash",
                            isChecked: appDelegate.isFlashModeActive
                        ) {
                            appDelegate.toggleFlashMode()
                            appDelegate.collapseSidePanel()
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 2)
                        
                        // Extras
                        SidePanelButton(
                            title: "How to Use",
                            isChecked: false
                        ) {
                            appDelegate.showOnboarding()
                            appDelegate.collapseSidePanel()
                        }
                        
                        SidePanelButton(
                            title: "Check for Updates...",
                            isChecked: false
                        ) {
                            appDelegate.checkForUpdates()
                            appDelegate.collapseSidePanel()
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 2)
                        
                        // Quit
                        SidePanelButton(
                            title: "Quit Pace",
                            isChecked: false
                        ) {
                            appDelegate.quitApp()
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: geometry.size.height * 0.32)  // Max 32% of screen height - requires scroll for Quit
                }
                .frame(width: 220)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.85))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: -2, y: 2)
                )
                .padding(.trailing, 8)
                
                Spacer()  // Center vertically
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct SidePanelButton: View {
    let title: String
    let isChecked: Bool
    var isIndented: Bool = false
    var shortcut: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .frame(width: 12)
                } else {
                    Color.clear.frame(width: 12)
                }
                
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, isIndented ? 24 : 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Color.white.opacity(0.0)
        )
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
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
