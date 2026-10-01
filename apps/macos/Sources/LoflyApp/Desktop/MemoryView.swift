import SwiftUI
import AppKit

/// Memory screen: the user owns what Lofly remembers. Internal reasoning is
/// never shown as memory — only explicit stored items.
///
/// Deliberately not reachable yet: the sidebar shows no Memory row and the
/// feature is marked "Soon" in Settings → Privacy. The screen is kept whole so
/// it can be wired up the day the server side ships, rather than rebuilt then.
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
                subtitle: "What Lofly has been told to remember.",
                trailing: {
                    HStack(spacing: LoflyTheme.Space.s) {
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

            LoflySeparator()

            if store.memory.isEmpty {
                emptyState(
                    "Nothing remembered yet",
                    "Lofly stores facts, preferences and project notes here when asked."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: LoflyTheme.Space.l) {
                        ForEach(grouped, id: \.0) { category, items in
                            VStack(alignment: .leading, spacing: LoflyTheme.Space.s) {
                                LoflySectionHeader(category.title)
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
                    .padding(LoflyTheme.Space.l)
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
        HStack(alignment: .top, spacing: LoflyTheme.Space.m) {
            Image(systemName: item.category.symbol)
                .font(.system(size: LoflyTheme.Size.callout))
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .padding(.top, 1)

            Text(item.content)
                .font(LoflyTheme.body(LoflyTheme.Size.body))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: LoflyTheme.Space.s) {
                Button("Edit", action: onEdit)
                    .controlSize(.small)
                Button("Delete", role: .destructive, action: onDelete)
                    .controlSize(.small)
            }
        }
        .padding(LoflyTheme.Space.m)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                .fill(LoflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                .stroke(LoflyTheme.separator, lineWidth: 0.5)
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
        VStack(alignment: .leading, spacing: LoflyTheme.Space.m) {
            LoflySectionHeader(item.category.title)

            TextEditor(text: $draft)
                .font(LoflyTheme.body(LoflyTheme.Size.body))
                .frame(height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                        .stroke(LoflyTheme.separator, lineWidth: 0.5)
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
        .padding(LoflyTheme.Space.l)
        .frame(width: 420)
    }
}
