import SwiftUI
import AppKit

/// Sidebar: Faithful ChatGPT macOS aesthetic with symmetrical padding,
/// perfectly aligned traffic lights clearance, highlighted active "New chat" state,
/// comfortable row heights, and "Dean Rabbani" account footer.
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
                .frame(height: 48)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    newChatButton
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                    navigationRows
                        .padding(.bottom, 10)

                    chatsSection
                }
                .padding(.horizontal, 10)
            }

            LoflySeparator()

            accountFooter
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(LoflyTheme.surface)
    }

    // MARK: - Wordmark (Height 48pt, perfectly level with macOS traffic lights)

    private var wordmark: some View {
        HStack(spacing: 6) {
            // Traffic lights clearance (macOS red, yellow, green buttons sit at x: 18-20, y: 18-20)
            Spacer()
                .frame(width: 76)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LoflyTheme.accent)
                Text("Lofly")
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 4)

            // Search toggle
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isSearchVisible.toggle()
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSearchVisible ? Color.primary : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSearchVisible ? Color.primary.opacity(0.08) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Cari percakapan")
            .accessibilityLabel("Search")

            // Close sidebar button ([|])
            Button(action: { store.toggleSidebar() }) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.clear)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close sidebar")
            .accessibilityLabel("Close sidebar")
        }
        .padding(.trailing, 10)
    }

    // MARK: - New chat Button (Highlighted when in new chat/draft)

    private var newChatButton: some View {
        Button(action: startNewChat) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(isNewChatActive ? Color.primary : Color.secondary)

                Text("New chat")
                    .font(.system(size: 14, weight: isNewChatActive ? .semibold : .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isNewChatActive ? Color.primary.opacity(0.12) : (isHoveringNewChat ? Color.primary.opacity(0.05) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isNewChatActive ? Color.primary.opacity(0.08) : Color.clear, lineWidth: 0.5)
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

    // MARK: - Navigation Rows (Activity, Integrations, Skills)

    private var navigationRows: some View {
        VStack(alignment: .leading, spacing: 3) {
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
                symbol: "list.bullet.rectangle",
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
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Chats Section (Recents matching ChatGPT Image 1)

    private var chatsSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Recents")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 4)

            if isSearchVisible || !store.historySearch.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    TextField("Search chats...", text: $store.historySearch)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))

                    if !store.historySearch.isEmpty {
                        Button { store.historySearch = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.horizontal, 4)
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
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
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

    // MARK: - Account Footer (Matching Dean Rabbani in ChatGPT Image 1)

    private var accountFooter: some View {
        HStack(spacing: 10) {
            Button {
                store.activeSurface = .account
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.88, green: 0.48, blue: 0.12))
                        Text(avatarInitials)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("Free")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
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
                    .font(.system(size: 14))
                    .foregroundStyle(store.activeSurface == .settings ? LoflyTheme.accent : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(store.activeSurface == .settings ? LoflyTheme.accent.opacity(0.12) : Color.primary.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
