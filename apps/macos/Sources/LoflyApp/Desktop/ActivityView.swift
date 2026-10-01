import SwiftUI
import AppKit

/// Activity: one place for "what is the agent doing, and what has it done".
///
/// Work in progress sits at the top because that is the only part the user can
/// act on (cancel it). The log below is the record. Tasks used to have its own
/// screen; it lives here now, so the sidebar stays four destinations.
struct ActivityView: View {
    @EnvironmentObject private var store: DesktopStore

    private var runningTasks: [TaskSnapshot] {
        store.tasks.filter { $0.isRunning }
    }

    private var grouped: [(String, [ActivityEntry])] {
        var order: [String] = []
        var buckets: [String: [ActivityEntry]] = [:]

        for entry in store.activity {
            let key = LoflyDate.day(milliseconds: entry.timestamp)
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(entry)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeader(
                title: "Activity",
                subtitle: "What the agent is doing now, and what it already did.",
                trailing: {
                    Button {
                        store.refreshActivity()
                        store.refreshTasks()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh activity")
                    .accessibilityLabel("Refresh activity")
                }
            )

            LoflySeparator()

            if store.activity.isEmpty && runningTasks.isEmpty {
                emptyState(
                    "No activity yet",
                    "Actions the agent performs are listed here as they happen.",
                    actionTitle: "Open chat",
                    action: { store.activeSurface = .chat }
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: LoflyTheme.Space.l) {
                        if !runningTasks.isEmpty {
                            runningSection
                        }
                        if store.activity.isEmpty {
                            Text("Nothing has finished yet.")
                                .font(LoflyTheme.body(LoflyTheme.Size.callout))
                                .foregroundStyle(.secondary)
                        } else {
                            historySection
                        }
                    }
                    .padding(LoflyTheme.Space.l)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .onAppear {
            store.refreshActivity()
            store.refreshTasks()
        }
    }

    // MARK: - Running

    private var runningSection: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.s) {
            LoflySectionHeader("Running now")
            ForEach(runningTasks) { task in
                TaskCard(task: task) { store.cancelTask(task) }
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.l) {
            ForEach(grouped, id: \.0) { day, entries in
                VStack(alignment: .leading, spacing: LoflyTheme.Space.s) {
                    LoflySectionHeader(day)
                    ForEach(entries) { entry in
                        ActivityRow(entry: entry)
                    }
                }
            }
        }
    }
}

private struct ActivityRow: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(alignment: .top, spacing: LoflyTheme.Space.s) {
            Image(systemName: LoflyTheme.symbol(for: entry.status))
                .font(.system(size: LoflyTheme.Size.callout))
                .foregroundStyle(LoflyTheme.color(for: entry.status))
                .frame(width: 14)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: LoflyTheme.Space.s) {
                    Text(entry.label)
                        .font(LoflyTheme.body(LoflyTheme.Size.body))
                    // A dry run gets its own badge so it is never read as done.
                    if entry.dryRun {
                        LoflyStatusPill(text: "Dry Run", color: .orange, symbol: "shield.lefthalf.filled")
                    }
                }
                if let detail = entry.detail, !detail.isEmpty {
                    Text(detail)
                        .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: LoflyTheme.Space.s)

            Text(LoflyDate.clock(milliseconds: entry.timestamp))
                .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, LoflyTheme.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.label), \(entry.status.title)\(entry.dryRun ? ", dry run" : "")")
    }
}
