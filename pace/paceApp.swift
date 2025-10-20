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
    var statusItem: NSStatusItem?
    private var globalKeyMonitor: Any?
    private var toggleMenuItem: NSMenuItem?
    private var focusMenuItem: NSMenuItem?
    private var heightToggleMenuItem: NSMenuItem?
    
    @Published var bandHeight: CGFloat = 200
    @Published var isDoubleHeight: Bool = false
    @Published var focusText: String = ""
    @Published var isFocusModeActive: Bool = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        
        overlayWindow = OverlayWindow(appDelegate: self)
        overlayWindow?.orderFront(nil)
        
        focusWindow = FocusWindow(appDelegate: self)
        
        setupGlobalShortcuts()
        updateMenuState(overlayVisible: true)
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "flashlight.on.fill", accessibilityDescription: "Pace")
            button.toolTip = "Pace - Reading Focus Tool"
        }
        
        let menu = NSMenu()
        
        toggleMenuItem = NSMenuItem(title: "Pace View (⌥P)", action: #selector(toggleOverlay), keyEquivalent: "p")
        toggleMenuItem?.keyEquivalentModifierMask = .option
        menu.addItem(toggleMenuItem!)
        
        focusMenuItem = NSMenuItem(title: "Focus on Message (⌥M)", action: #selector(toggleFocusMode), keyEquivalent: "m")
        focusMenuItem?.keyEquivalentModifierMask = .option
        menu.addItem(focusMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        let breatheInItem = NSMenuItem(title: "breathe in", action: nil, keyEquivalent: "")
        breatheInItem.isEnabled = false
        menu.addItem(breatheInItem)
        
        menu.addItem(NSMenuItem.separator())
        
        heightToggleMenuItem = NSMenuItem(title: "Normal Height ✓", action: #selector(toggleHeight), keyEquivalent: "")
        menu.addItem(heightToggleMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        let breatheOutItem = NSMenuItem(title: "breathe out", action: nil, keyEquivalent: "")
        breatheOutItem.isEnabled = false
        menu.addItem(breatheOutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit Pace", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func toggleHeight() {
        isDoubleHeight.toggle()
        bandHeight = isDoubleHeight ? 400 : 200
        updateHeightMenuText()
    }
    
    func updateHeightMenuText() {
        heightToggleMenuItem?.title = isDoubleHeight ? "Normal Window" : "Big Window"
    }
    
    func setupGlobalShortcuts() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 35 {
                DispatchQueue.main.async {
                    self?.toggleOverlay()
                }
            } else if event.modifierFlags.contains(.option) && event.keyCode == 46 {
                DispatchQueue.main.async {
                    self?.toggleFocusMode()
                }
            }
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 35 {
                DispatchQueue.main.async {
                    self?.toggleOverlay()
                }
                return nil
            } else if event.modifierFlags.contains(.option) && event.keyCode == 46 {
                DispatchQueue.main.async {
                    self?.toggleFocusMode()
                }
                return nil
            }
            return event
        }
    }
    
    func updateMenuState(overlayVisible: Bool) {
        if overlayVisible {
            toggleMenuItem?.title = "Normal View (⌥P)"
            statusItem?.button?.image = NSImage(systemSymbolName: "flashlight.on.fill", accessibilityDescription: "Pace On")
        } else {
            toggleMenuItem?.title = "Pace View (⌥P)"
            statusItem?.button?.image = NSImage(systemSymbolName: "flashlight.off.fill", accessibilityDescription: "Pace Off")
        }
        updateHeightMenuText()
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
    } else {
        print("✅ Showing focus mode")
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
    }
}
    
    @objc func quitApp() {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        NSApplication.shared.terminate(nil)
    }
    
    deinit {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
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
        
        self.level = .floating
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
    convenience init(appDelegate: AppDelegate) {
        let screenRect = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        self.init(
            contentRect: screenRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
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
}