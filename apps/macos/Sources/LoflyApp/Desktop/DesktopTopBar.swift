import SwiftUI
import AppKit

/// Restrained native macOS toolbar:
/// - Compact height (42pt) that visually blends into the window
/// - Traffic lights clearance and navigation controls
/// - Thread tabs allowing rapid switching between conversations
/// - Seamless graphite styling with subtle borders and states
public struct DesktopTopBar: View {
    @EnvironmentObject private var store: DesktopStore

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            if !store.isSidebarVisible {
                // When sidebar is collapsed, traffic lights sit at top-left of this bar
                Spacer()
                    .frame(width: 76)

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
                .help("Open sidebar")
                .accessibilityLabel("Open sidebar")

                navButtons

                Rectangle()
                    .fill(LoflyTheme.separator)
                    .frame(width: 1, height: 14)
                    .padding(.horizontal, 2)
            } else {
                navButtons
                    .padding(.leading, 10)

                Rectangle()
                    .fill(LoflyTheme.separator)
                    .frame(width: 1, height: 14)
                    .padding(.horizontal, 2)
            }

            // Thread Tabs Bar
            threadTabsBar

            Spacer(minLength: 8)
        }
        .frame(height: 42)
        .padding(.horizontal, 8)
        .background(LoflyTheme.contentBackground)
    }

    private var navButtons: some View {
        HStack(spacing: 2) {
            Button(action: { store.goBack() }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.canGoBack ? LoflyTheme.primaryText : LoflyTheme.secondaryText.opacity(0.35))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!store.canGoBack)
            .help("Back")

            Button(action: { store.goForward() }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.canGoForward ? LoflyTheme.primaryText : LoflyTheme.secondaryText.opacity(0.35))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!store.canGoForward)
            .help("Forward")
        }
    }

    // MARK: - Thread Tabs

    @ViewBuilder
    private var threadTabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                if store.openThreadIds.isEmpty && store.selectedConversationId == nil {
                    activeDraftTab
                } else {
                    ForEach(store.openThreadIds, id: \.self) { threadId in
                        threadTab(threadId: threadId)
                    }

                    if store.selectedConversationId == nil {
                        activeDraftTab
                    }
                }

                // Plus / New thread button
                Button(action: { store.newConversation() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LoflyTheme.secondaryText)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                                .fill(LoflyTheme.subtleFill)
                        )
                }
                .buttonStyle(.plain)
                .help("New thread")
                .accessibilityLabel("New thread")
            }
            .padding(.vertical, 3)
        }
    }

    private var activeDraftTab: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkle")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(LoflyTheme.accent)
            Text("New thread")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LoflyTheme.primaryText)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                .fill(LoflyTheme.selectedFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                .stroke(LoflyTheme.borderSubtle, lineWidth: 0.5)
        )
    }

    private func threadTab(threadId: String) -> some View {
        let isSelected = store.selectedConversationId == threadId
        let conv = store.conversations.first(where: { $0.id == threadId })
        let title = conv?.title ?? "Chat"

        return HStack(spacing: 5) {
            Button {
                store.selectConversation(threadId)
            } label: {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? LoflyTheme.primaryText : LoflyTheme.secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: 160)
                    .id("title-\(threadId)-\(title)")
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: title)
            }
            .buttonStyle(.plain)

            Button {
                store.closeThread(threadId)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(isSelected ? LoflyTheme.secondaryText : LoflyTheme.tertiaryText)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help("Close thread")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                .fill(isSelected ? LoflyTheme.selectedFill : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                .stroke(isSelected ? LoflyTheme.borderSubtle : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}
