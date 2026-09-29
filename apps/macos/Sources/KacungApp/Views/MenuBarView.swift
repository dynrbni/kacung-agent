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

                Text("Kacung Assistant")
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
                    Text("⌥ Space")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button(action: {
                appState.startListening()
            }) {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("Activate Voice (Woi Kacung)")
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
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: appState.isAccessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(appState.isAccessibilityGranted ? .green : .orange)
                    Text("Accessibility Control")
                        .font(.caption)

                    if !appState.isAccessibilityGranted {
                        Spacer()
                        Button("Grant") {
                            PermissionManager.shared.openSystemSettings(for: "accessibility")
                        }
                        .font(.caption2)
                    }
                }

                HStack {
                    Image(systemName: appState.isMicrophoneGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(appState.isMicrophoneGranted ? .green : .orange)
                    Text("Microphone Access")
                        .font(.caption)

                    if !appState.isMicrophoneGranted {
                        Spacer()
                        Button("Grant") {
                            PermissionManager.shared.openSystemSettings(for: "microphone")
                        }
                        .font(.caption2)
                    }
                }
            }

            Divider()

            Button("Quit Kacung") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding(12)
        .frame(width: 240)
    }
}
