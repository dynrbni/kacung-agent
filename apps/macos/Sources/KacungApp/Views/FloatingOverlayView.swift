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
                // Main Horizontal Notch Bar
                HStack(spacing: 0) {
                    // Left Wing: strictly clean SF Pro text, no icons, no colored badges
                    HStack {
                        if appState.state == .listening {
                            Text("Listening")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        } else if appState.state == .thinking {
                            Text("Thinking...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        } else if appState.state == .executing {
                            Text("Executing...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        } else if appState.state == .error {
                            Text(appState.errorMessage ?? "Error")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                                .lineLimit(1)
                        } else if !appState.lastResponse.isEmpty {
                            Text(appState.lastResponse)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text("Kacung")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 14)
                    .frame(width: wingWidth, height: notchHeight)
                    .opacity(appState.isVisibleOnScreen ? 1.0 : 0.0)
                    .offset(x: appState.isVisibleOnScreen ? 0 : 45)

                    // Center Gap (Physical Webcam Notch Cutout)
                    Color.clear
                        .frame(width: notchWidth, height: notchHeight)

                    // Right Wing: strictly pure white wave visualizer, no badges, no Mendengarkan text, no x button
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)

                        if appState.state == .listening {
                            // Only white wave visualizer
                            NotchAudioWaveView(
                                audioLevel: appState.audioLevel,
                                isListening: true
                            )
                        } else if appState.state == .thinking || appState.state == .executing {
                            ProgressView()
                                .controlSize(.mini)
                                .colorInvert()
                        } else if !appState.lastResponse.isEmpty {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    appState.isOutputExpanded.toggle()
                                }
                            }) {
                                Image(systemName: appState.isOutputExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.trailing, 14)
                    .frame(width: wingWidth, height: notchHeight)
                    .opacity(appState.isVisibleOnScreen ? 1.0 : 0.0)
                    .offset(x: appState.isVisibleOnScreen ? 0 : -45)
                }
                .frame(height: notchHeight)

                // Optional Expanded Output Card (only when user clicks to see details)
                if appState.isOutputExpanded && !appState.lastResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Output")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))

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
                                    Text(hasCopied ? "Disalin" : "Salin")
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
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(3)
                            }
                            .buttonStyle(.plain)
                        }

                        if !promptText.isEmpty {
                            Text("Prompt: \(promptText)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(2)
                        }

                        Text(appState.lastResponse)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white)
                            .lineLimit(5)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .padding(.horizontal, 14)
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
}
