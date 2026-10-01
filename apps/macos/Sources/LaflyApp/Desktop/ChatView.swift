import SwiftUI
import AppKit

/// Chat is the primary desktop screen. Messages, agent progress, and the
/// composer all read from the shared `DesktopStore`, which is a view over the
/// same runtime the notch drives.
struct ChatView: View {
    @EnvironmentObject private var store: DesktopStore
    @State private var showConversationList = true
    @FocusState private var composerFocused: Bool

    var body: some View {
        HSplitView {
            if showConversationList {
                conversationList
                    .frame(minWidth: 210, idealWidth: 240, maxWidth: 300)
            }

            VStack(spacing: 0) {
                header
                LaflySeparator()
                transcript
                LaflySeparator()
                composer
            }
            .frame(minWidth: 420)
        }
        .onAppear { composerFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: LaflyTheme.Space.s) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { showConversationList.toggle() }
            } label: {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: LaflyTheme.Size.body))
            }
            .buttonStyle(.borderless)
            .help(showConversationList ? "Hide conversations" : "Show conversations")
            .accessibilityLabel(showConversationList ? "Hide conversations" : "Show conversations")

            // The agent's live state is the same value the notch displays.
            LaflyStatusPill(
                text: store.agentState.title,
                color: store.agentState == .error ? .red : LaflyTheme.accent,
                symbol: agentSymbol
            )

            Spacer()

            if store.isSending {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Waiting for the agent")
            }
        }
        .padding(.horizontal, LaflyTheme.Space.m)
        .padding(.vertical, LaflyTheme.Space.s)
    }

    private var agentSymbol: String {
        switch store.agentState {
        case .idle: return "sparkles"
        case .listening: return "mic.fill"
        case .thinking: return "ellipsis.bubble"
        case .executing: return "gearshape.2.fill"
        case .speaking: return "speaker.wave.2.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    // MARK: - Conversation list

    private var conversationList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    store.newConversation()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                        .font(LaflyTheme.label(LaflyTheme.Size.caption))
                }
                .buttonStyle(.borderless)
                .help("Start a new conversation")
                Spacer()
            }
            .padding(.horizontal, LaflyTheme.Space.m)
            .padding(.vertical, LaflyTheme.Space.s)

            LaflySeparator()

            if store.conversations.isEmpty {
                VStack(spacing: LaflyTheme.Space.s) {
                    Spacer()
                    Text("No conversations yet")
                        .font(LaflyTheme.body(LaflyTheme.Size.callout))
                        .foregroundStyle(.secondary)
                    Button("Start one") { store.newConversation() }
                        .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(store.conversations) { summary in
                            conversationRow(summary)
                        }
                    }
                    .padding(.vertical, LaflyTheme.Space.xs)
                }
            }
        }
        .background(LaflyTheme.surface)
    }

    private func conversationRow(_ summary: ConversationSummary) -> some View {
        let isSelected = store.selectedConversationId == summary.id

        return Button {
            store.selectConversation(summary.id)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .font(LaflyTheme.body(LaflyTheme.Size.callout).weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text(relativeDate(summary.updatedAt))
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, LaflyTheme.Space.m)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: LaflyTheme.Radius.small, style: .continuous)
                    .fill(isSelected ? LaflyTheme.accent.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename…") {
                let alert = NSAlert()
                alert.messageText = "Rename conversation"
                let field = NSTextField(string: summary.title)
                alert.accessoryView = field
                alert.addButton(withTitle: "Rename")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                    store.renameConversation(summary.id, to: field.stringValue)
                }
            }
            Button("Delete", role: .destructive) {
                store.deleteConversation(summary.id)
            }
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: LaflyTheme.Space.m) {
                    if store.messages.isEmpty {
                        emptyState
                    }

                    ForEach(store.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }

                    // Live progress for the in-flight task, not a spinner alone.
                    if let task = store.activeTask {
                        TaskStrip(task: task)
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, LaflyTheme.Space.l)
                .padding(.vertical, LaflyTheme.Space.m)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .onChange(of: store.scrollTrigger) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: LaflyTheme.Space.m) {
            LaflySectionHeader("Ask Lafly")
            Text("Talk to the same agent that answers your voice commands.")
                .font(LaflyTheme.body(LaflyTheme.Size.body))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: LaflyTheme.Space.xs) {
                exampleRow("Set volume to 40.")
                exampleRow("WhatsApp Reja Agung bilang Yuli bubur.")
                exampleRow("Analyze this project and help me fix the build.")
            }
            .padding(.top, LaflyTheme.Space.xs)
        }
        .padding(.vertical, LaflyTheme.Space.xl)
    }

    private func exampleRow(_ text: String) -> some View {
        Button {
            store.composerText = text
        } label: {
            Text(text)
                .font(LaflyTheme.body(LaflyTheme.Size.callout))
                .foregroundStyle(.primary)
                .padding(.horizontal, LaflyTheme.Space.m)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                        .fill(LaflyTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                        .stroke(LaflyTheme.separator, lineWidth: 0.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: LaflyTheme.Space.s) {
            // Live transcript from the shared speech pipeline, so pressing
            // Control + Option here fills the same input the notch uses.
            if !store.liveTranscript.isEmpty && store.agentState == .listening {
                HStack(spacing: LaflyTheme.Space.s) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: LaflyTheme.Size.caption))
                        .foregroundStyle(.red)
                    Text(store.liveTranscript)
                        .font(LaflyTheme.body(LaflyTheme.Size.callout))
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, LaflyTheme.Space.m)
                .padding(.vertical, LaflyTheme.Space.xs)
                .background(
                    RoundedRectangle(cornerRadius: LaflyTheme.Radius.small, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )
            }

            HStack(alignment: .bottom, spacing: LaflyTheme.Space.s) {
                TextEditor(text: $store.composerText)
                    .font(LaflyTheme.body(LaflyTheme.Size.body))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 34, maxHeight: 120)
                    .focused($composerFocused)
                    .onSubmit { submit() }
                    .accessibilityLabel("Message Lafly")
                    .overlay(alignment: .topLeading) {
                        if store.composerText.isEmpty {
                            Text("Ask Lafly anything…")
                                .font(LaflyTheme.body(LaflyTheme.Size.body))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 6)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    // Same push-to-talk path as the hotkey; no second voice system.
                    AppState.shared.handleHotkeyPress()
                } label: {
                    Image(systemName: store.agentState == .listening ? "waveform" : "mic")
                        .font(.system(size: LaflyTheme.Size.body))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .help("Push to talk (Control + Option)")
                .accessibilityLabel("Push to talk")

                if store.activeTask != nil {
                    Button {
                        store.cancelActiveTask()
                    } label: {
                        Image(systemName: "stop.circle")
                            .font(.system(size: LaflyTheme.Size.body))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .help("Cancel the running task")
                    .accessibilityLabel("Cancel the running task")
                } else {
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: LaflyTheme.Size.body))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .disabled(store.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Send")
                    .accessibilityLabel("Send message")
                }
            }
            .padding(.horizontal, LaflyTheme.Space.m)
            .padding(.bottom, LaflyTheme.Space.s)
        }
        .padding(.top, LaflyTheme.Space.s)
        .background(LaflyTheme.surface)
    }

    private func submit() {
        store.send()
        composerFocused = true
    }

    private func relativeDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// One transcript bubble. Assistant text is selectable; user text is not, which
