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
    public var onAudioRecorded: ((URL) -> Void)?

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Audio recording file for fallback
    private var audioFile: AVAudioFile?
    private let recordingURL = URL(fileURLWithPath: "/tmp/kacung-speech.wav")

    // High-precision DispatchTime VAD (Voice Activity Detection)
    private var lastSpeechTime: DispatchTime = .now()
    private var hasSpoken: Bool = false
    private var isFinalizing: Bool = false

    private init() {
        // Preferred locale: id-ID, fallback to system default (e.g. en_ID), then en-US
        if let idRec = SFSpeechRecognizer(locale: Locale(identifier: "id-ID")), idRec.isAvailable {
            self.speechRecognizer = idRec
        } else if let sysRec = SFSpeechRecognizer(), sysRec.isAvailable {
            self.speechRecognizer = sysRec
        } else {
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
    }

    public func requestSpeechAuthorization(completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    print("[SpeechRecognizer] SFSpeechRecognizer authorization status: \(authStatus.rawValue)")
                    completion(authStatus == .authorized)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    public func startListening() {
        guard !isListening else { return }

        stopAndCleanUp()

        liveTranscript = ""
        errorMessage = nil
        hasSpoken = false
        isFinalizing = false
        lastSpeechTime = .now()

        // 1. Verify Microphone Permission
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .denied || micStatus == .restricted {
            self.errorMessage = "Izin mikrofon belum diberikan. Buka System Settings > Privacy & Security > Microphone."
            return
        }

        if micStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.verifySpeechAndBegin()
                    } else {
                        self?.errorMessage = "Izin mikrofon ditolak."
                    }
                }
            }
            return
        }

        verifySpeechAndBegin()
    }

    private func getAvailableRecognizer() -> SFSpeechRecognizer? {
        if let idRec = SFSpeechRecognizer(locale: Locale(identifier: "id-ID")), idRec.isAvailable {
            return idRec
        } else if let sysRec = SFSpeechRecognizer(), sysRec.isAvailable {
            return sysRec
        } else if let enRec = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), enRec.isAvailable {
            return enRec
        }
        return self.speechRecognizer
    }

    private func verifySpeechAndBegin() {
        requestSpeechAuthorization { [weak self] speechGranted in
            guard let self = self else { return }
            if !speechGranted {
                print("[SpeechRecognizer] Notice: Speech recognition permission is not authorized.")
                self.errorMessage = "Izin Speech Recognition belum aktif. Buka System Settings > Privacy & Security > Speech Recognition."
            }
            self.beginAudioSession(enableRecognizer: speechGranted)
        }
    }

    private func beginAudioSession(enableRecognizer: Bool) {
        do {
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0 else {
                self.errorMessage = "Mikrofon tidak aktif atau sample rate 0."
                return
            }

            // 1. Prepare local WAV recording file
            if FileManager.default.fileExists(atPath: recordingURL.path) {
                try? FileManager.default.removeItem(at: recordingURL)
            }
            self.audioFile = try? AVAudioFile(forWriting: recordingURL, settings: recordingFormat.settings)

            // 2. Prepare native SFSpeechRecognizer request
            if enableRecognizer {
                if let recognizer = getAvailableRecognizer(), recognizer.isAvailable {
                    let request = SFSpeechAudioBufferRecognitionRequest()
                    request.shouldReportPartialResults = true
                    request.addsPunctuation = true
                    self.recognitionRequest = request

                    // 3. Start speech recognition task
                    self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                        guard let self = self else { return }

                        if let result = result {
                            let text = result.bestTranscription.formattedString
                            if !text.isEmpty {
                                DispatchQueue.main.async {
                                    self.liveTranscript = text
                                    self.hasSpoken = true
                                    self.lastSpeechTime = .now()
                                }
                            }
                        }

                        if let error = error {
                            let nsError = error as NSError
                            if nsError.domain != "kAFAssistantErrorDomain" || (nsError.code != 203 && nsError.code != 216) {
                                print("[SpeechRecognizer] Notice: \(error.localizedDescription)")
                                DispatchQueue.main.async {
                                    if nsError.localizedDescription.contains("denied") || nsError.code == 1700 {
                                        self.errorMessage = "Akses Speech Recognition ditolak. Buka System Settings > Privacy & Security > Speech Recognition."
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("[SpeechRecognizer] SFSpeechRecognizer is not available.")
                }
            }

            // 4. Install tap on inputNode: calculates VAD, updates wave, checks silence
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }

                // Save to audio file
                try? self.audioFile?.write(from: buffer)

                // Feed to Apple speech recognizer if enabled
                self.recognitionRequest?.append(buffer)

                // Calculate energy & Voice Activity Detection
                self.processAudioBufferForVAD(buffer: buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            self.isListening = true
            print("[SpeechRecognizer] Listening started. Speak now...")

        } catch {
            self.errorMessage = "Gagal menyalakan mikrofon: \(error.localizedDescription)"
            stopAndCleanUp()
        }
    }

    private func processAudioBufferForVAD(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sum: Float = 0.0
        let data = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        for sample in data {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))

        // Scale RMS to a responsive 0.0 - 1.0 audio level
        let rawLevel = min(max((rms - 0.001) * 55.0, 0.0), 1.0)

        // Voice detection threshold
        let isVoiceActive = rawLevel > 0.07

        if isVoiceActive {
            hasSpoken = true
            lastSpeechTime = .now()
        }

        DispatchQueue.main.async {
            // Smooth audio level for visualizer wave
            self.audioLevel = (self.audioLevel * 0.25) + (rawLevel * 0.75)

            // VAD Silence Check:
            // If the user has spoken at least once, and audio has remained silent for 1.1 seconds:
            if self.hasSpoken && !self.isFinalizing {
                let now = DispatchTime.now()
                let silenceSeconds = Double(now.uptimeNanoseconds - self.lastSpeechTime.uptimeNanoseconds) / 1_000_000_000.0

                if silenceSeconds >= 1.1 {
                    self.isFinalizing = true
                    print("[SpeechRecognizer] Silence of \(String(format: "%.1f", silenceSeconds))s detected! Auto-submitting voice query...")
                    self.finishListening()
                }
            }
        }
    }

    public func stopListening() {
        guard isListening else { return }
        finishListening()
    }

    private func finishListening() {
        guard isListening else { return }
        isListening = false

        // Stop capturing audio
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()

        // Wait brief 200ms to let the recognizer catch the final trailing word
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            let finalQuery = self.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            let audioPath = self.recordingURL

            self.stopAndCleanUp()

            if !finalQuery.isEmpty {
                print("[SpeechRecognizer] Dispatched voice query: \"\(finalQuery)\"")
                self.onTranscriptFinalized?(finalQuery)
            } else if FileManager.default.fileExists(atPath: audioPath.path) {
                print("[SpeechRecognizer] Native recognizer emitted no text; dispatching audio file fallback...")
                self.onAudioRecorded?(audioPath)
            }
        }
    }

    public func stopAndCleanUp() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        audioFile = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        audioLevel = 0.0
        isFinalizing = false
    }
}
