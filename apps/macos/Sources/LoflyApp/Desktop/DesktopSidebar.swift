import SwiftUI
import AppKit

/// Sidebar: four destinations, then the conversations worth resuming, then who
/// you are. Nothing else.
///
/// Memory and Tasks used to be rows here. Multiple destinations are fine only
/// while each one has a real screen behind it — Memory has none yet (it lives
/// in Settings as a "Soon" state), and Tasks became the live block at the top of
/// Activity, which is the only place a running task can be acted on.
struct DesktopSidebar: View {
    @EnvironmentObject private var store: DesktopStore
    @State private var isHoveringNewChat = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    wordmark
                        .padding(.horizontal, LoflyTheme.Space.m)
                        .padding(.top, 14)
                        .padding(.bottom, LoflyTheme.Space.m)

                    newChatButton
                        .padding(.bottom, 2)

                    navigationRows
                        .padding(.bottom, LoflyTheme.Space.m)

                    chatsSection
                }
                .padding(.horizontal, LoflyTheme.Space.s)
            }

            LoflySeparator()

            accountFooter
                .padding(.horizontal, LoflyTheme.Space.m)
                .padding(.vertical, LoflyTheme.Space.s)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(LoflyTheme.accent)
            Text("Lofly")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
            Button(action: { store.toggleSidebar() }) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Tutup sidebar")
            .accessibilityLabel("Tutup sidebar")
        }
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - New chat

    /// The one solid accent in the sidebar. Everything else earns its colour
    /// from state.
    private var newChatButton: some View {
        Button(action: startNewChat) {
            HStack(spacing: LoflyTheme.Space.s) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: LoflyTheme.Size.callout))
                    .frame(width: 18)
                    .foregroundStyle(store.activeSurface == .chat && store.messages.isEmpty ? LoflyTheme.accent : Color.secondary)
                Text("New chat")
                    .font(LoflyTheme.body(LoflyTheme.Size.body))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer(minLength: LoflyTheme.Space.xs)
            }
            .padding(.horizontal, LoflyTheme.Space.m)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                    .fill(isHoveringNewChat ? LoflyTheme.subtleFill.opacity(0.35) : Color.clear)
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

    // MARK: - Destinations

    private var navigationRows: some View {
        VStack(alignment: .leading, spacing: 1) {
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
                action: { store.activeSurface = .skills }
            )
        }
    }

    /// A running task is the one thing about Activity that is worth noticing
    /// from here, so the row carries the state the Tasks row used to.
    @ViewBuilder
    private var runningTaskDot: some View {
        if let active = store.activeTask, active.isRunning {
            Circle()
                .fill(LoflyTheme.accent)
                .frame(width: 6, height: 6)
                .accessibilityLabel("Task running")
        }
    }

    /// Real count of services that answered their probe. Hidden at zero rather
    /// than showing a decorative "0".
    @ViewBuilder
    private var connectedCount: some View {
        let count = store.integrations.filter { $0.status == .connected }.count
        if count > 0 {
            Text("\(count)")
                .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(count) connected")
        }
    }

    // MARK: - Chats

    private var chatsSection: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.xs) {
            LoflySidebarHeader("Chats")
                .padding(.horizontal, LoflyTheme.Space.m)
                .padding(.bottom, 2)

            LoflySidebarSearchField(text: $store.historySearch)

            if store.conversations.isEmpty {
                emptyHistory
            } else {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(store.conversations) { summary in
                        historyRow(summary)
                    }
                }
            }
        }
    }

    /// Two different empties: nothing here yet, and nothing matched the search.
    /// They read differently because the next action is different.
    private var emptyHistory: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.xs) {
            Text(store.historySearch.isEmpty
                 ? "No chats yet."
                 : "No chats match \"\(store.historySearch)\".")
                .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.historySearch.isEmpty {
                Button("Start a new chat", action: startNewChat)
                    .buttonStyle(.link)
                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
            } else {
                Button("Clear search") { store.historySearch = "" }
                    .buttonStyle(.link)
                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
            }
        }
        .padding(.horizontal, LoflyTheme.Space.m)
        .padding(.vertical, LoflyTheme.Space.s)
    }

    /// Titles only. A timestamp on every row doubles the height of a list you
    /// scan by title, so the date lives in the tooltip and the context menu.
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

    // MARK: - Account footer

    /// Two destinations, same as before: the account row opens the account, the
    /// gear opens Settings.
    private var accountFooter: some View {
        HStack(spacing: LoflyTheme.Space.s) {
            Button {
                store.activeSurface = .account
            } label: {
                HStack(spacing: LoflyTheme.Space.s) {
                    avatar

                    VStack(alignment: .leading, spacing: 1) {
                        Text(accountName)
                            .font(LoflyTheme.label(LoflyTheme.Size.body))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(store.account.signedIn ? "Free plan" : "Local account")
                            .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Account")
            .accessibilityLabel("Account, \(accountName)")

            Spacer(minLength: LoflyTheme.Space.s)

            Button {
                store.activeSurface = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(store.activeSurface == .settings ? LoflyTheme.accent : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                            .fill(store.activeSurface == .settings ? LoflyTheme.accent.opacity(0.14) : LoflyTheme.subtleFill.opacity(0.2))
                    )
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .accessibilityElement(children: .contain)
    }

    private var accountName: String {
        guard store.account.signedIn else { return "Not signed in" }
        let name = store.account.displayName?.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "Signed in" : name
    }

    @ViewBuilder
    private var avatar: some View {
        if initials.isEmpty {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [LoflyTheme.accent.opacity(0.85), LoflyTheme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [LoflyTheme.accent.opacity(0.85), LoflyTheme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(initials)
                    .font(LoflyTheme.label(10))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)
        }
    }

    private var initials: String {
        guard store.account.signedIn else { return "" }
        let name = store.account.displayName?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else { return "" }
        return name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
            .joined()
    }
}
