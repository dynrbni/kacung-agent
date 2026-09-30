import AppKit
import SwiftUI

final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard AppState.shared.isVisibleOnScreen else { return nil }
        
        // Cocoa view coordinates: y=0 is bottom, y=bounds.height is top.
        // Active island content is anchored at the top of the hosting view.
        let activeHeight: CGFloat = AppState.shared.isOutputExpanded ? 240.0 : (AppState.shared.notchTopInset > 0 ? AppState.shared.notchTopInset + 4.0 : 36.0)
        let islandBottomY = bounds.height - activeHeight
        
        // If mouse is below the active island area, pass through to windows underneath
        if point.y < islandBottomY {
            return nil
        }

        // Pass through mouse clicks to left/right of the compact notch island
        let activeWidth: CGFloat = 350.0
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
            AppState.shared.checkPermissions()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
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
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
