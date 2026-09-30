import Foundation
import SwiftUI
import Combine

public func getNotchScreen() -> NSScreen {
    if let notchScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
        return notchScreen
    }
    if #available(macOS 12.0, *) {
        if let notchScreen = NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }) {
            return notchScreen
        }
    }
    return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
}

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
    @Published public var isOutputExpanded = false
    @Published public var notchTopInset: CGFloat = 32.0
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
    private var hideWorkItem: DispatchWorkItem?

    private init() {
        checkPermissions()
        updateNotchMetrics()
        setupClientHandlers()
        setupSpeechHandlers()
        setupHotkey()

        // Periodically monitor system permissions (e.g. user toggles Accessibility in System Settings)
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPermissions()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkPermissions()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.repositionOverlayWindow()
            }
            .store(in: &cancellables)

        client.connect()
    }

    public func updateNotchMetrics() {
        let screen = getNotchScreen()
        let topInset = screen.safeAreaInsets.top
        self.notchTopInset = topInset > 0 ? topInset : 0.0
    }

    public func repositionOverlayWindow() {
        guard let panel = overlayWindow else { return }
        updateNotchMetrics()
        let notchScreen = getNotchScreen()
        let screenFrame = notchScreen.frame
        let windowWidth: CGFloat = 560.0
        let windowHeight: CGFloat = 240.0
        let x = screenFrame.midX - (windowWidth / 2.0)
        let y = screenFrame.maxY - windowHeight
        let targetFrame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        if panel.frame != targetFrame {
            panel.setFrame(targetFrame, display: true, animate: false)
        }
    }

    public func checkPermissions() {
        let prevAX = isAccessibilityGranted
        let currentAX = permissions.isAccessibilityGranted
        if prevAX != currentAX {
            print("[AppState] Accessibility permission updated: \(currentAX)")
        }
        isAccessibilityGranted = currentAX
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
        }

        speechRecognizer.onAudioRecorded = { [weak self] audioURL in
            guard let self = self else { return }
            print("[AppState] Sending recorded voice audio to agent runtime...")
            self.autoDismissWorkItem?.cancel()
            self.state = .thinking
            self.client.sendAudioFile(url: audioURL) { [weak self] result in
                switch result {
                case .success(let res):
                    self?.lastResponse = res.text
                    self?.state = .idle
                    self?.scheduleAutoDismiss(delay: 4.0)
                case .failure(let err):
                    self?.state = .error
                    self?.errorMessage = err.localizedDescription
                    self?.lastResponse = ""
                    self?.scheduleAutoDismiss(delay: 4.5)
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
        autoDismissWorkItem?.cancel()
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
                self?.scheduleAutoDismiss(delay: 4.0)
            case .failure(let err):
                self?.state = .error
                self?.lastResponse = "Error: \(err.localizedDescription)"
                self?.scheduleAutoDismiss(delay: 4.5)
            }
        }
    }

    public func resolveConfirmation(id: String, approved: Bool) {
        client.sendConfirmation(id: id, approved: approved)
        pendingConfirmation = nil
        scheduleAutoDismiss(delay: 2.0)
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
        hideWorkItem?.cancel()
        hideWorkItem = nil

        repositionOverlayWindow()

        isOverlayVisible = true
        overlayWindow?.makeKeyAndOrderFront(nil)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.76)) {
            isVisibleOnScreen = true
        }
    }

    public func hideOverlay() {
        autoDismissWorkItem?.cancel()
        hideWorkItem?.cancel()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.76)) {
            isVisibleOnScreen = false
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if !self.isVisibleOnScreen {
                self.isOverlayVisible = false
                self.overlayWindow?.orderOut(nil)
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    public func scheduleAutoDismiss(delay: Double = 4.0) {
        autoDismissWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // Only auto-dismiss if task completed (idle) or failed (error), never during execution or listening
            if (self.state == .idle || self.state == .error) && self.pendingConfirmation == nil {
                print("[AppState] Auto-dismissing Notch island back into bezel...")
                self.hideOverlay()
            }
        }
        autoDismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
