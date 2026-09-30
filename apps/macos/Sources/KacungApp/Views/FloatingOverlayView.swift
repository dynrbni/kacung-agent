import SwiftUI

struct DynamicIslandShape: Shape {
    var cornerRadius: CGFloat = 10
    var hasNotch: Bool = true

    func path(in rect: CGRect) -> Path {
        if !hasNotch {
            return RoundedRectangle(cornerRadius: cornerRadius).path(in: rect)
        }
        var path = Path()
        // Top-left at bezel
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Top edge flush with screen top
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Right edge down to bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        // Left edge back to top-left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct DynamicIslandBorderShape: Shape {
    var cornerRadius: CGFloat = 10
    var hasNotch: Bool = true

    func path(in rect: CGRect) -> Path {
        if !hasNotch {
            return RoundedRectangle(cornerRadius: cornerRadius).path(in: rect)
        }
        var path = Path()
        // Start at top-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Down right side
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        // Up left side to top-left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        // Top edge remains open so it merges seamlessly into the black bezel
        return path
    }
}

public struct FloatingOverlayView: View {
    @ObservedObject public var appState: AppState
    @FocusState private var isInputFocused: Bool
    @State private var hasCopied: Bool = false

    private var notchHeight: CGFloat {
        appState.notchTopInset > 0 ? appState.notchTopInset : 32.0
    }
    private let notchWidth: CGFloat = 179.0
    private let activeWidth: CGFloat = 520.0
    private let wingWidth: CGFloat = 170.0

    private var promptText: String {
        if !appState.liveTranscript.isEmpty {
            return appState.liveTranscript
        }
        return appState.inputText
    }

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Main Horizontal Notch Bar (flushed with physical notch height)
                HStack(spacing: 0) {
                    // Left Wing (Left of camera notch)
                    HStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(stateColor.opacity(0.3))
                                .frame(width: 18, height: 18)

                            Circle()
                                .stroke(stateColor, lineWidth: 1.5)
                                .scaleEffect(appState.state == .listening ? (1.0 + CGFloat(appState.audioLevel * 0.35)) : 1.0)
                                .animation(.easeOut(duration: 0.1), value: appState.audioLevel)

                            Image(systemName: stateIconName)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(stateColor)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text("KACUNG")
                                .font(.system(size: 7.5, weight: .black, design: .rounded))
                                .foregroundColor(.gray)

                            Text(appState.state.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 12)
                    .frame(width: wingWidth, height: notchHeight)
                    .opacity(appState.isVisibleOnScreen ? 1.0 : 0.0)
                    .offset(x: appState.isVisibleOnScreen ? 0 : 45)

                    // Center Gap (Directly over physical webcam notch cutout)
                    Color.clear
                        .frame(width: notchWidth, height: notchHeight)

                    // Right Wing (Right of camera notch)
                    HStack(spacing: 6) {
                        Spacer(minLength: 0)

                        // Real-time transcribed speech text or status
                        if appState.state == .listening {
                            if !appState.liveTranscript.isEmpty {
                                Text("\"\(appState.liveTranscript)\"")
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundColor(.cyan)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: 70)
                            } else {
                                Text("Mendengarkan...")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        } else if appState.state == .thinking || appState.state == .executing {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text(appState.state == .executing ? "Jalan..." : "Proses...")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(.purple)
                            }
                        } else if !appState.lastResponse.isEmpty && !appState.isOutputExpanded {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    appState.isOutputExpanded = true
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Text(appState.lastResponse)
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.white.opacity(0.9))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: 75)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.cyan.opacity(0.8))
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        // Right-side voice wave visualizer
                        if appState.state == .listening || appState.audioLevel > 0.04 {
                            NotchAudioWaveView(
                                audioLevel: appState.audioLevel,
                                isListening: appState.state == .listening
                            )
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Hotkey badge
                        Text("⌃⌥")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(3.5)
                            .foregroundColor(.white.opacity(0.75))

                        // Dismiss button
                        Button(action: {
                            appState.hideOverlay()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 10)
                    .frame(width: wingWidth, height: notchHeight)
                    .opacity(appState.isVisibleOnScreen ? 1.0 : 0.0)
                    .offset(x: appState.isVisibleOnScreen ? 0 : -45)
                }
                .frame(height: notchHeight)

                // Optional Expanded Output Card (only when user clicks to see details)
                if appState.isOutputExpanded && !appState.lastResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Detail Perintah", systemImage: "text.bubble.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.cyan)

                            Spacer()

                            Button(action: {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(appState.lastResponse, forType: .string)
                                hasCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    hasCopied = false
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 9))
                                    Text(hasCopied ? "Disalin!" : "Salin")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(4)
                                .foregroundColor(hasCopied ? .green : .white)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    appState.isOutputExpanded = false
                                }
                            }) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.gray)
                                    .padding(3)
                            }
                            .buttonStyle(.plain)
                        }

                        if !promptText.isEmpty {
                            Text("PROMPT: \(promptText)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.cyan.opacity(0.9))
                                .lineLimit(2)
                        }

                        Text(appState.lastResponse)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .lineLimit(4)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(width: appState.isVisibleOnScreen ? activeWidth : notchWidth)
            .clipped()
            .background(
                DynamicIslandShape(cornerRadius: 10, hasNotch: appState.notchTopInset > 0)
                    .fill(Color.black)
            )
            .overlay(
                DynamicIslandBorderShape(cornerRadius: 10, hasNotch: appState.notchTopInset > 0)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: appState.isVisibleOnScreen)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.isOutputExpanded)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            isInputFocused = true
        }
    }

    private var stateColor: Color {
        switch appState.state {
        case .idle: return .blue
        case .listening: return .cyan
        case .thinking: return .purple
        case .executing: return .orange
        case .speaking: return .green
        case .error: return .red
        }
    }

    private var stateIconName: String {
        switch appState.state {
        case .idle: return "sparkles"
        case .listening: return "waveform"
        case .thinking: return "brain"
        case .executing: return "gearshape.arrow.triangle.2.circlepath"
        case .speaking: return "speaker.wave.2.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
