import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Chat is the primary desktop surface. Modeled after the modern ChatGPT interface:
/// - Clean borderless canvas with top bar completely blank
/// - Centered hero empty state with "What can I help with ?", floating input capsule, and suggestion chips
/// - Centered transcript stream with polished user bubbles and assistant responses
/// - Floating bottom composer docked at the bottom center with model selector, tools, and attachments
struct ChatView: View {
    @EnvironmentObject private var store: DesktopStore
    @FocusState private var composerFocused: Bool
    @State private var isRecordingAudio = false

    private var isEmptyState: Bool {
        store.messages.isEmpty && store.voiceSession == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top is completely empty as requested
            if isEmptyState {
                emptyHeroView
            } else {
                transcript
                bottomComposerContainer
            }
        }
        .padding(.top, 10)
        .background(Color(nsColor: .textBackgroundColor))
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

    private var selectedConversation: ConversationSummary? {
        store.conversations.first { $0.id == store.selectedConversationId }
    }

    // MARK: - Empty Hero State (What can I help with ?)

    private var emptyHeroView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("What can I help with ?")
                    .font(.system(size: 32, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                floatingComposerBox
                    .frame(maxWidth: 680)

                suggestionChips
                    .frame(maxWidth: 680)
            }
            .padding(.horizontal, 48)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var suggestionChips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: LoflyTheme.Space.s) {
                suggestionChip(title: "Bantu buat rencana kerja", icon: "doc.text")
                suggestionChip(title: "Jelaskan konsep AI", icon: "sparkles")
                suggestionChip(title: "Tulis email formal", icon: "envelope")
                suggestionChip(title: "Brainstorming ide", icon: "lightbulb")
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LoflyTheme.Space.s) {
                suggestionChip(title: "Bantu buat rencana kerja", icon: "doc.text", expand: true)
                suggestionChip(title: "Jelaskan konsep AI", icon: "sparkles", expand: true)
                suggestionChip(title: "Tulis email formal", icon: "envelope", expand: true)
                suggestionChip(title: "Brainstorming ide", icon: "lightbulb", expand: true)
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
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(LoflyTheme.body(LoflyTheme.Size.caption))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: expand ? .infinity : nil)
            .padding(.horizontal, LoflyTheme.Space.m)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: LoflyTheme.Radius.large, style: .continuous)
                    .fill(LoflyTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LoflyTheme.Radius.large, style: .continuous)
                    .stroke(LoflyTheme.separator.opacity(0.6), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Floating Composer Capsule

    private var floatingComposerBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isRecordingAudio {
                // Waveform Audio Recording Bar (Speech-To-Text inside App)
                HStack(spacing: 12) {
                    plusAttachmentButton
                        .opacity(0.3)
                        .disabled(true)

                    AudioWaveformBarView()
                        .frame(maxWidth: .infinity)

                    // Cancel button (✕)
                    Button(action: cancelVoiceRecording) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(LoflyTheme.subtleFill.opacity(0.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Batal merekam")
                    .accessibilityLabel("Batal merekam")

                    // Confirm / Accept button (✓)
                    Button(action: confirmVoiceRecording) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.primary)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Selesai & masukkan teks")
                    .accessibilityLabel("Selesai & masukkan teks")
                }
                .frame(minHeight: 38)
                .padding(.horizontal, 4)
            } else {
                // 1. Attachment chips preview
                if !store.attachments.isEmpty {
                    attachmentChipsBar
                }

                // 2. Text input area
                TextField("Ask anything", text: $store.composerText, axis: .vertical)
                    .font(LoflyTheme.body(14))
                    .lineLimit(1...5)
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
                    .accessibilityLabel("Message Lofly")

                // 3. Bottom action row inside capsule
                HStack(spacing: LoflyTheme.Space.s) {
                    // Plus button for image and file attachments
                    plusAttachmentButton

                    // Model & Reasoning Selector: Gemini 3.8 Flash (Low, Medium, High)
                    modelSelectorMenu

                    // Tools pill button
                    Button {
                        store.activeSurface = .skills
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11, weight: .medium))
                            Text("Tools")
                                .font(LoflyTheme.label(LoflyTheme.Size.caption))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(LoflyTheme.subtleFill.opacity(0.25))
                        )
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("View and manage available tools")

                    Spacer()

                    // In-app Speech-to-text mic button
                    Button(action: startInAppVoiceRecording) {
                        Image(systemName: "mic")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Speech to text (Rekam suara)")
                    .accessibilityLabel("Speech to text")

                    // Send or stop button (ChatGPT style)
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
                                    .fill(Color.primary)
                                    .frame(width: 28, height: 28)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(nsColor: .windowBackgroundColor))
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
                                    .fill(canSend ? Color.primary : LoflyTheme.subtleFill.opacity(0.35))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(canSend ? Color(nsColor: .windowBackgroundColor) : Color.secondary.opacity(0.6))
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
        .padding(.horizontal, LoflyTheme.Space.m)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.xl, style: .continuous)
                .fill(LoflyTheme.composerBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.xl, style: .continuous)
                .stroke(LoflyTheme.separator.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
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
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(LoflyTheme.subtleFill.opacity(0.3))
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
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if !att.fileSize.isEmpty {
                                Text(att.fileSize)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: 120, alignment: .leading)

                        Button {
                            store.removeAttachment(id: att.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Hapus lampiran")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LoflyTheme.subtleFill.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(LoflyTheme.separator.opacity(0.5), lineWidth: 0.5)
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
            panel.message = "Pilih gambar untuk dilampirkan"
        } else {
            panel.allowedContentTypes = [.item, .content, .data, .pdf, .text, .plainText]
            panel.message = "Pilih file atau dokumen untuk dilampirkan"
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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LoflyTheme.accent)
                Text("Gemini 3.8 Flash")
                    .font(LoflyTheme.label(11))
                    .foregroundStyle(.primary)
                Text("· \(store.reasoningLevel.capitalized)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(LoflyTheme.subtleFill.opacity(0.25))
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
                LazyVStack(alignment: .leading, spacing: LoflyTheme.Space.l) {
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
                .padding(.horizontal, 48)
                .padding(.vertical, LoflyTheme.Space.m)
                .frame(maxWidth: 680, alignment: .leading)
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
                .frame(maxWidth: 680)

            Text("Lofly can make mistakes. Verify important info.")
                .font(LoflyTheme.caption(10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 48)
        .padding(.bottom, LoflyTheme.Space.s)
        .padding(.top, 4)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func submit() {
        let trimmed = store.composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.send()
        composerFocused = true
    }
}

// MARK: - Message Row (Clean ChatGPT Style)

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
                    // Only show inline thinking if there isn't an active task already showing it
                    if store.activeTask == nil {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking...")
                                .font(LoflyTheme.body(13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else if message.role == .assistant {
                    // Assistant response: rendered with rich markdown typography and real-time streaming caret
                    RichMarkdownView(text: message.text, isStreaming: isMessageStreaming)
                        .contentShape(Rectangle())

                    // ChatGPT-style Action Bar below AI Output (hidden while streaming)
                    if !isMessageStreaming && !message.text.isEmpty {
                        assistantActionBar
                    }
                } else {
                    // User Message Bubble
                    Text(MarkdownParser.inlineAttributedString(message.text))
                        .font(.system(size: 14.5, weight: .regular))
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LoflyTheme.userBubbleBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(LoflyTheme.userBubbleBorder, lineWidth: 0.5)
                                    )
                        )
                }

                if let error = message.error, !error.isEmpty {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: message.role == .user ? 560 : .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                // User bubble is right-aligned
            } else {
                Spacer(minLength: 32)
            }
        }
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "You" : "Assistant") said: \(message.text)")
    }

    // MARK: - Action Toolbar (Copy, Thumbs Up / Down Rate Response, Regenerate, Share)

    private var assistantActionBar: some View {
        let currentRating = store.messageRatings[message.id]

        return HStack(spacing: 6) {
            // 1. Copy text button
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
                        .font(.system(size: 12))
                    if didCopy {
                        Text("Copied")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .foregroundStyle(didCopy ? LoflyTheme.accent : Color.secondary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(didCopy ? LoflyTheme.accent.opacity(0.12) : (isHovering ? Color.primary.opacity(0.04) : Color.clear))
                )
            }
            .buttonStyle(.plain)
            .help(didCopy ? "Copied!" : "Salin teks")

            // 2. Thumbs up rate response
            Button {
                store.toggleRating(for: message.id, rating: .thumbsUp)
            } label: {
                Image(systemName: currentRating == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 12))
                    .foregroundStyle(currentRating == .thumbsUp ? LoflyTheme.accent : Color.secondary.opacity(0.8))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(currentRating == .thumbsUp ? LoflyTheme.accent.opacity(0.12) : (isHovering ? Color.primary.opacity(0.04) : Color.clear))
                    )
            }
            .buttonStyle(.plain)
            .help("Bagus")

            // 3. Thumbs down rate response
            Button {
                store.toggleRating(for: message.id, rating: .thumbsDown)
            } label: {
                Image(systemName: currentRating == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 12))
                    .foregroundStyle(currentRating == .thumbsDown ? Color.orange : Color.secondary.opacity(0.8))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(currentRating == .thumbsDown ? Color.orange.opacity(0.12) : (isHovering ? Color.primary.opacity(0.04) : Color.clear))
                    )
            }
            .buttonStyle(.plain)
            .help("Kurang bagus")

            // 4. Share button
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.text, forType: .string)
                didCopy = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    didCopy = false
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary.opacity(0.8))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isHovering ? Color.primary.opacity(0.04) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Share")

            // 5. Regenerate button
            Button {
                store.send()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary.opacity(0.8))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isHovering ? Color.primary.opacity(0.04) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Regenerate response")

            Spacer()
        }
        .padding(.top, 4)
        .opacity(isHovering || didCopy || currentRating != nil ? 1.0 : 0.7)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Voice Session Card

