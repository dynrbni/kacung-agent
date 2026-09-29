import Foundation
import AVFoundation

public final class AudioRecorder: ObservableObject {
    public static let shared = AudioRecorder()

    private var audioEngine = AVAudioEngine()
    @Published public var isRecording = false
    @Published public var audioLevel: Float = 0.0

    public var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    private init() {}

    public func startRecording() {
        guard !isRecording else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
            self?.onAudioBuffer?(buffer)
        }

        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    public func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataValue = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        var sum: Float = 0.0
        for sample in channelDataValue {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        DispatchQueue.main.async {
            self.audioLevel = min(max(rms * 10.0, 0.0), 1.0)
        }
    }
}
