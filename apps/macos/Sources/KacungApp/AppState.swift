import Foundation
import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var state: AssistantState = .idle
    @Published public var isConnected = false
    @Published public var lastResponse: String = ""
    @Published public var liveTranscript: String = ""
    @Published public var inputText: String = ""
    @Published public var pendingConfirmation: ConfirmationRequest? = nil
    @Published public var isOverlayVisible = false
    @Published public var isVisibleOnScreen = false
    @Published public var audioLevel: Float = 0.0
    @Published public var isAccessibilityGranted = false
    @Published public var isMicrophoneGranted = false
    @Published public var isSpeechGranted = false
    @Published public var errorMessage: String? = nil

    public var overlayWindow: NSPanel?

    private var cancellables = Set<AnyCancellable>()
    private let client = AgentClient.shared
    private let speechRecognizer = SpeechRecognizer.shared
    private let speechSynthesizer = NativeSpeechSynthesizer.shared
    private let hotkey = HotkeyManager.shared
    private let permissions = PermissionManager.shared
    private var autoDismissWorkItem: DispatchWorkItem?

    private init() {
        checkPermissions()
        setupClientHandlers()
        setupSpeechHandlers()
        setupHotkey()

        client.connect()
    }

    public func checkPermissions() {
        isAccessibilityGranted = permissions.isAccessibilityGranted
        isMicrophoneGranted = permissions.isMicrophoneGranted
        isSpeechGranted = permissions.isSpeechRecognitionGranted
    }

    private func setupClientHandlers() {
        client.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isConnected = connected
            }
            .store(in: &cancellables)

        client.onStateChanged = { [weak self] newState in
            self?.state = newState
        }

        client.onConfirmationRequired = { [weak self] req in
            self?.pendingConfirmation = req
            self?.showOverlay()
        }

        client.onSpeechStart = { [weak self] text in
            self?.state = .speaking
            self?.speechSynthesizer.speak(text: text)
        }

        client.onSpeechEnd = { [weak self] _ in
            self?.state = .idle
            self?.scheduleAutoDismiss(delay: 1.8)
        }

        client.onError = { [weak self] errorMsg in
            self?.state = .error
            self?.lastResponse = "Error: \(errorMsg)"
            self?.scheduleAutoDismiss(delay: 3.0)
        }
    }

    private func setupSpeechHandlers() {
        speechRecognizer.$liveTranscript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                guard let self = self else { return }
                self.liveTranscript = transcript
                if !transcript.isEmpty {
                    self.inputText = transcript
                }
            }
            .store(in: &cancellables)

        speechRecognizer.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)

        speechRecognizer.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] err in
                if let err = err {
                    self?.errorMessage = err
                    self?.state = .error
                }
            }
            .store(in: &cancellables)

        speechRecognizer.onTranscriptFinalized = { [weak self] finalTranscript in
            guard let self = self else { return }
            let query = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }
            print("[AppState] Speech recognized: \"\(query)\". Submitting query...")
            self.liveTranscript = query
            self.inputText = query

            self.sendQuery(text: query)
            self.scheduleAutoDismiss(delay: 2.2)
        }

        speechRecognizer.onAudioRecorded = { [weak self] audioURL in
            guard let self = self else { return }
            print("[AppState] Sending recorded voice audio to agent runtime...")
            self.state = .thinking
            self.client.sendAudioFile(url: audioURL) { [weak self] result in
                switch result {
                case .success(let res):
                    self?.lastResponse = res.text
                    self?.state = .idle
                    self?.scheduleAutoDismiss(delay: 2.0)
                case .failure(let err):
                    self?.state = .error
                    self?.errorMessage = err.localizedDescription
                    self?.lastResponse = ""
                    self?.scheduleAutoDismiss(delay: 3.0)
                }
            }
        }
    }

    private func setupHotkey() {
        hotkey.onHotkeyTriggered = { [weak self] in
            self?.handleHotkeyWake()
        }
        hotkey.registerHotkey()
    }

    public func handleHotkeyWake() {
        autoDismissWorkItem?.cancel()
        if isVisibleOnScreen {
            // Dismiss immediately if user taps hotkey while active
            hideOverlay()
            if state == .listening {
                speechRecognizer.stopListening()
            }
        } else {
            // Summon from notch and listen immediately
            showOverlay()
            startListening()
        }
    }

    public func startListening() {
        autoDismissWorkItem?.cancel()
        checkPermissions()
        state = .listening
        liveTranscript = ""
        inputText = ""
        errorMessage = nil
        speechRecognizer.startListening()
        client.sendWake()
    }

    public func stopListening() {
        state = .thinking
        speechRecognizer.stopListening()
    }

    public func sendQuery(text: String) {
        state = .thinking
        lastResponse = ""
        liveTranscript = text
        inputText = text
        errorMessage = nil

        // Schedule auto-retract into notch after dispatching prompt
        scheduleAutoDismiss(delay: 2.5)

        client.sendQuery(text: text) { [weak self] result in
            switch result {
            case .success(let res):
                self?.lastResponse = res.text
                self?.state = .idle
                self?.scheduleAutoDismiss(delay: 2.0)
            case .failure(let err):
                self?.state = .error
                self?.lastResponse = "Error: \(err.localizedDescription)"
                self?.scheduleAutoDismiss(delay: 3.5)
            }
        }
    }

    public func resolveConfirmation(id: String, approved: Bool) {
        client.sendConfirmation(id: id, approved: approved)
        pendingConfirmation = nil
        scheduleAutoDismiss(delay: 1.5)
    }

    public func resetConversation() {
        client.sendReset()
        lastResponse = ""
        liveTranscript = ""
        inputText = ""
        errorMessage = nil
        state = .idle
        pendingConfirmation = nil
    }

    public func toggleOverlay() {
        if isVisibleOnScreen {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    public func showOverlay() {
        autoDismissWorkItem?.cancel()
        isOverlayVisible = true
        overlayWindow?.makeKeyAndOrderFront(nil)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.74)) {
            isVisibleOnScreen = true
        }
    }

    public func hideOverlay() {
        autoDismissWorkItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.74)) {
            isVisibleOnScreen = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard let self = self, !self.isVisibleOnScreen else { return }
            self.isOverlayVisible = false
            self.overlayWindow?.orderOut(nil)
        }
    }

    public func scheduleAutoDismiss(delay: Double = 2.0) {
        autoDismissWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.state != .listening && self.pendingConfirmation == nil {
                print("[AppState] Auto-dismissing Notch island back into bezel...")
                self.hideOverlay()
            }
        }
        autoDismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    public func updateOverlayHeight(_ height: CGFloat) {
        guard let panel = overlayWindow, let screen = NSScreen.main else { return }
        let safeHeight = max(height, 52.0)
        let screenFrame = screen.frame
        let width = panel.frame.width
        let x = screenFrame.midX - (width / 2.0)
        let y = screenFrame.maxY - safeHeight
        let newFrame = NSRect(x: x, y: y, width: width, height: safeHeight)
        if abs(panel.frame.height - safeHeight) > 1.0 {
            panel.setFrame(newFrame, display: true, animate: false)
        }
    }
}
