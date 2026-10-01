import SwiftUI

/// Inline banner for recoverable errors. Never a modal: the app stays usable.
struct LoflyBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: LoflyTheme.Space.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(LoflyTheme.body(LoflyTheme.Size.callout))
                .lineLimit(2)
            Spacer(minLength: LoflyTheme.Space.s)
            Button("Dismiss", action: onDismiss)
                .buttonStyle(.borderless)
                .font(LoflyTheme.label(LoflyTheme.Size.caption))
        }
        .padding(.horizontal, LoflyTheme.Space.m)
        .padding(.vertical, LoflyTheme.Space.s)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                .fill(LoflyTheme.surface)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                .stroke(LoflyTheme.separator, lineWidth: 0.5)
        )
        .padding(.horizontal, LoflyTheme.Space.l)
    }
}
