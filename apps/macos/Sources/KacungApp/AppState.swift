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
    @Published public var isOverlayVisible = true
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
            if newState != .idle {
                self?.showOverlay()
            }
        }

        client.onConfirmationRequired = { [weak self] req in
            self?.pendingConfirmation = req
            self?.showOverlay()
        }

        client.onSpeechStart = { [weak self] text in
            self?.state = .speaking
            // Native voice feedback fallback
            self?.speechSynthesizer.speak(text: text)
        }

        client.onSpeechEnd = { [weak self] _ in
            self?.state = .idle
        }

        client.onError = { [weak self] errorMsg in
            self?.state = .error
            self?.lastResponse = "Error: \(errorMsg)"
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
            print("[AppState] Speech recognized: \"\(finalTranscript)\"")
            self.liveTranscript = finalTranscript
            self.inputText = finalTranscript

            // Brief visual delay so user sees the recognized text in the input box before auto-submitting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self = self else { return }
                let query = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !query.isEmpty {
                    print("[AppState] Auto-submitting voice query: \"\(query)\"")
                    self.sendQuery(text: query)
                }
            }
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
                case .failure(let err):
                    self?.state = .error
                    self?.errorMessage = err.localizedDescription
                    self?.lastResponse = ""
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
        showOverlay()
        if state == .idle {
            startListening()
        } else if state == .listening {
            stopListening()
        } else {
            toggleOverlay()
        }
    }

    public func startListening() {
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

        client.sendQuery(text: text) { [weak self] result in
            switch result {
            case .success(let res):
                self?.lastResponse = res.text
                self?.state = .idle
            case .failure(let err):
                self?.state = .error
                self?.lastResponse = "Error: \(err.localizedDescription)"
            }
        }
    }

    public func resolveConfirmation(id: String, approved: Bool) {
        client.sendConfirmation(id: id, approved: approved)
        pendingConfirmation = nil
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
        if isOverlayVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    public func showOverlay() {
        isOverlayVisible = true
        overlayWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hideOverlay() {
        isOverlayVisible = false
        overlayWindow?.orderOut(nil)
    }
}
