import SwiftUI
import AppKit

/// Redesigned macOS toolbar inspired by Codex:
/// - Clean centered conversation title
/// - Glass-effect navigation and action buttons
/// - Proper traffic lights clearance
/// - Minimal, balanced layout with generous spacing
public struct DesktopTopBar: View {
    @EnvironmentObject private var store: DesktopStore
    @State private var isHoveringMore = false
    @State private var isHoveringThreads = false

    public init() {}

    public var body: some View {
        ZStack {
            // Centered title
            centeredTitle

            // Left controls
            HStack(spacing: 0) {
                leftControls
                Spacer()
            }

            // Right controls
            HStack(spacing: 0) {
                Spacer()
                rightControls
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 14)
        .background(topBarBackground)
    }

    // MARK: - Top Bar Background

    private var topBarBackground: some View {
        ZStack {
            LoflyTheme.contentBackground
            // Subtle glass overlay at the top
            LinearGradient(
                colors: [
                    Color.white.opacity(0.015),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Left Controls (Sidebar Toggle + Nav)

    private var leftControls: some View {
        HStack(spacing: 6) {
            if !store.isSidebarVisible {
                // Traffic lights clearance when sidebar is hidden
                Spacer()
                    .frame(width: 76)

                GlassButton(
                    icon: "sidebar.leading",
                    help: "Open sidebar"
                ) {
                    store.toggleSidebar()
                }
            }

            // Navigation back/forward in a glass pill
            navPill
        }
        .padding(.leading, store.isSidebarVisible ? 6 : 0)
    }

    // MARK: - Navigation Pill (Back / Forward)

    private var navPill: some View {
        HStack(spacing: 0) {
            Button(action: { store.goBack() }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(store.canGoBack ? LoflyTheme.primaryText.opacity(0.85) : LoflyTheme.tertiaryText.opacity(0.45))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!store.canGoBack)
            .help("Back")

            // Subtle divider inside the pill
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1, height: 14)

            Button(action: { store.goForward() }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(store.canGoForward ? LoflyTheme.primaryText.opacity(0.85) : LoflyTheme.tertiaryText.opacity(0.45))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!store.canGoForward)
            .help("Forward")
        }
        .background(GlassPillBackground())
    }

    // MARK: - Centered Title

    private var centeredTitle: some View {
        HStack(spacing: 0) {
            let title = currentTitle
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LoflyTheme.primaryText.opacity(0.9))
                .lineLimit(1)
                .frame(maxWidth: 360)
                .animation(.easeInOut(duration: 0.2), value: title)
        }
    }

    private var currentTitle: String {
        if let convId = store.selectedConversationId,
           let conv = store.conversations.first(where: { $0.id == convId }) {
            return conv.title
        }
        return "New chat"
    }

    // MARK: - Right Controls

    private var rightControls: some View {
        HStack(spacing: 6) {
            // Thread switcher dropdown
            threadSwitcher

            // More menu button
            GlassButton(icon: "ellipsis", help: "More options") {
                // Future: show context menu
            }
        }
        .padding(.trailing, 2)
    }

    // MARK: - Thread Switcher (Compact Dropdown Style)

    @ViewBuilder
    private var threadSwitcher: some View {
        if !store.openThreadIds.isEmpty || store.selectedConversationId != nil {
            Menu {
                // New thread at the top
                Button {
                    store.newConversation()
                } label: {
                    Label("New thread", systemImage: "plus")
                }

                Divider()

                // List of open threads
                ForEach(store.openThreadIds, id: \.self) { threadId in
                    let conv = store.conversations.first(where: { $0.id == threadId })
                    let title = conv?.title ?? "Chat"
                    let isSelected = store.selectedConversationId == threadId

                    Button {
                        store.selectConversation(threadId)
                    } label: {
                        HStack {
                            Text(title)
                            if isSelected {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if store.openThreadIds.count > 1 {
                    Divider()

                    Button("Close other threads") {
                        if let current = store.selectedConversationId {
                            for id in store.openThreadIds where id != current {
                                store.closeThread(id)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.stack")
                        .font(.system(size: 11, weight: .medium))
                    Text("\(max(1, store.openThreadIds.count))")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(LoflyTheme.secondaryText)
                .frame(height: 28)
                .padding(.horizontal, 10)
                .background(GlassPillBackground())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Switch threads")
        } else {
            // Single new chat — show a small + button to start a thread
            GlassButton(icon: "plus", help: "New thread") {
                store.newConversation()
            }
        }
    }
}

// MARK: - Glass Button Component

/// A single icon button with a frosted glass background effect,
/// matching Codex's elevated button aesthetic.
struct GlassButton: View {
    let icon: String
    var iconSize: CGFloat = 12
    var help: String = ""
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(isHovering ? LoflyTheme.primaryText.opacity(0.9) : LoflyTheme.secondaryText)
                .frame(width: 30, height: 28)
                .background(
                    GlassPillBackground(isHovering: isHovering)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

// MARK: - Glass Pill Background

/// Frosted glass pill background used by top bar buttons.
/// Creates a subtle elevated, translucent surface effect.
struct GlassPillBackground: View {
    var isHovering: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                .ultraThinMaterial
            )
            .opacity(isHovering ? 1.0 : 0.6)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.06 : 0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(isHovering ? 0.12 : 0.06), lineWidth: 0.5)
            )
            .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}
