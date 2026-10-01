import SwiftUI
import AppKit

/// Window controller for the desktop companion.
///
/// Closing the window only hides it: the agent server keeps running and the
/// menu bar notch stays the lightweight surface, so a background task started
/// from here continues to completion.
@MainActor
public final class DesktopWindowController {
    public static let shared = DesktopWindowController()

    private var window: NSWindow?

    private init() {}

    /// True while the desktop window is on screen. The notch defers to the
    /// desktop companion whenever this is true: push-to-talk still works, but
    /// its capture and result surface inline in the chat panel instead.
    public var isVisible: Bool {
        window?.isVisible ?? false
    }

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let store = DesktopStore.shared
        store.bind()
        store.refreshConversations()
        store.refreshTasks()
        store.refreshAccount()

        let contentView = DesktopRootView()
            .environmentObject(store)
            .frame(minWidth: 960, minHeight: 620)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Lofly"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0.094, green: 0.094, blue: 0.094, alpha: 1.0)
        window.appearance = NSAppearance(named: .darkAqua)
        window.center()
        window.setFrameAutosaveName("LoflyDesktopWindow")
        let hostingController = NSHostingController(rootView: contentView)
        window.contentViewController = hostingController
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationService.shared.requestAuthorization()

        self.window = window
    }

    public func toggle() {
        if let window, window.isVisible {
            window.orderOut(nil)
        } else {
            show()
        }
    }

    public func close() {
        window?.orderOut(nil)
    }
}

/// Root shell: sidebar navigation plus the selected surface.
///
/// The detail surface lives in `DesktopStore.activeSurface` rather than local
/// state, so a push-to-talk started anywhere can bring the chat forward.
public struct DesktopRootView: View {
    @EnvironmentObject private var store: DesktopStore

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            if store.isSidebarVisible {
                DesktopSidebar()
                    .frame(width: LoflyTheme.sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                LoflySeparator(.vertical)
            }

            VStack(spacing: 0) {
                DesktopTopBar()

                LoflySeparator(.horizontal)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(LoflyTheme.contentBackground)
        .ignoresSafeArea(.all, edges: .top)
        // Closing the window must not tear down the agent: the app is a
        // background accessory, so the desktop surface is purely additive.
        .onAppear {
            store.bind()
            store.refreshConversations()
            store.refreshTasks()
        }
        .overlay(alignment: .bottom) {
            if let banner = store.banner {
                LoflyBanner(text: banner) { store.dismissBanner() }
                    .padding(.bottom, LoflyTheme.Space.l)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch store.activeSurface {
        case .chat: ChatView()
        case .activity: ActivityView()
        case .integrations: IntegrationsView()
        case .skills: SkillsView()
        case .account: AccountView()
        case .settings: SettingsView()
        }
    }
}
