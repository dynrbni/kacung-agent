import SwiftUI

/// One task with its steps and its cancel action.
///
/// Shared by the Activity screen's live block and anything else that needs to
/// show work in progress, so a running task looks the same wherever it appears.
struct TaskCard: View {
    let task: TaskSnapshot
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: LoflyTheme.Space.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LoflyTheme.primaryText)
                        .lineLimit(2)
                    Text(LoflyDate.relative(milliseconds: task.updatedAt))
                        .font(LoflyTheme.caption(11))
                        .foregroundStyle(LoflyTheme.tertiaryText)
                }
                Spacer(minLength: LoflyTheme.Space.s)
                LoflyStatusPill(
                    text: task.status.title,
                    color: LoflyTheme.color(for: task.status)
                )
                if task.isRunning {
                    Button("Cancel", role: .destructive, action: onCancel)
                        .controlSize(.small)
                        .accessibilityLabel("Cancel \(task.title)")
                }
            }

            if !task.steps.isEmpty {
                LoflySeparator()
                VStack(alignment: .leading, spacing: LoflyTheme.Space.xs) {
                    ForEach(task.steps) { step in
                        HStack(spacing: LoflyTheme.Space.s) {
                            Image(systemName: LoflyTheme.symbol(for: step))
                                .font(.system(size: 12))
                                .foregroundStyle(LoflyTheme.color(for: step))
                                .frame(width: 14)
                            Text(step.label)
                                .font(LoflyTheme.body(13))
                                .foregroundStyle(step.state == .skipped ? LoflyTheme.secondaryText : LoflyTheme.primaryText)
                            Spacer()
                            if let error = step.error, !error.isEmpty {
                                Text(error)
                                    .font(LoflyTheme.caption(11))
                                    .foregroundStyle(Color.red)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(LoflyTheme.Space.m)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.large, style: .continuous)
                .fill(LoflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.large, style: .continuous)
                .stroke(LoflyTheme.borderSubtle, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Task: \(task.title). Status: \(task.status.title). \(task.steps.count) steps.")
    }
}