struct VoiceSessionCard: View {
    @EnvironmentObject private var store: DesktopStore
    let session: VoiceSession

    var body: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.s) {
            HStack(spacing: LoflyTheme.Space.s) {
                Image(systemName: "mic.fill")
                    .font(.system(size: LoflyTheme.Size.caption))
                    .foregroundStyle(session.isRunning ? .red : .secondary)
                LoflySectionHeader(session.isRunning ? "Voice session" : "Voice")
                if !session.isRunning {
                    Spacer(minLength: LoflyTheme.Space.xs)
                    Button {
                        store.dismissVoiceSession()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: LoflyTheme.Size.caption))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Dismiss")
                    .accessibilityLabel("Dismiss voice session")
                }
            }

            if !session.transcript.isEmpty {
                Text(session.transcript)
                    .font(LoflyTheme.body(LoflyTheme.Size.body))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if session.isRunning {
                HStack(spacing: LoflyTheme.Space.s) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Listening…")
                        .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                        .foregroundStyle(.secondary)
                }
            }

            if let response = session.responseText {
                RichMarkdownView(text: response)
                    .padding(LoflyTheme.Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                            .fill(LoflyTheme.accent.opacity(0.08))
                    )
            }

            if let error = session.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                    .foregroundStyle(.orange)
            }
        }
        .padding(LoflyTheme.Space.m)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.large, style: .continuous)
                .fill(LoflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.large, style: .continuous)
                .stroke(LoflyTheme.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
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
                .font(LoflyTheme.body(13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
    }
}
