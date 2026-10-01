import SwiftUI
import AppKit

/// Sidebar: Native macOS navigation panel with quiet, lightweight graphite styling,
/// proportional spacing, traffic lights clearance, and subtle selection states.
struct DesktopSidebar: View {
    @EnvironmentObject private var store: DesktopStore
    @State private var isHoveringNewChat = false
    @State private var isSearchVisible = false

    private var isNewChatActive: Bool {
        store.selectedConversationId == nil && store.activeSurface == .chat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            wordmark
                .frame(height: 44)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    newChatButton
                        .padding(.top, 4)
                        .padding(.bottom, 6)

                    navigationRows
                        .padding(.bottom, 12)

                    chatsSection
                }
                .padding(.horizontal, 8)
            }

            LoflySeparator()

            accountFooter
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(LoflyTheme.sidebarBackground)
    }

    // MARK: - Wordmark (macOS Traffic Lights Clearance + Wordmark + Tools)

    private var wordmark: some View {
        HStack(spacing: 6) {
            // Traffic lights clearance (~76pt)
            Spacer()
                .frame(width: 76)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(LoflyTheme.accent)
                Text("Lofly")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(LoflyTheme.primaryText)
            }

            Spacer(minLength: 4)

            // Search toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSearchVisible.toggle()
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(isSearchVisible ? LoflyTheme.primaryText : LoflyTheme.secondaryText)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                            .fill(isSearchVisible ? LoflyTheme.subtleFill : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Search chats")
            .accessibilityLabel("Search")

            // Collapse sidebar button
            Button(action: { store.toggleSidebar() }) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 12))
                    .foregroundStyle(LoflyTheme.secondaryText)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                            .fill(Color.clear)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close sidebar")
            .accessibilityLabel("Close sidebar")
        }
        .padding(.trailing, 8)
    }

    // MARK: - Primary: New Chat Button

    private var newChatButton: some View {
        Button(action: startNewChat) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(isNewChatActive ? LoflyTheme.primaryText : LoflyTheme.secondaryText)

                Text("New chat")
                    .font(.system(size: 13, weight: isNewChatActive ? .semibold : .medium))
                    .lineLimit(1)
                    .foregroundStyle(isNewChatActive ? LoflyTheme.primaryText : LoflyTheme.primaryText.opacity(0.92))

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                    .fill(isNewChatActive ? LoflyTheme.selectedFill : (isHoveringNewChat ? LoflyTheme.hoverFill : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                    .stroke(isNewChatActive ? LoflyTheme.borderSubtle : Color.clear, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHoveringNewChat = $0 }
        .help("Start a new conversation")
        .accessibilityLabel("New chat")
    }

    private func startNewChat() {
        store.activeSurface = .chat
        store.newConversation()
    }

    // MARK: - Secondary: Navigation Rows

    private var navigationRows: some View {
        VStack(alignment: .leading, spacing: 2) {
            LoflySidebarRow(
                "Activity",
                symbol: "clock.arrow.circlepath",
                isSelected: store.activeSurface == .activity,
                trailing: { runningTaskDot },
                action: { store.activeSurface = .activity }
            )

            LoflySidebarRow(
                "Integrations",
                symbol: "square.grid.2x2",
                isSelected: store.activeSurface == .integrations,
                trailing: { connectedCount },
                action: { store.activeSurface = .integrations }
            )

            LoflySidebarRow(
                "Skills",
                symbol: "slider.horizontal.3",
                isSelected: store.activeSurface == .skills,
                trailing: { EmptyView() },
                action: { store.activeSurface = .skills }
            )
        }
    }

    @ViewBuilder
    private var runningTaskDot: some View {
        if let active = store.activeTask, active.isRunning {
            Circle()
                .fill(LoflyTheme.accent)
                .frame(width: 6, height: 6)
        }
    }

    @ViewBuilder
    private var connectedCount: some View {
        let count = store.integrations.filter { $0.status == .connected }.count
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LoflyTheme.tertiaryText)
        }
    }

    // MARK: - Recents Section

    private var chatsSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                LoflySectionHeader("Recents")
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 4)

            if isSearchVisible || !store.historySearch.isEmpty {
                LoflySidebarSearchField(text: $store.historySearch)
                    .padding(.bottom, 6)
            }

            if store.conversations.isEmpty {
                emptyHistory
            } else {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(store.conversations) { summary in
                        historyRow(summary)
                    }
                }
            }
        }
    }

    private var emptyHistory: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.historySearch.isEmpty
                 ? "No chats yet."
                 : "No chats match \"\(store.historySearch)\".")
                .font(.system(size: 12))
                .foregroundStyle(LoflyTheme.tertiaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
    }

    private func historyRow(_ summary: ConversationSummary) -> some View {
        let isSelected = store.selectedConversationId == summary.id && store.activeSurface == .chat

        return LoflySidebarRow(
            summary.title,
            isSelected: isSelected,
            action: { store.openConversation(summary.id) }
        )
        .help("\(summary.title) — updated \(LoflyDate.relative(milliseconds: summary.updatedAt))")
        .contextMenu {
            Button("Rename…") {
                let alert = NSAlert()
                alert.messageText = "Rename conversation"
                let field = NSTextField(string: summary.title)
                alert.accessoryView = field
                alert.addButton(withTitle: "Rename")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                    store.renameConversation(summary.id, to: field.stringValue)
                }
            }
            Button("Delete", role: .destructive) {
                store.deleteConversation(summary.id)
            }
        }
    }

    // MARK: - Bottom: Settings & Profile

    private var accountFooter: some View {
        HStack(spacing: 8) {
            Button {
                store.activeSurface = .account
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.20))
                        Text(avatarInitials)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LoflyTheme.primaryText)
                    }
                    .frame(width: 26, height: 26)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(displayName)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(LoflyTheme.primaryText)
                            .lineLimit(1)
                        Text("Active")
                            .font(.system(size: 10.5))
                            .foregroundStyle(LoflyTheme.tertiaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                store.activeSurface = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(store.activeSurface == .settings ? LoflyTheme.accent : LoflyTheme.secondaryText)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                            .fill(store.activeSurface == .settings ? LoflyTheme.accent.opacity(0.12) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var displayName: String {
        let name = store.account.displayName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !name.isEmpty { return name }
        return "Dean Rabbani"
    }

    private var avatarInitials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}
