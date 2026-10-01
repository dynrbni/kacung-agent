import SwiftUI
import AppKit

/// Unified top bar matching ChatGPT macOS / Lofly companion:
/// - Leading traffic lights clearance (~78pt)
/// - Navigation controls (Back ← and Forward →)
/// - Sidebar toggle button ([|]) to collapse / expand the sidebar
/// - Thread tabs allowing rapid switching between recent conversations
/// - Animated titles when AI generates or updates conversation titles
/// - "+" / "New thread" button to start a fresh draft
public struct DesktopTopBar: View {
    @EnvironmentObject private var store: DesktopStore

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            if !store.isSidebarVisible {
                // When sidebar is collapsed, traffic lights sit at top-left of this bar
                Spacer()
                    .frame(width: 76)

                navButtons

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
                .help("Buka sidebar")
                .accessibilityLabel("Open sidebar")

                Rectangle()
                    .fill(LoflyTheme.separator.opacity(0.6))
                    .frame(width: 1, height: 16)
                    .padding(.horizontal, 2)
            } else {
                // When sidebar is visible, traffic lights sit in the sidebar header
                navButtons
                    .padding(.leading, 12)

                Rectangle()
                    .fill(LoflyTheme.separator.opacity(0.6))
                    .frame(width: 1, height: 16)
                    .padding(.horizontal, 2)
            }

            // Thread Tabs Bar
            threadTabsBar

            Spacer(minLength: 8)
        }
        .frame(height: 48)
        .padding(.horizontal, 8)
        .background(LoflyTheme.surface)
    }

    private var navButtons: some View {
        HStack(spacing: 2) {
            Button(action: { store.goBack() }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(store.canGoBack ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!store.canGoBack)
            .help("Back")

            Button(action: { store.goForward() }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(store.canGoForward ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: 26, height: 26)
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
            HStack(spacing: 6) {
                if store.openThreadIds.isEmpty && store.selectedConversationId == nil {
                    // Draft / New chat tab
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                }
                .buttonStyle(.plain)
                .help("New thread")
                .accessibilityLabel("New thread")
            }
            .padding(.vertical, 4)
        }
    }

    private var activeDraftTab: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LoflyTheme.accent)
            Text("New thread")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func threadTab(threadId: String) -> some View {
        let isSelected = store.selectedConversationId == threadId
        let conv = store.conversations.first(where: { $0.id == threadId })
        let title = conv?.title ?? "Chat"

        return HStack(spacing: 6) {
            Button {
                store.selectConversation(threadId)
            } label: {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 160)
                    .id("title-\(threadId)-\(title)")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.94)).combined(with: .offset(y: 1)),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: title)
            }
            .buttonStyle(.plain)

            Button {
                store.closeThread(threadId)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isSelected ? Color.secondary : Color.secondary.opacity(0.6))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help("Close thread")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isSelected ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}
