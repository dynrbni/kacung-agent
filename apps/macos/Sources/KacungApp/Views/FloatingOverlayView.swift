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
    @State private var isHoveringRight: Bool = false

    private var notchHeight: CGFloat {
        appState.notchTopInset > 0 ? appState.notchTopInset : 32.0
    }
    private let notchWidth: CGFloat = 179.0
    private let wingWidth: CGFloat = 85.5
    private var activeWidth: CGFloat {
        notchWidth + (wingWidth * 2) // Exactly 350.0 pt - compact and clean
    }

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
                            Text(appState.liveTranscript.isEmpty ? "Listening" : appState.liveTranscript)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else if appState.state == .thinking {
                            Text("Thinking...")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        } else if appState.state == .executing {
                            Text("Executing...")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        } else if appState.state == .error {
                            Text(appState.errorMessage ?? "Error")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                                .lineLimit(1)
                        } else if !appState.lastResponse.isEmpty {
                            Text("Siap bos")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        } else {
                            Text("Kacung")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 12)
                    .frame(width: wingWidth, height: notchHeight)
                    .opacity(appState.isVisibleOnScreen ? 1.0 : 0.0)
                    .offset(x: appState.isVisibleOnScreen ? 0 : 35)

                    // Center Gap (Physical Webcam Notch Cutout)
                    Color.clear
                        .frame(width: notchWidth, height: notchHeight)

                    // Right Wing: strictly pure white wave visualizer, or dropdown button when finished
                    HStack(spacing: 6) {
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
                                appState.cancelAutoDismiss()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                    appState.isOutputExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: appState.isOutputExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 26, height: 18)
                                .background(Color.white.opacity(isHoveringRight ? 0.25 : 0.16))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .onHover { h in
                                isHoveringRight = h
                                if h {
                                    appState.cancelAutoDismiss()
                                }
                            }
                        }
                    }
                    .padding(.trailing, 12)
                    .frame(width: wingWidth, height: notchHeight)
                    .opacity(appState.isVisibleOnScreen ? 1.0 : 0.0)
                    .offset(x: appState.isVisibleOnScreen ? 0 : -35)
                }
                .frame(height: notchHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !appState.lastResponse.isEmpty {
                        appState.cancelAutoDismiss()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            appState.isOutputExpanded.toggle()
                        }
                    }
                }

                // Expanded Output Dropdown Card (revealed when dropdown is clicked)
                if appState.isOutputExpanded && !appState.lastResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Output")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))

                            Spacer()

                            Button(action: {
                                appState.cancelAutoDismiss()
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
                                        .font(.system(size: 9.5, weight: .medium))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(5)
                                .foregroundColor(hasCopied ? .green : .white)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                    appState.isOutputExpanded = false
                                }
                                appState.scheduleAutoDismiss(delay: 4.0)
                            }) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(4)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        if !promptText.isEmpty {
                            Text("Prompt: \(promptText)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(2)
                        }

                        ScrollView(.vertical, showsIndicators: true) {
                            Text(appState.lastResponse)
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(.white)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineSpacing(3)
                        }
                        .frame(maxHeight: 160)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(width: appState.isVisibleOnScreen ? activeWidth : notchWidth)
            .clipped()
            .background(
                DynamicIslandShape(cornerRadius: 12, hasNotch: appState.notchTopInset > 0)
                    .fill(Color.black)
            )
            .overlay(
                DynamicIslandBorderShape(cornerRadius: 12, hasNotch: appState.notchTopInset > 0)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 4)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: appState.isVisibleOnScreen)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: appState.isOutputExpanded)
            .onHover { hovering in
                if hovering {
                    appState.cancelAutoDismiss()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            isInputFocused = true
        }
    }
}
