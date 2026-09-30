import Foundation
import AVFoundation
import Speech

public struct VoicePipelineConfig {
    /// Silence duration in seconds to trigger auto-finalization (target 800-1500ms; default 1.35s)
    public var silenceTimeoutSeconds: Double = 1.35
    /// Minimum speech duration in seconds to filter out mic pops/coughs (default 0.3s)
    public var minSpeechDurationSeconds: Double = 0.3
    /// Maximum recording duration in seconds before safety auto-finalization (default 45.0s)
    public var maxRecordingDurationSeconds: Double = 45.0
    /// VAD RMS energy delta threshold above ambient noise floor (default 0.008, sensitive to quiet speech)
    public var vadEnergyThreshold: Float = 0.008
    /// Debounce time in seconds after recognitionRequest.endAudio() to capture final recognized tokens (default 0.5s)
    public var finalizationDebounceSeconds: Double = 0.5
    /// Max pre-roll PCM buffers to retain in ring buffer (approx 350-450ms)
    public var preRollCapacity: Int = 14
}

@MainActor
public final class SpeechRecognizer: ObservableObject {
    public static let shared = SpeechRecognizer()

    public var config = VoicePipelineConfig()

    @Published public var isListening = false
    @Published public var liveTranscript = ""
    @Published public var audioLevel: Float = 0.0
    @Published public var errorMessage: String? = nil
    @Published public var hasSpoken = false

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
    private var sessionStartTime: DispatchTime = .now()
    private var speechStartTime: DispatchTime = .now()
    private var isFinalizing: Bool = false
    private var noiseFloor: Float = 0.008

    // Circular pre-roll buffer to prevent cutting off early syllables
    private var preRollBuffers: [AVAudioPCMBuffer] = []

