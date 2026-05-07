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
        case cycleBackground = 5
        case toggleSidePanel = 6
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
        
        // ⌃⌥S - Toggle Side Panel (KeyCode 1)
        register(id: .toggleSidePanel, keyCode: 1, modifiers: modifiers)
        
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
                appDelegate.cycleColorMode()
                
            case .toggleSidePanel:
                print("🎹 ⌃⌥S Toggling side panel")
                appDelegate.toggleSidePanel()
                
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
    var onboardingWindow: OnboardingWindow?
    var sidePanelWindow: SidePanelWindow?
    var statusItem: NSStatusItem?
    private var hotkeyManager: GlobalHotkeyManager?

    @Published var isOnboardingActive: Bool = false
    @Published var isSidePanelExpanded: Bool = false
    private var toggleMenuItem: NSMenuItem?
    private var focusModeMenuItems: [FocusMode: NSMenuItem] = [:]
    private var focusSizeMenuItems: [FocusSize: NSMenuItem] = [:]
    private 

    // Analytics tracking
    private var overlayShownTime: Date?

    // Sparkle updater
    private var updaterController: SPUStandardUpdaterController?

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
        if let startTime = overlayShownTime, overlayWindow?.isVisible == true {
            let duration = Date().timeIntervalSince(startTime)
            AnalyticsManager.shared.trackPaceViewHidden(duration: duration)
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
    

    var opacitySliderView: MenuSliderView?
    var blurSliderView: MenuSliderView?
    var colorToggleItem: NSMenuItem?

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Pace")
            button.toolTip = "Pace - Reading Focus Tool"
        }
        
        let menu = NSMenu()
        
        // --- 1. Shape ---
        let shapeMenu = NSMenu()
        focusModeMenuItems.removeAll()
        for (index, mode) in FocusMode.allCases.enumerated() {
            let modeItem = NSMenuItem(title: mode.displayName, action: #selector(selectFocusMode(_:)), keyEquivalent: "")
            if index == 0 {
                modeItem.attributedTitle = createMenuTitle(mode.displayName, shortcut: "⌃⌥O")
            }
            modeItem.representedObject = mode
            modeItem.state = (mode == focusConfiguration.mode) ? .on : .off
            focusModeMenuItems[mode] = modeItem
            shapeMenu.addItem(modeItem)
        }
        let shapeMenuItem = NSMenuItem(title: "Shape", action: nil, keyEquivalent: "")
        shapeMenuItem.image = NSImage(systemSymbolName: "square.on.circle", accessibilityDescription: nil)
        shapeMenuItem.submenu = shapeMenu
        menu.addItem(shapeMenuItem)
        
        // --- 2. Size ---
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
        sizeMenuItem.image = NSImage(systemSymbolName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", accessibilityDescription: nil)
        sizeMenuItem.submenu = sizeMenu
        menu.addItem(sizeMenuItem)
        
        // --- 3. Color ---
        let colorMenu = NSMenu()
        let darkItem = NSMenuItem(title: "Dark", action: #selector(selectDarkMode), keyEquivalent: "")
        darkItem.state = focusConfiguration.isDarkMode ? .on : .off
        let lightItem = NSMenuItem(title: "Light", action: #selector(selectLightMode), keyEquivalent: "")
        lightItem.state = !focusConfiguration.isDarkMode ? .on : .off
        colorMenu.addItem(darkItem)
        colorMenu.addItem(lightItem)
        
        let colorMenuItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        colorMenuItem.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)
        colorMenuItem.submenu = colorMenu
        menu.addItem(colorMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- 4. Opacity Slider ---
        let opacityMenuItem = NSMenuItem()
        let opView = MenuSliderView(title: "Opacity", iconName: "circle.lefthalf.filled", value: focusConfiguration.opacity, minValue: 0.1, maxValue: 1.0)
        opView.valueFormatter = { "\(Int(zsh * 100))%" }
        opView.onValueChanged = { [weak self] val in
            self?.applyOpacity(val)
        }
        opacityMenuItem.view = opView
        opacitySliderView = opView
        menu.addItem(opacityMenuItem)
        
        // --- 5. Blur Slider ---
        let blurMenuItem = NSMenuItem()
        let blView = MenuSliderView(title: "Blur", iconName: "drop", value: focusConfiguration.blurRadius, minValue: 0.0, maxValue: 20.0)
        blView.valueFormatter = { "\(Int(zsh))px" }
        blView.onValueChanged = { [weak self] val in
            self?.applyBlurRadius(val)
        }
        blurMenuItem.view = blView
        blurSliderView = blView
        menu.addItem(blurMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- 6. Settings ---
        let settingsMenu = NSMenu()
        let howToUseItem = NSMenuItem(title: "How to Use", action: #selector(showOnboarding), keyEquivalent: "")
        settingsMenu.addItem(howToUseItem)
        let checkForUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        settingsMenu.addItem(checkForUpdatesItem)
        settingsMenu.addItem(NSMenuItem.separator())
        settingsMenu.addItem(NSMenuItem(title: "Quit Pace", action: #selector(quitApp), keyEquivalent: ""))
        
        let settingsMenuItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsMenuItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settingsMenuItem.submenu = settingsMenu
        menu.addItem(settingsMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- 7. Hide Overlay (Turn Off) ---
        toggleMenuItem = NSMenuItem(title: "Hide Overlay", action: #selector(toggleOverlay), keyEquivalent: "")
        toggleMenuItem?.attributedTitle = createMenuTitle("Hide Overlay", shortcut: "⌃⌥K")
        toggleMenuItem?.state = .off
        menu.addItem(toggleMenuItem!)
        
        statusItem?.menu = menu
    }
    
    @objc func selectFocusMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? FocusMode else { return }
        applyFocusMode(mode)
    }
    
    func applyFocusMode(_ mode: FocusMode) {
        AnalyticsManager.shared.trackModeDeactivated(mode: focusConfiguration.mode.rawValue)
        focusConfiguration.mode = mode
        FocusConfiguration.current = focusConfiguration
        AnalyticsManager.shared.trackModeActivated(mode: mode.rawValue, size: focusConfiguration.size.rawValue)
        
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
        AnalyticsManager.shared.trackModeDeactivated(mode: focusConfiguration.mode.rawValue)
        focusConfiguration.size = size
        FocusConfiguration.current = focusConfiguration
        AnalyticsManager.shared.trackModeActivated(mode: focusConfiguration.mode.rawValue, size: size.rawValue)
        
        if overlayWindow?.isVisible != true {
            overlayShownTime = Date()
            AnalyticsManager.shared.trackPaceViewShown()
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
        }
        updateFocusSizeMenu()
    }
    
    @objc func selectDarkMode() {
        applyDarkMode(true)
    }
    
    @objc func selectLightMode() {
        applyDarkMode(false)
    }
    
    func applyDarkMode(_ isDark: Bool) {
        focusConfiguration.isDarkMode = isDark
        FocusConfiguration.current = focusConfiguration
        
        if overlayWindow?.isVisible != true {
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
        }
        updateColorMenu()
    }
    
    func applyOpacity(_ opacity: Double) {
        focusConfiguration.opacity = opacity
        FocusConfiguration.current = focusConfiguration
        
        if overlayWindow?.isVisible != true {
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
        }
    }
    
    func applyBlurRadius(_ blur: Double) {
        focusConfiguration.blurRadius = blur
        FocusConfiguration.current = focusConfiguration
        
        if overlayWindow?.isVisible != true {
            overlayWindow?.orderFront(nil)
            updateMenuState(overlayVisible: true)
        }
    }
    
    func updateFocusModeMenu() {
        let overlayVisible = overlayWindow?.isVisible == true
        for (mode, item) in focusModeMenuItems {
            item.state = (overlayVisible && mode == focusConfiguration.mode) ? .on : .off
        }
    }
    
    func updateFocusSizeMenu() {
        for (size, item) in focusSizeMenuItems {
            item.state = (size == focusConfiguration.size) ? .on : .off
        }
    }
    
    func updateColorMenu() {
        // Re-setup menu or just update items via iteration if we stored them
        // For simplicity, we can rely on recreating or updating. 
        // We'll fetch them dynamically.
        if let menu = statusItem?.menu, let colorItem = menu.item(withTitle: "Color"), let submenu = colorItem.submenu {
            for item in submenu.items {
                if item.title == "Dark" {
                    item.state = focusConfiguration.isDarkMode ? .on : .off
                } else if item.title == "Light" {
                    item.state = !focusConfiguration.isDarkMode ? .on : .off
                }
            }
        }
    }
    
    func updateMenuState(overlayVisible: Bool) {
        if overlayVisible {
            toggleMenuItem?.state = .off
        } else {
            toggleMenuItem?.state = .on
        }
        updateFocusModeMenu()
        updateStatusIcon(overlayVisible: overlayVisible)
    }

    func updateStatusIcon(overlayVisible: Bool) {
        let symbolName = overlayVisible ? "eye" : "eye.slash"
        statusItem?.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Pace")
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
    @State private var isHovering: Bool = false
    
    // Determine bar color based on background style
    private var barColor: Color {
        return appDelegate.focusConfiguration.isDarkMode ? Color.white : Color.black
    }
    
    var body: some View {
        Button(action: {
            appDelegate.toggleSidePanel()
        }) {
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor)
                .frame(width: 8, height: 80)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isHovering ? 1.0 : 0.0)
        .padding(.trailing, 4)
        .padding(.leading, 20) // Wider invisible hit area
        .padding(.vertical, 20)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct ExpandedSidePanel: View {
    @ObservedObject var appDelegate: AppDelegate
    @State private var showShapeSubmenu: Bool = false
    @State private var showSizeSubmenu: Bool = false
    @State private var showColorSubmenu: Bool = false
    @State private var showSettingsSubmenu: Bool = false
    
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
                
                // ScrollView
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        
                        // --- 1. Shape ---
                        Button(action: { withAnimation { showShapeSubmenu.toggle() } }) {
                            HStack {
                                Image(systemName: "square.on.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 16)
                                Text("Shape")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: showShapeSubmenu ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showShapeSubmenu {
                            ForEach(Array(FocusMode.allCases.enumerated()), id: \.element) { index, mode in
                                SidePanelButton(
                                    title: mode.displayName,
                                    isChecked: mode == appDelegate.focusConfiguration.mode && appDelegate.overlayWindow?.isVisible == true,
                                    isIndented: true,
                                    shortcut: index == 0 ? "⌃⌥O" : nil
                                ) {
                                    appDelegate.applyFocusMode(mode)
                                    appDelegate.collapseSidePanel()
                                }
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 2)
                        
                        // --- 2. Size ---
                        Button(action: { withAnimation { showSizeSubmenu.toggle() } }) {
                            HStack {
                                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 16)
                                Text("Size")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: showSizeSubmenu ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
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
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 2)
                        
                        // --- 3. Color ---
                        Button(action: { withAnimation { showColorSubmenu.toggle() } }) {
                            HStack {
                                Image(systemName: "paintpalette")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 16)
                                Text("Color")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: showColorSubmenu ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showColorSubmenu {
                            SidePanelButton(title: "Dark", isChecked: appDelegate.focusConfiguration.isDarkMode, isIndented: true) {
                                appDelegate.applyDarkMode(true)
                                appDelegate.collapseSidePanel()
                            }
                            SidePanelButton(title: "Light", isChecked: !appDelegate.focusConfiguration.isDarkMode, isIndented: true) {
                                appDelegate.applyDarkMode(false)
                                appDelegate.collapseSidePanel()
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 2)
                        
                        // --- 4. Opacity ---
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "circle.lefthalf.filled")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 16)
                                Text("Opacity")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(appDelegate.focusConfiguration.opacity * 100))%")
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            
                            Slider(value: Binding(
                                get: { appDelegate.focusConfiguration.opacity },
                                set: { appDelegate.applyOpacity(zsh) }
                            ), in: 0.1...1.0)
                            .padding(.horizontal, 12)
                        }
                        .padding(.vertical, 5)
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 2)
                        
                        // --- 5. Blur ---
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "drop")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 16)
                                Text("Blur")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(appDelegate.focusConfiguration.blurRadius))px")
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            
                            Slider(value: Binding(
                                get: { appDelegate.focusConfiguration.blurRadius },
                                set: { appDelegate.applyBlurRadius(zsh) }
                            ), in: 0...20)
                            .padding(.horizontal, 12)
                        }
                        .padding(.vertical, 5)
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 2)
                        
                        // --- 6. Settings ---
                        Button(action: { withAnimation { showSettingsSubmenu.toggle() } }) {
                            HStack {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 16)
                                Text("Settings")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: showSettingsSubmenu ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showSettingsSubmenu {
                            SidePanelButton(title: "How to Use", isChecked: false, isIndented: true) {
                                appDelegate.showOnboarding()
                                appDelegate.collapseSidePanel()
                            }
                            SidePanelButton(title: "Check for Updates...", isChecked: false, isIndented: true) {
                                appDelegate.checkForUpdates()
                                appDelegate.collapseSidePanel()
                            }
                            SidePanelButton(title: "Quit Pace", isChecked: false, isIndented: true) {
                                appDelegate.quitApp()
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 2)
                        
                        // --- 7. Hide Overlay ---
                        SidePanelButton(
                            title: appDelegate.overlayWindow?.isVisible == true ? "Hide Overlay" : "Show Overlay",
                            isChecked: false,
                            shortcut: "⌃⌥K"
                        ) {
                            appDelegate.toggleOverlay()
                            appDelegate.collapseSidePanel()
                        }
                        
                        Spacer().frame(height: 10)
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: geometry.size.height * 0.7)
                }
                .frame(width: 200)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.trailing, 10)
                
                Spacer()  // Center vertically
            }
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

