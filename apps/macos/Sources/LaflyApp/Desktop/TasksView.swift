import SwiftUI
import AppKit

/// Tasks screen: inspect status and cancel anything still running.
struct TasksView: View {
    @EnvironmentObject private var store: DesktopStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeader(
                title: "Tasks",
                subtitle: "Agent work, newest first.",
                trailing: {
                    Button {
                        store.refreshTasks()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh tasks")
                    .accessibilityLabel("Refresh tasks")
                }
            )

            LaflySeparator()

            if store.tasks.isEmpty {
                emptyState(
                    "No tasks yet",
                    "Run a command from Chats and it will appear here."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: LaflyTheme.Space.m) {
                        ForEach(store.tasks) { task in
                            TaskCard(task: task) { store.cancelActiveTask() }
                        }
                    }
                    .padding(LaflyTheme.Space.l)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .onAppear { store.refreshTasks() }
    }
}

private struct TaskCard: View {
    let task: TaskSnapshot
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LaflyTheme.Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: LaflyTheme.Space.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(LaflyTheme.title(LaflyTheme.Size.sectionTitle))
                        .lineLimit(2)
                    Text(relativeDate)
                        .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: LaflyTheme.Space.s)
                LaflyStatusPill(
                    text: task.status.title,
                    color: LaflyTheme.color(for: task.status)
                )
                if task.isRunning {
                    Button("Cancel", role: .destructive, action: onCancel)
                        .controlSize(.small)
                        .accessibilityLabel("Cancel \(task.title)")
                }
            }

            if !task.steps.isEmpty {
                LaflySeparator()
                VStack(alignment: .leading, spacing: LaflyTheme.Space.xs) {
                    ForEach(task.steps) { step in
                        HStack(spacing: LaflyTheme.Space.s) {
                            Image(systemName: LaflyTheme.symbol(for: step))
                                .font(.system(size: LaflyTheme.Size.callout))
                                .foregroundStyle(LaflyTheme.color(for: step))
                                .frame(width: 14)
                            Text(step.label)
                                .font(LaflyTheme.body(LaflyTheme.Size.callout))
                                .foregroundStyle(step.state == .skipped ? .secondary : .primary)
                            Spacer()
                            if let error = step.error, !error.isEmpty {
                                Text(error)
                                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                                    .foregroundStyle(.red)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding(LaflyTheme.Space.m)
        .background(
            RoundedRectangle(cornerRadius: LaflyTheme.Radius.large, style: .continuous)
                .fill(LaflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LaflyTheme.Radius.large, style: .continuous)
                .stroke(LaflyTheme.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Task: \(task.title). Status: \(task.status.title). \(task.steps.count) steps.")
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(
            for: Date(timeIntervalSince1970: task.updatedAt / 1000),
            relativeTo: Date()
        )
    }
}

/// Shared header used by the secondary screens so they feel like one app.
@ViewBuilder
func screenHeader(
    title: String,
    subtitle: String,
    @ViewBuilder trailing: () -> some View = { EmptyView() }
) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: LaflyTheme.Space.s) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(LaflyTheme.display(LaflyTheme.Size.windowTitle))
            Text(subtitle)
                .font(LaflyTheme.body(LaflyTheme.Size.callout))
                .foregroundStyle(.secondary)
        }
        Spacer()
        trailing()
    }
    .padding(.horizontal, LaflyTheme.Space.l)
    .padding(.vertical, LaflyTheme.Space.m)
}

func emptyState(_ title: String, _ message: String) -> some View {
    VStack(spacing: LaflyTheme.Space.s) {
        Spacer()
        Text(title)
            .font(LaflyTheme.title(LaflyTheme.Size.sectionTitle))
        Text(message)
            .font(LaflyTheme.body(LaflyTheme.Size.callout))
            .foregroundStyle(.secondary)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
