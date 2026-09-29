import Foundation
import AVFoundation
import Speech

@MainActor
public final class SpeechRecognizer: ObservableObject {
    public static let shared = SpeechRecognizer()

    @Published public var isListening = false
    @Published public var liveTranscript = ""
    @Published public var audioLevel: Float = 0.0
    @Published public var errorMessage: String? = nil

    public var onTranscriptFinalized: ((String) -> Void)?

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var hasDetectedSpeech = false

    private init() {
        // Preferred locale: id-ID, fallback to system locale or en-US
        if let idRec = SFSpeechRecognizer(locale: Locale(identifier: "id-ID")), idRec.isAvailable {
            self.speechRecognizer = idRec
        } else if let sysRec = SFSpeechRecognizer(), sysRec.isAvailable {
            self.speechRecognizer = sysRec
        } else {
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
    }

    public func startListening() {
        guard !isListening else { return }

        // 1. Verify permissions
        PermissionManager.shared.requestAllPermissions { [weak self] granted in
            guard let self = self else { return }
            if !granted {
                self.errorMessage = "Izin mikrofon atau speech recognition belum diberikan. Silakan aktifkan di System Settings."
                return
            }
            self.beginAudioSession()
        }
    }

    private func beginAudioSession() {
        // Reset any existing task
        stopAndCleanUp()

        liveTranscript = ""
        errorMessage = nil
        hasDetectedSpeech = false

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            self.errorMessage = "Speech recognizer tidak tersedia pada Mac ini."
            return
        }

        do {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            self.recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0 else {
                self.errorMessage = "Format audio mikrofon tidak valid (sample rate 0)."
                return
            }

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                request.append(buffer)
                self?.calculateAudioLevel(buffer: buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            self.isListening = true

            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    let transcribed = result.bestTranscription.formattedString
                    self.liveTranscript = transcribed
                    self.hasDetectedSpeech = true

                    // Reset silence timer on every new word
                    self.resetSilenceTimer()

                    if result.isFinal {
                        self.finishListening()
                    }
                }

                if let error = error {
                    // Ignore cancellation errors
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 203 || nsError.code == 216) {
                        // Request completed or aborted normally
                        return
                    }
                    if !self.hasDetectedSpeech {
                        print("Speech recognition notice: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            self.errorMessage = "Gagal mengaktifkan mikrofon: \(error.localizedDescription)"
            stopAndCleanUp()
        }
    }

    public func stopListening() {
        guard isListening else { return }
        silenceTimer?.invalidate()
        silenceTimer = nil
        finishListening()
    }

    private func finishListening() {
        let finalQuery = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopAndCleanUp()

        if !finalQuery.isEmpty {
            onTranscriptFinalized?(finalQuery)
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        // Wait 1.5 seconds of silence after speech is detected to finalize
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishListening()
            }
        }
    }

    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataValue = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        var sum: Float = 0.0
        for sample in channelDataValue {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        DispatchQueue.main.async {
            self.audioLevel = min(max(rms * 12.0, 0.0), 1.0)
        }
    }

    public func stopAndCleanUp() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        audioLevel = 0.0
    }
}
