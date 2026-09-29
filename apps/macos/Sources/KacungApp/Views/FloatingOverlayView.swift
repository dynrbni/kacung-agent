import SwiftUI

public struct FloatingOverlayView: View {
    @ObservedObject public var appState: AppState
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main Siri-like Pill Container
            VStack(spacing: 12) {
                // Header with status indicator
                HStack(spacing: 10) {
                    // Animated state icon
                    ZStack {
                        Circle()
                            .fill(stateColor.opacity(0.2))
                            .frame(width: 28, height: 28)

                        Circle()
                            .stroke(stateColor, lineWidth: 2)
                            .frame(width: 28, height: 28)
                            .scaleEffect(appState.state == .listening || appState.state == .thinking ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: appState.state)

                        Image(systemName: stateIconName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(stateColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("KACUNG")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)

                        Text(appState.state.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // Hotkey badge (development feature indicator)
                    Text("⌥ Space")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)

                    // Close / Hide button
                    Button(action: {
                        appState.hideOverlay()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }

                // Error Banner with System Settings helper
                if let error = appState.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .lineLimit(3)
                        Spacer()
                        Button("Settings") {
                            PermissionManager.shared.openSystemSettings(for: "microphone")
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(8)
                }

                // Audio waveform & live speech transcript when listening
                if appState.state == .listening {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            ForEach(0..<10) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 4, height: max(6, CGFloat(appState.audioLevel * 45.0) * (CGFloat(index % 4 + 1) * 0.35)))
                                    .animation(.easeOut(duration: 0.1), value: appState.audioLevel)
                            }
                        }
                        .frame(height: 24)

                        if !appState.liveTranscript.isEmpty {
                            Text("\"\(appState.liveTranscript)\"")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.cyan)
                                .lineLimit(3)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        } else {
                            Text("Bicara sekarang (contoh: \"Buka Safari\", \"Jam berapa sekarang\")...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Response / Output Card if available
                if !appState.lastResponse.isEmpty && appState.state != .listening {
                    VStack(alignment: .leading, spacing: 6) {
                        if !appState.liveTranscript.isEmpty {
                            Text(appState.liveTranscript)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        Text(appState.lastResponse)
                            .font(.system(size: 13))
                            .lineLimit(6)
                            .foregroundColor(.primary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }

                // Pending Confirmation Dialog inside overlay
                if let confirmation = appState.pendingConfirmation {
                    ConfirmationModalView(
                        request: confirmation,
                        onApprove: { appState.resolveConfirmation(id: confirmation.id, approved: true) },
                        onDeny: { appState.resolveConfirmation(id: confirmation.id, approved: false) }
                    )
                }

                // Input bar (Supports natural typing and voice toggle)
                HStack(spacing: 8) {
                    TextField(appState.state == .listening ? "Mendengarkan suara Anda..." : "Tanya atau suruh Kacung...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($isInputFocused)
                        .disabled(appState.state == .listening)
                        .onSubmit {
                            submitQuery()
                        }

                    if appState.state == .thinking || appState.state == .executing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(action: {
                            if appState.state == .listening {
                                appState.stopListening()
                            } else {
                                appState.startListening()
                            }
                        }) {
                            Image(systemName: appState.state == .listening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(appState.state == .listening ? .red : .accentColor)
                                .padding(4)
                        }
                        .buttonStyle(.plain)

                        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: submitQuery) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.15))
                .cornerRadius(8)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [stateColor.opacity(0.5), stateColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .frame(width: 380)
        .padding()
        .onAppear {
            isInputFocused = true
        }
    }

    private func submitQuery() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        appState.sendQuery(text: text)
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
