import SwiftUI

struct DynamicIslandShape: Shape {
    var cornerRadius: CGFloat = 18
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
    var cornerRadius: CGFloat = 18
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

    private var promptText: String {
        if !appState.liveTranscript.isEmpty {
            return appState.liveTranscript
        }
        return appState.inputText
    }

    private var topPadding: CGFloat {
        if appState.notchTopInset > 0 {
            return appState.notchTopInset + 4.0
        }
        return 10.0
    }

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main Solid Jet Black Notch Island
            VStack(spacing: 8) {
                // Header Capsule (matches MacBook Notch visual extension)
                HStack(spacing: 10) {
                    // Left: Glowing Animated Kacung Indicator
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(stateColor.opacity(0.3))
                                .frame(width: 24, height: 24)

                            Circle()
                                .stroke(stateColor, lineWidth: 1.8)
                                .frame(width: 24, height: 24)
                                .scaleEffect(appState.state == .listening ? (1.0 + CGFloat(appState.audioLevel * 0.4)) : 1.0)
                                .animation(.easeOut(duration: 0.1), value: appState.audioLevel)

                            Image(systemName: stateIconName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(stateColor)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text("KACUNG")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(.gray)

                            Text(appState.state.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()

                    // Center: Real-time Transcribed Speech Text
                    if appState.state == .listening {
                        if !appState.liveTranscript.isEmpty {
                            Text("\"\(appState.liveTranscript)\"")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.cyan)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: 180)
                        } else {
                            Text("Mendengarkan...")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    } else if appState.state == .thinking || appState.state == .executing {
                        HStack(spacing: 5) {
                            ProgressView()
                                .controlSize(.mini)
                            Text(appState.state == .executing ? "Menjalankan..." : "Memproses...")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.purple)
                        }
                    } else if !appState.lastResponse.isEmpty && !appState.isOutputExpanded {
                        Text(appState.lastResponse)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 180)
                    }

                    Spacer()

                    // Right: Audio Waveform Animation + Hotkey badge
                    HStack(spacing: 6) {
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
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(4)
                            .foregroundColor(.white.opacity(0.75))

                        // Dismiss button
                        Button(action: {
                            appState.hideOverlay()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(3)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Error Message if present
                if let error = appState.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(6)
                }

                // Response Card (when AI has responded and expanded view requested)
                if !appState.lastResponse.isEmpty && appState.isOutputExpanded {
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }

                // If user clicks compact response to toggle full details
                if !appState.lastResponse.isEmpty && !appState.isOutputExpanded && appState.state != .listening {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            appState.isOutputExpanded = true
                        }
                    }) {
                        HStack {
                            Text("Lihat detail respons")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan.opacity(0.8))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.cyan.opacity(0.8))
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, topPadding)
            .padding(.bottom, 10)
            .frame(width: 400)
            .background(
                // Pure Solid Jet Black seamless with MacBook Notch
                DynamicIslandShape(cornerRadius: 18, hasNotch: appState.notchTopInset > 0)
                    .fill(Color.black)
            )
            .overlay(
                DynamicIslandBorderShape(cornerRadius: 18, hasNotch: appState.notchTopInset > 0)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.6), radius: 14, x: 0, y: 7)
            .offset(y: appState.isVisibleOnScreen ? 0 : -(appState.notchTopInset + 90))
            .opacity(appState.isVisibleOnScreen ? 1.0 : 0.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.76), value: appState.isVisibleOnScreen)

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
