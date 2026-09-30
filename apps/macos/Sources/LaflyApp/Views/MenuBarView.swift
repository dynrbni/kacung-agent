import SwiftUI

public struct MenuBarView: View {
    @ObservedObject public var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Circle()
                    .fill(appState.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text("Lafly Assistant")
                    .font(.headline)

                Spacer()

                Text(appState.state.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Quick Actions
            Button(action: {
                appState.toggleOverlay()
            }) {
                HStack {
                    Image(systemName: "macwindow.on.rectangle")
                    Text("Toggle Assistant Overlay")
                    Spacer()
                    Text("⌃⌥")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button(action: {
                appState.startListening()
            }) {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("Activate Voice (Woi Lafly)")
                }
            }
            .buttonStyle(.plain)

            Button(action: {
                appState.resetConversation()
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset Conversation")
                }
            }
            .buttonStyle(.plain)

            Divider()

            // Permissions Check
            VStack(alignment: .leading, spacing: 6) {
                Text("System Permissions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fontWeight(.bold)

                HStack {
                    Image(systemName: appState.isMicrophoneGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(appState.isMicrophoneGranted ? .green : .orange)
                    Text("Microphone")
                        .font(.caption)

                    if !appState.isMicrophoneGranted {
                        Spacer()
                        Button("Grant") {
                            PermissionManager.shared.openSystemSettings(for: "microphone")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                appState.checkPermissions()
                            }
                        }
                        .font(.caption2)
                    }
                }

                HStack {
                    Image(systemName: appState.isSpeechGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(appState.isSpeechGranted ? .green : .orange)
                    Text("Speech Recognition")
                        .font(.caption)

                    if !appState.isSpeechGranted {
                        Spacer()
                        Button("Grant") {
                            PermissionManager.shared.openSystemSettings(for: "speech")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                appState.checkPermissions()
                            }
                        }
                        .font(.caption2)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: appState.isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(appState.isAccessibilityGranted ? .green : .orange)
                        Text("Accessibility Control")
                            .font(.caption)

                        Spacer()

                        if !appState.isAccessibilityGranted {
                            Button("Buka Settings") {
                                PermissionManager.shared.requestAccessibilityPermission()
                                PermissionManager.shared.openSystemSettings(for: "accessibility")
                                for delay in [0.5, 1.0, 2.0, 4.0] {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        appState.checkPermissions()
                                    }
                                }
                            }
                            .font(.caption2)
                        } else {
                            Text("Aktif")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !appState.isAccessibilityGranted {
                        Text("Jika sudah ON di System Settings, matikan lalu nyalakan lagi toggle Lafly agar macOS merefresh izin.")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)

                        Button(action: {
                            appState.checkPermissions()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.clockwise")
                                Text("Cek Status Izin")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }

            Divider()

            Button("Quit Lafly") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding(12)
        .frame(width: 270)
        .onAppear {
            appState.checkPermissions()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            appState.checkPermissions()
        }
    }
}
