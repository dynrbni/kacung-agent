import SwiftUI

/// Shared header used by the secondary screens so they feel like one app.
@ViewBuilder
func screenHeader(
    title: String,
    subtitle: String,
    @ViewBuilder trailing: () -> some View = { EmptyView() }
) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: LoflyTheme.Space.s) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(LoflyTheme.display(LoflyTheme.Size.windowTitle))
            Text(subtitle)
                .font(LoflyTheme.body(LoflyTheme.Size.callout))
                .foregroundStyle(.secondary)
        }
        Spacer()
        trailing()
    }
    .padding(.horizontal, LoflyTheme.Space.l)
    .padding(.vertical, LoflyTheme.Space.m)
}

/// Empty state. It names the cause and, when there is one, the single action
/// that fills it — the difference between a state and a shrug.
func emptyState(
    _ title: String,
    _ message: String,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil
) -> some View {
    VStack(spacing: LoflyTheme.Space.s) {
        Spacer()
        Text(title)
            .font(LoflyTheme.title(LoflyTheme.Size.sectionTitle))
        Text(message)
            .font(LoflyTheme.body(LoflyTheme.Size.callout))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 380)
        if let actionTitle, let action {
            Button(actionTitle, action: action)
                .controlSize(.small)
                .padding(.top, LoflyTheme.Space.xs)
        }
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

/// Loading state. Says what is being loaded rather than showing a bare
/// spinner, so the wait has a subject.
func loadingState(_ message: String) -> some View {
    VStack(spacing: LoflyTheme.Space.s) {
        Spacer()
        ProgressView()
            .controlSize(.small)
        Text(message)
            .font(LoflyTheme.body(LoflyTheme.Size.callout))
            .foregroundStyle(.secondary)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