    private init() {
        // Preferred locale: id-ID, fallback to system default, then en-US
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
        sessionStartTime = .now()
        speechStartTime = .now()
        preRollBuffers.removeAll()

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
            // Ensure audio engine is completely fresh on each session
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.reset()
            audioEngine = AVAudioEngine()

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0 else {
                self.errorMessage = "Mikrofon tidak aktif atau sample rate 0."
                return
            }

            // Diagnostics: Identify active microphone hardware and audio stream parameters
            let activeMicName = AVCaptureDevice.default(for: .audio)?.localizedName ?? "Default Input Device"
            print("""
            [SpeechRecognizer] === Voice Pipeline Initialized ===
              Microphone Device: \(activeMicName)
              Sample Rate: \(recordingFormat.sampleRate) Hz
              Channels: \(recordingFormat.channelCount) (\(recordingFormat.channelCount == 1 ? "Mono" : "Stereo"))
              Format Settings: \(recordingFormat.settings)
              VAD Trailing Silence Timeout: \(self.config.silenceTimeoutSeconds)s
              VAD Sensitivity Threshold: \(self.config.vadEnergyThreshold)
              Max Recording Duration: \(self.config.maxRecordingDurationSeconds)s
            ==================================================
            """)

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

                    // Contextual vocabulary: bias speech recognizer acoustic model towards apps and terms
                    request.contextualStrings = [
                        // Core Application Names
                        "WhatsApp", "Spotify", "CapCut", "Safari", "Google Chrome", "Chrome",
                        "VS Code", "Visual Studio Code", "GitHub", "Terminal", "Finder",
                        "Discord", "Telegram", "Microsoft Word", "Word", "Slack", "Notion",
                        // Indonesian Contacts & Entities
                        "Dimas", "Backsy", "Kacung",
                        // Common Indonesian / English voice command terms
                        "playlist", "screenshot", "volume", "turunin", "naikin", "buka",
                        "tutup", "putar", "chat", "kirim", "pesan", "bilang", "gue",
                        "telat", "lagu", "kesimpulan", "research", "document"
                    ]

                    self.recognitionRequest = request

                    // 3. Start speech recognition task
                    self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                        guard let self = self else { return }

                        if let result = result {
                            let text = result.bestTranscription.formattedString
                            if !text.isEmpty {
                                DispatchQueue.main.async {
                                    self.liveTranscript = text
                                    if !self.hasSpoken {
                                        self.hasSpoken = true
                                        self.speechStartTime = .now()
                                    }
                                    self.lastSpeechTime = .now()
                                }
                            }
                        }

                        if let error = error {
                            let nsError = error as NSError
                            if nsError.domain != "kAFAssistantErrorDomain" || (nsError.code != 203 && nsError.code != 216) {
                                print("[SpeechRecognizer] SFSpeechRecognition Notice: \(error.localizedDescription)")
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

            // 4. Install tap on inputNode: handles pre-roll buffering, writes to file, feeds recognizer, calculates VAD
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }

                // Manage circular pre-roll buffer before speech start
                if !self.hasSpoken {
                    if let copy = self.copyPCMBuffer(buffer) {
                        self.preRollBuffers.append(copy)
                        if self.preRollBuffers.count > self.config.preRollCapacity {
                            self.preRollBuffers.removeFirst()
                        }
                    }
                }

                // Write to WAV recording file
                try? self.audioFile?.write(from: buffer)

                // Feed to native speech recognizer
                self.recognitionRequest?.append(buffer)

                // Process audio energy, calibrate noise floor, and evaluate VAD
                self.processAudioBufferForVAD(buffer: buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            self.isListening = true
            print("[SpeechRecognizer] Listening started. Awaiting voice input...")

        } catch {
            self.errorMessage = "Gagal menyalakan mikrofon: \(error.localizedDescription)"
            stopAndCleanUp()
        }
    }

    private func copyPCMBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return nil
        }
        copy.frameLength = buffer.frameLength
        if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
            for channel in 0..<Int(buffer.format.channelCount) {
                memcpy(dst[channel], src[channel], Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
        }
        return copy
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

        // Dynamically calibrate ambient room noise floor
        if rms < noiseFloor * 1.5 {
            noiseFloor = (noiseFloor * 0.95) + (rms * 0.05)
        }

        let voiceDelta = max(rms - noiseFloor, 0.0)
        let rawLevel = min(max(voiceDelta * 45.0, 0.0), 1.0)
        let isVoiceActive = voiceDelta > self.config.vadEnergyThreshold

        if isVoiceActive {
            lastSpeechTime = .now()
            if !hasSpoken {
                hasSpoken = true
                speechStartTime = .now()
            }
        }

        DispatchQueue.main.async {
            // Smooth audio level for visualizer wave
            self.audioLevel = (self.audioLevel * 0.25) + (rawLevel * 0.75)

            let now = DispatchTime.now()

            // 1. Safety Check: Cap maximum recording duration to prevent indefinite listening
            let totalElapsed = Double(now.uptimeNanoseconds - self.sessionStartTime.uptimeNanoseconds) / 1_000_000_000.0
            if totalElapsed >= self.config.maxRecordingDurationSeconds && !self.isFinalizing {
                self.isFinalizing = true
                print("[SpeechRecognizer] Maximum recording duration of \(self.config.maxRecordingDurationSeconds)s reached. Finalizing...")
                self.finishListening()
                return
            }

            // 2. Trailing Silence Detection
            // Only auto-submit IF user has actually spoken text and speech exceeded minimum duration
            if self.hasSpoken && !self.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !self.isFinalizing {
                let speechElapsed = Double(now.uptimeNanoseconds - self.speechStartTime.uptimeNanoseconds) / 1_000_000_000.0
                let silenceSeconds = Double(now.uptimeNanoseconds - self.lastSpeechTime.uptimeNanoseconds) / 1_000_000_000.0

                if speechElapsed >= self.config.minSpeechDurationSeconds && silenceSeconds >= self.config.silenceTimeoutSeconds {
                    self.isFinalizing = true
                    print("[SpeechRecognizer] Trailing silence of \(String(format: "%.2f", silenceSeconds))s detected! Auto-submitting voice query...")
                    self.finishListening()
                }
            }
        }
    }

    public func stopListening() {
        guard isListening else { return }
        finishListening()
    }

    public func cancelListening() {
        guard isListening else { return }
        print("[SpeechRecognizer] Cancelling listening (prompt discarded).")
        stopAndCleanUp()
        liveTranscript = ""
    }

    private func finishListening() {
        guard isListening else { return }
        isListening = false

        // Stop capturing audio
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        // Wait debounce duration (500ms) to allow recognizer to capture the final trailing word
        DispatchQueue.main.asyncAfter(deadline: .now() + self.config.finalizationDebounceSeconds) { [weak self] in
            guard let self = self else { return }
            let finalQuery = self.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            let audioPath = self.recordingURL

            self.stopAndCleanUp()

            if !finalQuery.isEmpty {
                print("[SpeechRecognizer] Dispatched finalized voice query: \"\(finalQuery)\"")
                self.onTranscriptFinalized?(finalQuery)
            } else if FileManager.default.fileExists(atPath: audioPath.path) && self.hasSpoken {
                print("[SpeechRecognizer] Native recognizer emitted no text; dispatching audio file fallback...")
                self.onAudioRecorded?(audioPath)
            }
        }
    }

    public func stopAndCleanUp() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        audioFile = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        preRollBuffers.removeAll()

        isListening = false
        audioLevel = 0.0
        isFinalizing = false
    }
}
