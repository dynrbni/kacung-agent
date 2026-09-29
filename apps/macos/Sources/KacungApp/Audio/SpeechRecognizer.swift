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
    private var silenceTimer: Timer?
    private var hasDetectedSpeech = false
    private var audioFile: AVAudioFile?
    private let recordingURL = URL(fileURLWithPath: "/tmp/kacung-speech.wav")

    private init() {
        // Preferred locale: id-ID, fallback to system locale, then en-US
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

        // Clean any leftover tasks
        stopAndCleanUp()

        liveTranscript = ""
        errorMessage = nil
        hasDetectedSpeech = false

        // Check microphone status
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .denied || micStatus == .restricted {
            self.errorMessage = "Izin mikrofon belum diberikan. Silakan aktifkan di System Settings > Privacy > Microphone."
            return
        }

        if micStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.beginAudioSession()
                    } else {
                        self?.errorMessage = "Izin mikrofon ditolak oleh pengguna."
                    }
                }
            }
            return
        }

        // Microphone is already authorized, start listening immediately
        beginAudioSession()
    }

    private func beginAudioSession() {
        do {
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0 else {
                self.errorMessage = "Format audio mikrofon tidak valid (sample rate 0)."
                return
            }

            // 1. Prepare local WAV recording file
            if FileManager.default.fileExists(atPath: recordingURL.path) {
                try? FileManager.default.removeItem(at: recordingURL)
            }
            self.audioFile = try? AVAudioFile(forWriting: recordingURL, settings: recordingFormat.settings)

            // 2. Prepare native SFSpeechRecognizer request
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            self.recognitionRequest = request

            // 3. Install tap on inputNode to capture real-time audio
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                // Write to WAV file
                try? self?.audioFile?.write(from: buffer)

                // Pipe buffer to speech recognizer
                request.append(buffer)

                // Calculate visual audio level
                self?.calculateAudioLevel(buffer: buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            self.isListening = true
            print("AudioEngine started, listening for voice...")

            // 4. Start speech recognition task
            if let recognizer = speechRecognizer, recognizer.isAvailable {
                self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    guard let self = self else { return }

                    if let result = result {
                        let transcribed = result.bestTranscription.formattedString
                        if !transcribed.isEmpty {
                            self.liveTranscript = transcribed
                            self.hasDetectedSpeech = true
                            self.resetSilenceTimer()
                        }
                    }

                    if let error = error {
                        let nsError = error as NSError
                        // Ignore standard cancellation codes
                        if nsError.domain != "kAFAssistantErrorDomain" || (nsError.code != 203 && nsError.code != 216) {
                            if !self.hasDetectedSpeech {
                                print("Speech recognition note: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        } catch {
            self.errorMessage = "Gagal mengaktifkan audio engine: \(error.localizedDescription)"
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
        let recordedURL = recordingURL
        stopAndCleanUp()

        if !finalQuery.isEmpty {
            onTranscriptFinalized?(finalQuery)
        } else if FileManager.default.fileExists(atPath: recordedURL.path) {
            // Fallback to sending recorded audio to agent if native recognizer didn't emit text
            onAudioRecorded?(recordedURL)
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        // Finalize automatically after 1.5 seconds of silence
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishListening()
            }
        }
    }

    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sum: Float = 0.0
        let data = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        for sample in data {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))

        // Dynamic sensitivity: scale RMS to [0.0, 1.0] with aggressive responsiveness
        let normalized = min(max((rms - 0.001) * 45.0, 0.0), 1.0)

        DispatchQueue.main.async {
            // Apply subtle smoothing so wave looks organic
            self.audioLevel = (self.audioLevel * 0.3) + (normalized * 0.7)
        }
    }

    public func stopAndCleanUp() {
        silenceTimer?.invalidate()
        silenceTimer = nil

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
    }
}
