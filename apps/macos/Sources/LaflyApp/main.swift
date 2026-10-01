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

        // The activation policy stays .accessory: the app has no Dock icon and
        // closing the desktop window only hides it, so background tasks and the
        // notch keep working.
        NotificationService.shared.requestAuthorization()

        NSLog("[Lafly] applicationDidFinishLaunching - AXIsProcessTrusted: %d", AXIsProcessTrusted() ? 1 : 0)
        print("Lafly macOS application initialized successfully in background. Press Control+Option to summon.")
    }

    /// Closing the desktop window must not terminate the app; a running task
    /// has to be allowed to finish.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Lafly")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 240, height: 260)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(appState: AppState.shared) {
                popover.performClose(nil)
                DesktopWindowController.shared.show()
            }
        )
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
    if CommandLine.arguments.contains("--check-ax") {
        let trusted = AXIsProcessTrusted()
        print("AX_RESULT:\(trusted)")
        exit(trusted ? 0 : 1)
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
