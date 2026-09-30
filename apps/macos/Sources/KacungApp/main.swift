import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayPanel: NSPanel?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar icon
        setupStatusItem()

        // Setup floating Dynamic Island Notch overlay window
        setupFloatingOverlay()

        // Register AppState window reference
        AppState.shared.overlayWindow = overlayPanel

        // Start quietly in background; overlay only appears on Control + Option hotkey trigger
        AppState.shared.hideOverlay()

        print("Kacung macOS application initialized successfully in background. Press Control+Option to summon.")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Kacung")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 240, height: 260)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(appState: AppState.shared))
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func setupFloatingOverlay() {
        let defaultWidth: CGFloat = 400
        let defaultHeight: CGFloat = 60

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
        panel.contentView = NSHostingView(rootView: contentView)

        // Position exactly at top center of main screen (Notch area)
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = screenFrame.midX - (defaultWidth / 2.0)
            let y = screenFrame.maxY - defaultHeight
            panel.setFrame(NSRect(x: x, y: y, width: defaultWidth, height: defaultHeight), display: true)
        }

        self.overlayPanel = panel
    }
}

// Top-level entry point (runs on Main thread)
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
