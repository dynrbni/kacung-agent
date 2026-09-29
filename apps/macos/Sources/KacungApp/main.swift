import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayPanel: NSPanel?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar icon
        setupStatusItem()

        // Setup floating Siri-style overlay window
        setupFloatingOverlay()

        // Register AppState window reference
        AppState.shared.overlayWindow = overlayPanel

        // Show overlay and start listening on initial launch
        AppState.shared.showOverlay()
        AppState.shared.startListening()

        print("Kacung macOS application initialized successfully and is listening.")
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
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true

        let contentView = FloatingOverlayView(appState: AppState.shared)
        panel.contentView = NSHostingView(rootView: contentView)

        // Center on screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - 200
            let y = screenRect.midY - 50 // Slightly higher than exact center
            panel.setFrameOrigin(NSPoint(x: x, y: y))
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
