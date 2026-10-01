import SwiftUI
import AppKit

public enum DesktopSection: String, CaseIterable, Identifiable, Hashable {
    case chat
    case tasks
    case integrations
    case memory
    case activity
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .chat: return "Chats"
        case .tasks: return "Tasks"
        case .integrations: return "Integrations"
        case .memory: return "Memory"
        case .activity: return "Activity"
        case .settings: return "Settings"
        }
    }

    public var symbol: String {
        switch self {
        case .chat: return "bubble.left.and.text.bubble.right"
        case .tasks: return "checklist"
        case .integrations: return "square.grid.2x2"
        case .memory: return "brain"
        case .activity: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

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

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let store = DesktopStore()
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
        window.title = "Lafly"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("LaflyDesktopWindow")
        window.contentView = NSHostingView(rootView: contentView)
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

/// Root shell: sidebar navigation plus the selected screen.
public struct DesktopRootView: View {
    @EnvironmentObject private var store: DesktopStore
    @State private var section: DesktopSection = .chat

    public init() {}

    public var body: some View {
        NavigationSplitView {
            DesktopSidebar(section: $section)
                .navigationSplitViewColumnWidth(
                    min: LaflyTheme.sidebarWidth,
                    ideal: LaflyTheme.sidebarWidth,
                    max: LaflyTheme.sidebarWidth + 60
                )
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(LaflyTheme.surface)
        // Closing the window must not tear down the agent: the app is a
        // background accessory, so the desktop surface is purely additive.
        .onAppear {
            store.bind()
            store.refreshConversations()
            store.refreshTasks()
        }
        .overlay(alignment: .bottom) {
            if let banner = store.banner {
                LaflyBanner(text: banner) { store.dismissBanner() }
                    .padding(.bottom, LaflyTheme.Space.l)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .chat: ChatView()
        case .tasks: TasksView()
        case .integrations: IntegrationsView()
        case .memory: MemoryView()
        case .activity: ActivityView()
        case .settings: SettingsView()
        }
    }
}

/// Compact sidebar. Only the six sections the control centre actually needs —
/// no nested navigation, no decorative rows.
struct DesktopSidebar: View {
    @EnvironmentObject private var store: DesktopStore
    @Binding var section: DesktopSection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            connectionRow
                .padding(.horizontal, LaflyTheme.Space.m)
                .padding(.top, LaflyTheme.Space.m)
                .padding(.bottom, LaflyTheme.Space.s)

            LaflySeparator()
                .padding(.bottom, LaflyTheme.Space.s)

            ScrollView {
                VStack(alignment: .leading, spacing: LaflyTheme.Space.xs) {
                    ForEach(DesktopSection.allCases) { item in
                        sidebarButton(item)
                    }
                }
                .padding(.horizontal, LaflyTheme.Space.s)
            }

            Spacer(minLength: 0)

            accountRow
                .padding(.horizontal, LaflyTheme.Space.m)
                .padding(.vertical, LaflyTheme.Space.s)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var connectionRow: some View {
        HStack(spacing: LaflyTheme.Space.s) {
            Circle()
                .fill(store.isConnected ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Lafly Agent")
                    .font(LaflyTheme.label(LaflyTheme.Size.caption))
                Text(store.isConnected ? "Connected" : "Disconnected")
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !store.isConnected {
                Button {
                    store.bind()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: LaflyTheme.Size.caption))
                }
                .buttonStyle(.borderless)
                .help("Retry connection")
                .accessibilityLabel("Retry connection")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            store.isConnected ? "Lafly Agent connected" : "Lafly Agent disconnected"
        )
    }

    private func sidebarButton(_ item: DesktopSection) -> some View {
        Button {
            section = item
        } label: {
            HStack(spacing: LaflyTheme.Space.s) {
                Image(systemName: item.symbol)
                    .font(.system(size: LaflyTheme.Size.callout))
                    .frame(width: 16)
                Text(item.title)
                    .font(LaflyTheme.body(LaflyTheme.Size.body))
                Spacer()
                if item == .tasks, let active = store.activeTask, active.isRunning {
                    Circle()
                        .fill(LaflyTheme.accent)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Task running")
                }
            }
            .padding(.horizontal, LaflyTheme.Space.s)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LaflyTheme.Radius.small, style: .continuous)
                    .fill(section == item ? LaflyTheme.accent.opacity(0.14) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(section == item ? [.isSelected] : [])
    }

    private var accountRow: some View {
        HStack(spacing: LaflyTheme.Space.s) {
            Image(systemName: store.account.signedIn ? "person.crop.circle.fill" : "person.crop.circle")
                .font(.system(size: LaflyTheme.Size.body))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.account.signedIn ? (store.account.displayName ?? "Signed in") : "Signed out")
                    .font(LaflyTheme.body(LaflyTheme.Size.caption))
                Text("Local account")
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Inline banner for recoverable errors. Never a modal: the app stays usable.
struct LaflyBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: LaflyTheme.Space.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(LaflyTheme.body(LaflyTheme.Size.callout))
                .lineLimit(2)
            Spacer(minLength: LaflyTheme.Space.s)
            Button("Dismiss", action: onDismiss)
                .buttonStyle(.borderless)
                .font(LaflyTheme.label(LaflyTheme.Size.caption))
        }
        .padding(.horizontal, LaflyTheme.Space.m)
        .padding(.vertical, LaflyTheme.Space.s)
        .background(
            RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                .fill(LaflyTheme.surface)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                .stroke(LaflyTheme.separator, lineWidth: 0.5)
        )
        .padding(.horizontal, LaflyTheme.Space.l)
    }
}