/// matches how a terminal-style agent log reads.
struct MessageRow: View {
    let message: ConversationMessage

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: LaflyTheme.Space.xs) {
            LaflySectionHeader(message.role == .user ? "You" : "Lafly")

            Text(message.text)
                .font(LaflyTheme.body(LaflyTheme.Size.body))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .padding(.horizontal, LaflyTheme.Space.m)
                .padding(.vertical, LaflyTheme.Space.s)
                .background(
                    RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                        .fill(message.role == .user ? LaflyTheme.accent.opacity(0.12) : LaflyTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                        .stroke(LaflyTheme.separator, lineWidth: 0.5)
                )

            if let error = message.error, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "You" : "Lafly") said: \(message.text)")
    }
}

/// Compact live progress for the running task.
struct TaskStrip: View {
    let task: TaskSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: LaflyTheme.Space.xs) {
            HStack(spacing: LaflyTheme.Space.s) {
                ProgressView()
                    .controlSize(.small)
                LaflySectionHeader(task.title)
                Spacer()
                Text(task.status.title)
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
            }

            ForEach(task.steps) { step in
                HStack(spacing: LaflyTheme.Space.s) {
                    Image(systemName: LaflyTheme.symbol(for: step))
                        .font(.system(size: LaflyTheme.Size.caption))
                        .foregroundStyle(LaflyTheme.color(for: step))
                    Text(step.label)
                        .font(LaflyTheme.body(LaflyTheme.Size.callout))
                    if let error = step.error {
                        Text(error)
                            .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                    Spacer()
                }
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
        .accessibilityLabel("Current task: \(task.title), \(task.status.title)")
    }
}
