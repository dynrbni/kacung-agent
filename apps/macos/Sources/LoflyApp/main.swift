import AppKit
import SwiftUI

final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard AppState.shared.isVisibleOnScreen else { return nil }

        // Cocoa view coordinates: y=0 is bottom, y=bounds.height is top.
        // Determine active hit area based on current state.
        let state = AppState.shared.state
        let isExpanded = AppState.shared.isOutputExpanded && !AppState.shared.lastResponse.isEmpty
        let isActiveState = (state == .thinking || state == .executing || state == .error)

        // Height of the interactive notch area
        let barHeight: CGFloat
        if isExpanded {
            barHeight = 280.0 // bar + dropdown panel
        } else if isActiveState {
            barHeight = 52.0  // expanded bar
        } else {
            barHeight = (AppState.shared.notchTopInset > 0 ? AppState.shared.notchTopInset + 4.0 : 40.0)
        }

        let islandBottomY = bounds.height - barHeight
        if point.y < islandBottomY {
            return nil
        }

        // Width of the interactive notch area
        let activeWidth: CGFloat
        if isExpanded {
            activeWidth = 420.0
        } else if isActiveState {
            activeWidth = 400.0
        } else {
            activeWidth = 350.0
        }

        let islandLeftX = (bounds.width - activeWidth) / 2.0
        let islandRightX = islandLeftX + activeWidth
        if point.x < islandLeftX || point.x > islandRightX {
            return nil
        }

        return super.hitTest(point)
    }
}

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayPanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup standard application main menu bar for regular macOS app
        setupMainMenu()

        // Setup floating Dynamic Island Notch overlay window
        setupFloatingOverlay()

        // Register AppState window reference
        AppState.shared.overlayWindow = overlayPanel

        // Start quietly in background; overlay only appears on Control + Option hotkey trigger
        AppState.shared.hideOverlay()

        NotificationService.shared.requestAuthorization()

        // Open desktop window
        DesktopWindowController.shared.show()

        NSLog("[Lofly] applicationDidFinishLaunching - AXIsProcessTrusted: %d", AXIsProcessTrusted() ? 1 : 0)
        print("Lofly macOS application initialized successfully. Running in Dock and background.")
    }

    /// When user clicks Dock icon, re-open the desktop companion window
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DesktopWindowController.shared.show()
        return true
    }

    /// Closing the desktop window must not terminate the app; background tasks,
    /// voice recognition, and notch overlay continue running in the background.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc func newChatAction() {
        DesktopStore.shared.activeSurface = .chat
        DesktopStore.shared.newConversation()
        DesktopWindowController.shared.show()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Lofly", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Lofly", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Lofly", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File Menu (Native Cmd+N for New Chat)
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Chat", action: #selector(AppDelegate.newChatAction), keyEquivalent: "n")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit Menu (crucial for Cmd+C, Cmd+V, Cmd+X, Cmd+A in TextField)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupFloatingOverlay() {
        let defaultWidth: CGFloat = 560
        let defaultHeight: CGFloat = 320

        let panel = NotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        // Level above status window overlays seamlessly on top of notch & menu bar
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false

        let contentView = FloatingOverlayView(appState: AppState.shared)
        panel.contentView = NotchHostingView(rootView: contentView)

        // Position exactly at top center of notch screen
        let notchScreen = getNotchScreen()
        let screenFrame = notchScreen.frame
        let x = screenFrame.midX - (defaultWidth / 2.0)
        let y = screenFrame.maxY - defaultHeight
        panel.setFrame(NSRect(x: x, y: y, width: defaultWidth, height: defaultHeight), display: true)

        self.overlayPanel = panel
    }
}

// Top-level entry point (runs on Main thread)
MainActor.assumeIsolated {
    if CommandLine.arguments.contains("--check-ax") {
        let trusted = AXIsProcessTrusted()
        print("AX_RESULT:\(trusted)")
        exit(trusted ? 0 : 1)
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
