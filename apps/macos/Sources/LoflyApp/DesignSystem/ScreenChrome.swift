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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LoflyTheme.primaryText)
            Text(subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(LoflyTheme.secondaryText)
        }
        Spacer()
        trailing()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
}

/// Empty state. It names the cause and, when there is one, the single action
/// that fills it — the difference between a state and a shrug.
func emptyState(
    _ title: String,
    _ message: String,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil
) -> some View {
    VStack(spacing: 8) {
        Spacer()
        Text(title)
            .font(.system(size: 14.5, weight: .semibold))
            .foregroundStyle(LoflyTheme.primaryText)
        Text(message)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(LoflyTheme.secondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 380)
        if let actionTitle, let action {
            Button(actionTitle, action: action)
                .controlSize(.small)
                .padding(.top, 4)
        }
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

/// Loading state. Says what is being loaded rather than showing a bare
/// spinner, so the wait has a subject.
func loadingState(_ message: String) -> some View {
    VStack(spacing: 8) {
        Spacer()
        ProgressView()
            .controlSize(.small)
        Text(message)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(LoflyTheme.secondaryText)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
