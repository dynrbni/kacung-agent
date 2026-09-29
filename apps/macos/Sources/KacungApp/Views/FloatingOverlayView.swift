import SwiftUI

public struct FloatingOverlayView: View {
    @ObservedObject public var appState: AppState
    @FocusState private var isInputFocused: Bool

    // Bar multipliers creating a natural audio frequency spectrum curve
    private let barMultipliers: [CGFloat] = [0.4, 0.7, 1.1, 1.6, 2.2, 2.5, 2.1, 1.7, 1.2, 0.8, 0.5]

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
                            .fill(stateColor.opacity(0.25))
                            .frame(width: 32, height: 32)

                        Circle()
                            .stroke(stateColor, lineWidth: 2)
                            .frame(width: 32, height: 32)
                            .scaleEffect(appState.state == .listening ? (1.0 + CGFloat(appState.audioLevel * 0.4)) : (appState.state == .thinking ? 1.15 : 1.0))
                            .animation(.easeOut(duration: 0.15), value: appState.audioLevel)

                        Image(systemName: stateIconName)
                            .font(.system(size: 14, weight: .bold))
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
                            let type = error.lowercased().contains("speech") ? "speech" : "microphone"
                            PermissionManager.shared.openSystemSettings(for: type)
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
                    VStack(spacing: 10) {
                        // Dynamic organic audio waveform
                        HStack(alignment: .center, spacing: 5) {
                            ForEach(0..<barMultipliers.count, id: \.self) { index in
                                let multiplier = barMultipliers[index]
                                let baseHeight: CGFloat = 6.0
                                let dynamicHeight: CGFloat = baseHeight + (CGFloat(appState.audioLevel) * 32.0 * multiplier)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.cyan, Color.blue, Color.purple],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 4.5, height: min(dynamicHeight, 38.0))
                                    .animation(.easeOut(duration: 0.1), value: appState.audioLevel)
                            }
                        }
                        .frame(height: 38)
                        .padding(.vertical, 4)

                        // Real-time transcribed text display
                        if !appState.liveTranscript.isEmpty {
                            Text("\"\(appState.liveTranscript)\"")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.cyan)
                                .lineLimit(3)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        } else {
                            Text("Bicara sekarang (contoh: \"Buka Safari\", \"Jam berapa\")...")
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
                    TextField(
                        appState.state == .listening && appState.inputText.isEmpty ? "Mendengarkan suara Anda..." : "Tanya atau suruh Kacung...",
                        text: $appState.inputText
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isInputFocused)
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
                            ZStack {
                                if appState.state == .listening {
                                    Circle()
                                        .fill(Color.red.opacity(0.2))
                                        .frame(width: 26, height: 26)
                                        .scaleEffect(1.0 + CGFloat(appState.audioLevel * 0.3))
                                        .animation(.easeInOut(duration: 0.2), value: appState.audioLevel)
                                }
                                Image(systemName: appState.state == .listening ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(appState.state == .listening ? .red : .accentColor)
                            }
                            .padding(4)
                        }
                        .buttonStyle(.plain)

                        if !appState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                                    colors: [stateColor.opacity(0.6), stateColor.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
        }
        .frame(width: 380)
        .padding()
        .onAppear {
            isInputFocused = true
        }
    }

    private func submitQuery() {
        let text = appState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if appState.state == .listening {
            appState.stopListening()
        }
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
