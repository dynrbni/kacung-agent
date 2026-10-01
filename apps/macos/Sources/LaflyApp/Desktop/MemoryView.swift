import SwiftUI
import AppKit

/// Memory screen: the user owns what Lafly remembers. Internal reasoning is
/// never shown as memory — only explicit stored items.
struct MemoryView: View {
    @EnvironmentObject private var store: DesktopStore
    @State private var editing: MemoryItem?
    @State private var draft = ""
    @State private var confirmingClearAll = false

    private var grouped: [(MemoryCategory, [MemoryItem])] {
        MemoryCategory.allCases.compactMap { category in
            let items = store.memory.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeader(
                title: "Memory",
                subtitle: "What Lafly has been told to remember.",
                trailing: {
                    HStack(spacing: LaflyTheme.Space.s) {
                        Button {
                            store.refreshMemory()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Refresh memory")
                        .accessibilityLabel("Refresh memory")

                        if !store.memory.isEmpty {
                            Button("Forget all", role: .destructive) {
                                confirmingClearAll = true
                            }
                            .controlSize(.small)
                        }
                    }
                }
            )

            LaflySeparator()

            if store.memory.isEmpty {
                emptyState(
                    "Nothing remembered yet",
                    "Lafly stores facts, preferences and project notes here when asked."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: LaflyTheme.Space.l) {
                        ForEach(grouped, id: \.0) { category, items in
                            VStack(alignment: .leading, spacing: LaflyTheme.Space.s) {
                                LaflySectionHeader(category.title)
                                ForEach(items) { item in
                                    MemoryRow(
                                        item: item,
                                        onEdit: {
                                            editing = item
                                            draft = item.content
                                        },
                                        onDelete: { store.deleteMemory(item) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(LaflyTheme.Space.l)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .onAppear { store.refreshMemory() }
        .sheet(item: $editing) { item in
            MemoryEditSheet(item: item, draft: $draft) { newValue in
                store.updateMemory(item, content: newValue)
            }
        }
        .alert("Forget everything?", isPresented: $confirmingClearAll) {
            Button("Cancel", role: .cancel) {}
            Button("Forget All", role: .destructive) { store.clearAllMemory() }
        } message: {
            Text("This deletes every stored memory item. It cannot be undone.")
        }
    }
}

private struct MemoryRow: View {
    let item: MemoryItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: LaflyTheme.Space.m) {
            Image(systemName: item.category.symbol)
                .font(.system(size: LaflyTheme.Size.callout))
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .padding(.top, 1)

            Text(item.content)
                .font(LaflyTheme.body(LaflyTheme.Size.body))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: LaflyTheme.Space.s) {
                Button("Edit", action: onEdit)
                    .controlSize(.small)
                Button("Delete", role: .destructive, action: onDelete)
                    .controlSize(.small)
            }
        }
        .padding(LaflyTheme.Space.m)
        .background(
            RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                .fill(LaflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                .stroke(LaflyTheme.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.category.title): \(item.content)")
    }
}

private struct MemoryEditSheet: View {
    let item: MemoryItem
    @Binding var draft: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: LaflyTheme.Space.m) {
            LaflySectionHeader(item.category.title)

            TextEditor(text: $draft)
                .font(LaflyTheme.body(LaflyTheme.Size.body))
                .frame(height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                        .stroke(LaflyTheme.separator, lineWidth: 0.5)
                )
                .accessibilityLabel("Memory content")

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(LaflyTheme.Space.l)
        .frame(width: 420)
    }
}

/// Activity screen: a concise record of what the agent did, grouped by day.
/// Simulated actions are labelled as such so a dry run is never mistaken for a
/// real one.
struct ActivityView: View {
    @EnvironmentObject private var store: DesktopStore

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }()

    private var grouped: [(String, [ActivityEntry])] {
        var order: [String] = []
        var buckets: [String: [ActivityEntry]] = [:]

        for entry in store.activity {
            let key = Self.dayFormatter.string(from: Date(timeIntervalSince1970: entry.timestamp / 1000))
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
                subtitle: "Recent actions the agent performed.",
                trailing: {
                    Button {
                        store.refreshActivity()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh activity")
                    .accessibilityLabel("Refresh activity")
                }
            )

            LaflySeparator()

            if store.activity.isEmpty {
                emptyState("No activity yet", "Agent actions will be listed here as they happen.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: LaflyTheme.Space.l) {
                        ForEach(grouped, id: \.0) { day, entries in
                            VStack(alignment: .leading, spacing: LaflyTheme.Space.s) {
                                LaflySectionHeader(day)
                                ForEach(entries) { entry in
                                    ActivityRow(entry: entry)
                                }
                            }
                        }
                    }
                    .padding(LaflyTheme.Space.l)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .onAppear { store.refreshActivity() }
    }
}

private struct ActivityRow: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(alignment: .top, spacing: LaflyTheme.Space.s) {
            Image(systemName: LaflyTheme.symbol(for: entry.status))
                .font(.system(size: LaflyTheme.Size.callout))
                .foregroundStyle(LaflyTheme.color(for: entry.status))
                .frame(width: 14)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: LaflyTheme.Space.s) {
                    Text(entry.label)
                        .font(LaflyTheme.body(LaflyTheme.Size.body))
                    // A dry run gets its own badge so it is never read as done.
                    if entry.dryRun {
                        LaflyStatusPill(text: "Dry Run", color: .orange, symbol: "shield.lefthalf.filled")
                    }
                }
                if let detail = entry.detail, !detail.isEmpty {
                    Text(detail)
                        .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: LaflyTheme.Space.s)

            Text(timeFormatter.string(from: Date(timeIntervalSince1970: entry.timestamp / 1000)))
                .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, LaflyTheme.Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.label), \(entry.status.title)\(entry.dryRun ? ", dry run" : "")")
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}
