import SwiftUI

public struct NotchAudioWaveView: View {
    public let audioLevel: Float
    public let isListening: Bool

    // Bar multipliers creating a natural acoustic frequency curve
    private let barMultipliers: [CGFloat] = [0.35, 0.65, 1.2, 1.8, 1.2, 0.65, 0.35]

    public init(audioLevel: Float, isListening: Bool) {
        self.audioLevel = audioLevel
        self.isListening = isListening
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 0.025)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<barMultipliers.count, id: \.self) { index in
                    let multiplier = barMultipliers[index]
                    let phase = Double(index) * 0.85
                    let ambientPulse = isListening
                        ? CGFloat(sin(time * 6.5 + phase) * 0.18 + 0.18)
                        : 0.0

                    let levelScaled = CGFloat(audioLevel) * 13.0 * multiplier
                    let dynamicHeight = 2.5 + ambientPulse * 3.5 + levelScaled
                    let clampedHeight = min(max(dynamicHeight, 2.5), 15.0)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: 2.0, height: clampedHeight)
                        .shadow(
                            color: Color.white.opacity(Double(audioLevel) * 0.35 + (isListening ? 0.15 : 0.0)),
                            radius: 1.5,
                            x: 0,
                            y: 0
                        )
                        .animation(.easeOut(duration: 0.07), value: audioLevel)
                }
            }
            .frame(height: 18)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
    }
}
