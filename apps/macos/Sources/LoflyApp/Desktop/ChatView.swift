import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Chat is the primary desktop surface:
/// - Minimal, elegant, calm native macOS interface
/// - Tonal dark graphite layers (#181818 content, #202020 composer, #1E1E1E surfaces)
/// - Time-aware personal greeting with subtle quick suggestions
/// - Tactile elevated composer with attachment, model, and voice controls
/// - Pure editorial transcript with readable typography and real-time streaming
struct ChatView: View {
    @EnvironmentObject private var store: DesktopStore
    @FocusState private var composerFocused: Bool
    @State private var isRecordingAudio = false

    private var isEmptyState: Bool {
        store.messages.isEmpty && store.voiceSession == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if isEmptyState {
                emptyHeroView
            } else {
                transcript
                bottomComposerContainer
            }
        }
        .background(LoflyTheme.contentBackground)
        .onAppear {
            composerFocused = true
            setupDictationListener()
        }
    }

    private func setupDictationListener() {
        SpeechRecognizer.shared.onDictationCompleted = { transcript in
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if store.composerText.isEmpty {
                store.composerText = trimmed
            } else {
                store.composerText += " " + trimmed
            }
            self.isRecordingAudio = false
            self.composerFocused = true
        }
    }

    // MARK: - Empty Hero State

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning." }
        if hour < 17 { return "Good afternoon." }
        return "Good evening."
    }

    private var emptyHeroView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Personal & subtle greeting
                VStack(spacing: 6) {
                    Text(greetingTitle)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(LoflyTheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text("What would you like to get done?")
                        .font(.system(size: 15.5, weight: .regular))
                        .foregroundStyle(LoflyTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 6)

                // Elevated graphite composer
                floatingComposerBox
                    .frame(maxWidth: 680)

                // 4 Subtle quick suggestions
                suggestionChips
                    .frame(maxWidth: 680)
            }
            .padding(.horizontal, 36)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var suggestionChips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                suggestionChip(title: "Explain something", icon: "sparkles")
                suggestionChip(title: "Plan something", icon: "calendar.badge.clock")
                suggestionChip(title: "Write something", icon: "text.alignleft")
                suggestionChip(title: "Get something done", icon: "terminal")
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                suggestionChip(title: "Explain something", icon: "sparkles", expand: true)
                suggestionChip(title: "Plan something", icon: "calendar.badge.clock", expand: true)
                suggestionChip(title: "Write something", icon: "text.alignleft", expand: true)
                suggestionChip(title: "Get something done", icon: "terminal", expand: true)
            }
        }
    }

    private func suggestionChip(title: String, icon: String, expand: Bool = false) -> some View {
        Button {
            store.composerText = title
            submit()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(LoflyTheme.secondaryText)
                Text(title)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(LoflyTheme.primaryText.opacity(0.92))
            }
            .frame(maxWidth: expand ? .infinity : nil)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LoflyTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(LoflyTheme.borderSubtle, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Floating Composer Capsule

    private var floatingComposerBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isRecordingAudio {
                // Waveform Audio Recording Bar
                HStack(spacing: 12) {
                    plusAttachmentButton
                        .opacity(0.3)
                        .disabled(true)

                    AudioWaveformBarView()
                        .frame(maxWidth: .infinity)

                    Button(action: cancelVoiceRecording) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LoflyTheme.secondaryText)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(LoflyTheme.subtleFill)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Cancel recording")
                    .accessibilityLabel("Cancel recording")

                    Button(action: confirmVoiceRecording) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LoflyTheme.windowBackground)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(LoflyTheme.primaryText)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Done & insert text")
                    .accessibilityLabel("Done & insert text")
                }
                .frame(minHeight: 38)
                .padding(.horizontal, 4)
            } else {
                // 1. Attachment chips preview
                if !store.attachments.isEmpty {
                    attachmentChipsBar
                }

                // 2. Text input area
                TextField("Ask Lofly anything...", text: $store.composerText, axis: .vertical)
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(LoflyTheme.primaryText)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .focused($composerFocused)
                    .onSubmit {
                        submit()
                    }
                    .onKeyPress(.return) {
                        if NSEvent.modifierFlags.contains(.shift) {
                            store.composerText.append("\n")
                            return .handled
                        }
                        submit()
                        return .handled
                    }
                    .frame(minHeight: 28)
                    .accessibilityLabel("Ask Lofly anything")

                // 3. Bottom action controls row
                HStack(spacing: 8) {
                    plusAttachmentButton

                    modelSelectorMenu

                    Spacer()

                    // Voice STT button
                    Button(action: startInAppVoiceRecording) {
                        Image(systemName: "mic")
                            .font(.system(size: 13))
                            .foregroundStyle(LoflyTheme.secondaryText)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Speech to text")
                    .accessibilityLabel("Speech to text")

                    // Send or Stop button
                    if store.isStreaming || store.isSending || store.activeTask != nil {
                        Button {
                            if store.isStreaming || store.isSending {
                                store.stopStreaming()
                            } else {
                                store.cancelActiveTask()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(LoflyTheme.primaryText)
                                    .frame(width: 28, height: 28)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LoflyTheme.windowBackground)
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Stop generating")
                        .accessibilityLabel("Stop generating")
                    } else {
                        let canSend = !store.isSending && (!store.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.attachments.isEmpty)
                        Button(action: submit) {
                            ZStack {
                                Circle()
                                    .fill(canSend ? LoflyTheme.primaryText : LoflyTheme.subtleFill)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(canSend ? LoflyTheme.windowBackground : LoflyTheme.tertiaryText)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSend)
                        .help("Send message")
                        .accessibilityLabel("Send message")
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.composer, style: .continuous)
                .fill(LoflyTheme.composerBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.composer, style: .continuous)
                .stroke(composerFocused ? LoflyTheme.accent.opacity(0.35) : LoflyTheme.borderMedium, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 4)
    }

    // MARK: - Attachments Components & Plus Menu

    private var plusAttachmentButton: some View {
        Menu {
            Button {
                pickFiles(forImages: true)
            } label: {
                Label("Add Photos or Images", systemImage: "photo.on.rectangle")
            }

            Button {
                pickFiles(forImages: false)
            } label: {
                Label("Add Files or Documents", systemImage: "doc.text")
            }

            Divider()

            Button {
                store.activeSurface = .skills
            } label: {
                Label("Manage Tools & Skills", systemImage: "slider.horizontal.3")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LoflyTheme.secondaryText)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(LoflyTheme.subtleFill)
                )
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Attach images or files")
    }

    private var attachmentChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.attachments) { att in
                    HStack(spacing: 6) {
                        Image(systemName: att.isImage ? "photo.fill" : "doc.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(att.isImage ? Color.blue : Color.orange)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(att.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(LoflyTheme.primaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if !att.fileSize.isEmpty {
                                Text(att.fileSize)
                                    .font(.system(size: 9))
                                    .foregroundStyle(LoflyTheme.secondaryText)
                            }
                        }
                        .frame(maxWidth: 120, alignment: .leading)

                        Button {
                            store.removeAttachment(id: att.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(LoflyTheme.tertiaryText)
                        }
                        .buttonStyle(.plain)
                        .help("Remove attachment")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LoflyTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(LoflyTheme.borderSubtle, lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)
        }
    }

    private func pickFiles(forImages: Bool) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true

        if forImages {
            var imageTypes: [UTType] = [.image, .png, .jpeg, .gif]
            if let webp = UTType(filenameExtension: "webp") { imageTypes.append(webp) }
            if let heic = UTType(filenameExtension: "heic") { imageTypes.append(heic) }
            panel.allowedContentTypes = imageTypes
            panel.message = "Choose image to attach"
        } else {
            panel.allowedContentTypes = [.item, .content, .data, .pdf, .text, .plainText]
            panel.message = "Choose document to attach"
        }

        if panel.runModal() == .OK {
            for url in panel.urls {
                store.addAttachment(url: url)
            }
        }
    }

    // MARK: - Model & Reasoning Selector

    private var modelSelectorMenu: some View {
        Menu {
            Section("Model") {
                Button {} label: {
                    HStack {
                        Text("Gemini 3.8 Flash")
                        Image(systemName: "checkmark")
                    }
                }
            }

            Section("Reasoning Effort") {
                Button {
                    store.reasoningLevel = "low"
                } label: {
                    HStack {
                        Text("Low (Fastest)")
                        if store.reasoningLevel == "low" {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    store.reasoningLevel = "medium"
                } label: {
                    HStack {
                        Text("Medium (Balanced)")
                        if store.reasoningLevel == "medium" {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    store.reasoningLevel = "high"
                } label: {
                    HStack {
                        Text("High (Deep Thinking)")
                        if store.reasoningLevel == "high" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkle")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(LoflyTheme.accent)
                Text("Gemini 3.8 Flash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LoflyTheme.primaryText)
                Text("· \(store.reasoningLevel.capitalized)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(LoflyTheme.tertiaryText)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(LoflyTheme.tertiaryText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LoflyTheme.subtleFill)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Select model and reasoning effort")
    }

    // MARK: - Voice STT Handlers

    private func startInAppVoiceRecording() {
        isRecordingAudio = true
        SpeechRecognizer.shared.isInAppDictation = true
        SpeechRecognizer.shared.startListening()
    }

    private func confirmVoiceRecording() {
        SpeechRecognizer.shared.stopListening()
        let transcript = SpeechRecognizer.shared.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcript.isEmpty {
            if store.composerText.isEmpty {
                store.composerText = transcript
            } else {
                store.composerText += " " + transcript
            }
        }
        SpeechRecognizer.shared.isInAppDictation = false
        isRecordingAudio = false
        composerFocused = true
    }

    private func cancelVoiceRecording() {
        SpeechRecognizer.shared.cancelListening()
        SpeechRecognizer.shared.isInAppDictation = false
        isRecordingAudio = false
        composerFocused = true
    }

    // MARK: - Transcript (Active Conversation)

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(store.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }

                    // Push-to-talk capture while the desktop is open
                    if let session = store.voiceSession {
                        VoiceSessionCard(session: session)
                            .id("voice-session")
                    }

                    // Live progress for the in-flight task
                    if let task = store.activeTask {
                        TaskStrip(task: task)
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 16)
                .frame(maxWidth: LoflyTheme.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .onChange(of: store.scrollTrigger) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: store.voiceSession?.transcript) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Bottom Composer Container (Docked when chatting)

    private var bottomComposerContainer: some View {
        VStack(spacing: 6) {
            floatingComposerBox
                .frame(maxWidth: LoflyTheme.contentMaxWidth)

            Text("Lofly can make mistakes. Verify important info.")
                .font(.system(size: 10.5))
                .foregroundStyle(LoflyTheme.tertiaryText)
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 10)
        .padding(.top, 4)
        .background(LoflyTheme.contentBackground)
    }

    private func submit() {
        let trimmed = store.composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.send()
        composerFocused = true
    }
}

// MARK: - Message Row (Clean Editorial Assistant + Minimal User Bubble)

struct MessageRow: View {
    @EnvironmentObject private var store: DesktopStore
    let message: ConversationMessage
    @State private var isHovering = false
    @State private var didCopy = false

    private var isMessageStreaming: Bool {
        store.isStreaming && store.activeStreamingMessageId == message.id
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 64)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                if message.role == .assistant && message.text.isEmpty {
                    if store.activeTask == nil {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking...")
                                .font(LoflyTheme.body(13))
                                .foregroundStyle(LoflyTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                } else if message.role == .assistant {
                    // Assistant response: rendered as pure editorial text with rich markdown
                    RichMarkdownView(text: message.text, isStreaming: isMessageStreaming)
                        .contentShape(Rectangle())

                    // Quiet action bar below AI output
                    if !isMessageStreaming && !message.text.isEmpty {
                        assistantActionBar
                    }
                } else {
                    // User message bubble: minimal, calm, graphite elevated surface
                    Text(MarkdownParser.inlineAttributedString(message.text))
                        .font(.system(size: 14.5, weight: .regular))
                        .lineSpacing(4.5)
                        .foregroundStyle(LoflyTheme.primaryText)
                        .textSelection(.enabled)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LoflyTheme.userBubbleBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(LoflyTheme.userBubbleBorder, lineWidth: 0.5)
                                )
                        )
                }

                if let error = message.error, !error.isEmpty {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(LoflyTheme.caption(11))
                        .foregroundStyle(Color.orange)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: message.role == .user ? 540 : .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role != .user {
                Spacer(minLength: 32)
            }
        }
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "You" : "Assistant") said: \(message.text)")
    }

    // MARK: - Action Toolbar (Copy, Thumbs Up / Down Rate Response, Regenerate)

    private var assistantActionBar: some View {
        let currentRating = store.messageRatings[message.id]

        return HStack(spacing: 4) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.text, forType: .string)
                didCopy = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    didCopy = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                    if didCopy {
                        Text("Copied")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                }
                .foregroundStyle(didCopy ? LoflyTheme.accent : LoflyTheme.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(didCopy ? LoflyTheme.accent.opacity(0.12) : (isHovering ? LoflyTheme.subtleFill : Color.clear))
                )
            }
            .buttonStyle(.plain)
            .help(didCopy ? "Copied" : "Copy text")

            Button {
                store.toggleRating(for: message.id, rating: .thumbsUp)
            } label: {
                Image(systemName: currentRating == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 11))
                    .foregroundStyle(currentRating == .thumbsUp ? LoflyTheme.accent : LoflyTheme.secondaryText)
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(currentRating == .thumbsUp ? LoflyTheme.accent.opacity(0.12) : (isHovering ? LoflyTheme.subtleFill : Color.clear))
                    )
            }
            .buttonStyle(.plain)
            .help("Good response")

            Button {
                store.toggleRating(for: message.id, rating: .thumbsDown)
            } label: {
                Image(systemName: currentRating == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 11))
                    .foregroundStyle(currentRating == .thumbsDown ? Color.orange : LoflyTheme.secondaryText)
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(currentRating == .thumbsDown ? Color.orange.opacity(0.12) : (isHovering ? LoflyTheme.subtleFill : Color.clear))
                    )
            }
            .buttonStyle(.plain)
            .help("Poor response")

            Button {
                store.send()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(LoflyTheme.secondaryText)
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isHovering ? LoflyTheme.subtleFill : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Regenerate response")

            Spacer()
        }
        .padding(.top, 4)
        .opacity(isHovering || didCopy || currentRating != nil ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Voice Session Card

struct VoiceSessionCard: View {
    @EnvironmentObject private var store: DesktopStore
    let session: VoiceSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(session.isRunning ? Color.red : LoflyTheme.secondaryText)
                Text(session.isRunning ? "Voice session" : "Voice")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LoflyTheme.tertiaryText)
                    .textCase(.uppercase)
                if !session.isRunning {
                    Spacer(minLength: 4)
                    Button {
                        store.dismissVoiceSession()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                            .foregroundStyle(LoflyTheme.secondaryText)
                    }
                    .buttonStyle(.borderless)
                    .help("Dismiss")
                }
            }

            if !session.transcript.isEmpty {
                Text(session.transcript)
                    .font(.system(size: 14))
                    .foregroundStyle(LoflyTheme.primaryText)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if session.isRunning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Listening…")
                        .font(.system(size: 11))
                        .foregroundStyle(LoflyTheme.secondaryText)
                }
            }

            if let response = session.responseText {
                RichMarkdownView(text: response)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                            .fill(LoflyTheme.surface)
                    )
            }

            if let error = session.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                .fill(LoflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                .stroke(LoflyTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - Task Strip (Boxless Live Status)

struct TaskStrip: View {
    let task: TaskSnapshot

    private var statusText: String {
        let isSearching = task.steps.contains { step in
            let tool = (step.toolName ?? "").lowercased()
            let label = step.label.lowercased()
            return tool.contains("search") || tool.contains("google") || label.contains("search") || label.contains("google") || label.contains("mencari")
        } || task.title.lowercased().contains("google") || task.title.lowercased().contains("search")

        if isSearching {
            return "Searching Google..."
        }
        return "Thinking..."
    }

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(statusText)
                .font(.system(size: 13))
                .foregroundStyle(LoflyTheme.secondaryText)
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
    }
}
