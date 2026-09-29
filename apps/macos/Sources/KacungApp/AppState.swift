import Foundation
import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var state: AssistantState = .idle
    @Published public var isConnected = false
    @Published public var lastResponse: String = ""
    @Published public var pendingConfirmation: ConfirmationRequest? = nil
    @Published public var isOverlayVisible = true
    @Published public var audioLevel: Float = 0.0
    @Published public var isAccessibilityGranted = false
    @Published public var isMicrophoneGranted = false

    public var overlayWindow: NSPanel?

    private var cancellables = Set<AnyCancellable>()
    private let client = AgentClient.shared
    private let recorder = AudioRecorder.shared
    private let speech = NativeSpeechSynthesizer.shared
    private let hotkey = HotkeyManager.shared
    private let permissions = PermissionManager.shared

    private init() {
        checkPermissions()
        setupClientHandlers()
        setupAudioHandlers()
        setupHotkey()

        client.connect()
    }

    public func checkPermissions() {
        isAccessibilityGranted = permissions.isAccessibilityGranted
        isMicrophoneGranted = permissions.isMicrophoneGranted
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

        client.onSpeechStart = { [weak self] _ in
            self?.state = .speaking
        }

        client.onSpeechEnd = { [weak self] _ in
            self?.state = .idle
        }

        client.onError = { [weak self] errorMsg in
            self?.state = .error
            self?.lastResponse = "Error: \(errorMsg)"
        }
    }

    private func setupAudioHandlers() {
        recorder.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
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
        } else {
            toggleOverlay()
        }
    }

    public func startListening() {
        state = .listening
        recorder.startRecording()
        client.sendWake()
    }

    public func stopListening() {
        recorder.stopRecording()
        state = .thinking
    }

    public func sendQuery(text: String) {
        state = .thinking
        lastResponse = ""
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
