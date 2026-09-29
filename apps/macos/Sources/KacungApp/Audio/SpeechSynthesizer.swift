import Foundation
import AVFoundation

@MainActor
public final class NativeSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = NativeSpeechSynthesizer()

    private let synthesizer = AVSpeechSynthesizer()
    public var onSpeakingStarted: (() -> Void)?
    public var onSpeakingFinished: (() -> Void)?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speak(text: stringLiteral) {
        let cleanText = text.replacingOccurrences(of: "[*#`_]", with: "", options: .regularExpression)
        let utterance = AVSpeechUtterance(string: cleanText)

        // Try Indonesian voice first, fallback to English
        if let idVoice = AVSpeechSynthesisVoice(language: "id-ID") {
            utterance.voice = idVoice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.onSpeakingStarted?()
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.onSpeakingFinished?()
        }
    }

    public typealias stringLiteral = String
}
