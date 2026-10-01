import SwiftUI
import Combine

/// Dynamic audio waveform visualizer matching modern AI voice recording interfaces.
/// Displays animated sound wave bars that fill 100% of the available width,
/// reacting in real-time to microphone audio levels with organic wave dynamics.
public struct AudioWaveformBarView: View {
    @ObservedObject var recognizer = SpeechRecognizer.shared
    @State private var phase: Double = 0
    @State private var sampleHistory: [Float] = []
    @State private var timer: Timer?

    private let barWidth: CGFloat = 3.0
    private let minSpacing: CGFloat = 2.5
    private let maxHeight: CGFloat = 26.0
    private let minHeight: CGFloat = 4.0

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(60.0, geometry.size.width)
            let count = max(8, Int(availableWidth / (barWidth + minSpacing)))
            let spacing = max(1.5, (availableWidth - CGFloat(count) * barWidth) / CGFloat(max(1, count - 1)))

            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    let sample = sampleValue(at: index, count: count)
                    let barH = minHeight + CGFloat(sample) * (maxHeight - minHeight)

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color.white.opacity(0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barWidth, height: barH)
                }
            }
            .frame(width: availableWidth, height: geometry.size.height, alignment: .center)
            .clipped()
            .onAppear {
                initHistory(count: count)
                startAnimation(count: count)
            }
            .onChange(of: count) { newCount in
                initHistory(count: newCount)
            }
        }
        .frame(height: 28)
        .onDisappear {
            stopAnimation()
        }
    }

    private func initHistory(count: Int) {
        guard count > 0 else { return }
        if sampleHistory.count != count {
            sampleHistory = Array(repeating: 0.06, count: count)
        }
    }

    private func startAnimation(count: Int) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { _ in
            Task { @MainActor in
                self.phase += 0.22
                let level = self.recognizer.audioLevel

                // Combine real microphone level with organic frequency jitter so waves stay alive
                let organic = Float(sin(self.phase * 3.1)) * 0.04 + Float(cos(self.phase * 1.9)) * 0.03
                let targetSample = max(0.04, min(1.0, level * 2.2 + organic))

                if self.sampleHistory.count != count {
                    self.sampleHistory = Array(repeating: targetSample, count: max(1, count))
                } else if !self.sampleHistory.isEmpty {
                    self.sampleHistory.removeFirst()
                    self.sampleHistory.append(targetSample)
                }
            }
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }

    private func sampleValue(at index: Int, count: Int) -> Float {
        guard !sampleHistory.isEmpty else { return 0.06 }
        let safeIndex = min(index, sampleHistory.count - 1)
        let histVal = sampleHistory[safeIndex]

        // Organic traveling wave across the bars for continuous fluid motion
        let x = Double(index) / Double(max(1, count))
        let ripple = Float(sin(phase * 1.8 + x * Double.pi * 5.0)) * 0.07
        let speechBoost = recognizer.audioLevel > 0.04
            ? Float(sin(phase * 4.2 + x * Double.pi * 8.0)) * recognizer.audioLevel * 0.3
            : 0.0

        return max(0.04, min(1.0, histVal * 0.85 + ripple + speechBoost))
    }
}
