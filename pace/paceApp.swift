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
    var statusItem: NSStatusItem?
    private var globalKeyMonitor: Any?
    private var toggleMenuItem: NSMenuItem?
    private var heightToggleMenuItem: NSMenuItem?
    
    // Height state directly in AppDelegate
    @Published var bandHeight: CGFloat = 200
    @Published var isDoubleHeight: Bool = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        
        // Pass self as the state holder
        overlayWindow = OverlayWindow(appDelegate: self)
        overlayWindow?.orderFront(nil)
        
        setupGlobalShortcut()
        updateMenuState(overlayVisible: true)
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "flashlight.on.fill", accessibilityDescription: "Pace")
            button.toolTip = "Pace - Reading Focus Tool"
        }
        
        let menu = NSMenu()
        
        // Main toggle
        toggleMenuItem = NSMenuItem(title: "Normal View (⌥P)", action: #selector(toggleOverlay), keyEquivalent: "p")
        toggleMenuItem?.keyEquivalentModifierMask = .option
        menu.addItem(toggleMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        // Height toggle option
        heightToggleMenuItem = NSMenuItem(title: "Normal Height ✓", action: #selector(toggleHeight), keyEquivalent: "")
        menu.addItem(heightToggleMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit confirmation reminder (greyed out)
        let confirmationItem = NSMenuItem(title: "You sure?", action: nil, keyEquivalent: "")
        confirmationItem.isEnabled = false
        menu.addItem(confirmationItem)
        
        // Actual quit option
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
    
    func setupGlobalShortcut() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 35 {
                DispatchQueue.main.async {
                    self?.toggleOverlay()
                }
            }
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 35 {
                DispatchQueue.main.async {
                    self?.toggleOverlay()
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
                window.orderFront(nil)
                updateMenuState(overlayVisible: true)
            }
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
        
        // Pass appDelegate to SwiftUI
        self.contentView = NSHostingView(rootView: OverlayContentView(appDelegate: appDelegate))
    }
}
