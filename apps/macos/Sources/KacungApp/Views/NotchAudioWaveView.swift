import SwiftUI

public struct NotchAudioWaveView: View {
    public let audioLevel: Float
    public let isListening: Bool

    // Bar multipliers creating a natural acoustic frequency curve
    private let barMultipliers: [CGFloat] = [0.4, 0.75, 1.3, 1.85, 1.35, 0.75, 0.4]

    public init(audioLevel: Float, isListening: Bool) {
        self.audioLevel = audioLevel
        self.isListening = isListening
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 0.03)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3.0) {
                ForEach(0..<barMultipliers.count, id: \.self) { index in
                    let multiplier = barMultipliers[index]
                    let phase = Double(index) * 0.9
                    let ambientPulse = isListening ? CGFloat(sin(time * 7.0 + phase) * 0.2 + 0.2) : 0.0

                    let levelScaled = CGFloat(audioLevel) * 14.0 * multiplier
                    let dynamicHeight = 3.0 + ambientPulse * 3.5 + levelScaled
                    let clampedHeight = min(max(dynamicHeight, 3.0), 16.0)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: 2.5, height: clampedHeight)
                        .shadow(
                            color: Color.white.opacity(Double(audioLevel) * 0.4 + (isListening ? 0.2 : 0.0)),
                            radius: 2,
                            x: 0,
                            y: 0
                        )
                        .animation(.easeOut(duration: 0.08), value: audioLevel)
                }
            }
            .frame(height: 20)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.6)
            )
        }
    }
}
