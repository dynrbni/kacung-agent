import SwiftUI
import AppKit

/// Settings screen, using a native tabbed toolbar rather than a sidebar of
/// preferences. Advanced diagnostics are kept on their own tab so they stay out
/// of the way of normal use.
struct SettingsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case general, voice, models, agent, privacy, advanced
        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .voice: return "Voice"
            case .models: return "AI / Models"
            case .agent: return "Agent"
            case .privacy: return "Privacy"
            case .advanced: return "Advanced"
            }
        }

        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .voice: return "mic"
            case .models: return "cpu"
            case .agent: return "square.stack.3d.up"
            case .privacy: return "hand.raised"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }

    @EnvironmentObject private var store: DesktopStore
    @State private var tab: Tab = .general
    @State private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeader(title: "Settings", subtitle: "Configure how Lafly behaves.")

            TabView(selection: $tab) {
                generalTab.tag(Tab.general)
                voiceTab.tag(Tab.voice)
                modelsTab.tag(Tab.models)
                agentTab.tag(Tab.agent)
                privacyTab.tag(Tab.privacy)
                advancedTab.tag(Tab.advanced)
            }
            .tabViewStyle(.automatic)
        }
        .onAppear { store.refreshSettings() }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Language") {
                Picker("Languages", selection: Binding(
                    get: { store.settings.languages },
                    set: { store.updateSettings(["languages": $0]) }
                )) {
                    Text("Indonesian").tag(["id"])
                    Text("English").tag(["en"])
                    Text("Indonesian + English").tag(["id", "en"])
                }
            }

            Section("Assistant") {
                LabeledContent("Name", value: store.agentState == .idle ? "Lafly" : store.agentState.title)
                LabeledContent("Wake phrase", value: "Woi Lafly")
            }

            Section("Permissions") {
                PermissionsView()
                    .frame(maxHeight: .infinity)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Voice

    private var voiceTab: some View {
        Form {
            Section("Push to talk") {
                Toggle("Enable hotkey", isOn: Binding(
                    get: { store.settings.hotkeyEnabled },
                    set: { store.updateSettings(["hotkeyEnabled": $0]) }
                ))
                LabeledContent("Shortcut", value: store.settings.hotkeyFallback)
                Text("Hold Control + Option to listen, release to submit. This is the same pipeline the notch uses.")
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
            }

            Section("Microphone") {
                LabeledContent("Status", value: appState.isMicrophoneGranted ? "Granted" : "Not granted")
                LabeledContent("Speech recognition", value: appState.isSpeechGranted ? "Granted" : "Not granted")
                Button("Re-check permissions") { appState.checkPermissions() }
            }
        }
        .formStyle(.grouped)
        .onAppear { appState.checkPermissions() }
    }

    // MARK: - Models

    private var modelsTab: some View {
        Form {
            Section("Latency") {
                Picker("Preference", selection: Binding(
                    get: { store.settings.latencyPreference },
                    set: { store.updateSettings(["latencyPreference": $0.rawValue]) }
                )) {
                    ForEach(LatencyPreference.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Text(store.settings.latencyPreference.detail)
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
            }

            Section("Provider") {
                Text("The model provider is configured in the agent server's .env file. Changing it here is intentionally not supported.")
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
                Button("View integrations") { store.refreshIntegrations() }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Agent

    private var agentTab: some View {
        Form {
            Section("Confirmation policy") {
                Toggle("Confirm sensitive actions", isOn: Binding(
                    get: { store.settings.confirmSensitiveActions },
                    set: { store.updateSettings(["confirmSensitiveActions": $0]) }
                ))
                Toggle("Confirm dangerous actions", isOn: Binding(
                    get: { store.settings.confirmDangerousActions },
                    set: { store.updateSettings(["confirmDangerousActions": $0]) }
                ))
            }

            Section("Execution") {
                Toggle("Keep running in background", isOn: Binding(
                    get: { store.settings.backgroundExecution },
                    set: { store.updateSettings(["backgroundExecution": $0]) }
                ))
                Text("Closing this window keeps tasks running. The menu bar notch stays available as the quick surface.")
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Privacy

    private var privacyTab: some View {
        Form {
            Section("Notifications") {
                Toggle("Notify on task events", isOn: Binding(
                    get: { store.settings.notificationsEnabled },
                    set: { store.updateSettings(["notificationsEnabled": $0]) }
                ))
            }

            Section("Data") {
                Picker("Log retention", selection: Binding(
                    get: { store.settings.logRetentionDays },
                    set: { store.updateSettings(["logRetentionDays": $0]) }
                )) {
                    Text("1 day").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
            }

            Section("Memory") {
                Button("Open memory") {
                    NotificationService.shared.notifyTaskCompleted("Open Memory from Settings > Privacy")
                }
                .disabled(true)
                Text("Manage what Lafly remembers from the Memory section.")
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
            }

            Section("Credentials") {
                LabeledContent("Storage", value: KeychainStore.has("session") ? "macOS Keychain" : "Not stored")
                Text("API keys and tokens are never written to chat history, task history, or logs.")
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section("Diagnostics") {
                Toggle("Debug mode", isOn: Binding(
                    get: { store.settings.debugMode },
                    set: { store.updateSettings(["debugMode": $0]) }
                ))
                LabeledContent("Agent server", value: store.isConnected ? "Connected" : "Disconnected")
                LabeledContent("Endpoint", value: "127.0.0.1:3847")
                LabeledContent("WebSocket", value: store.isConnected ? "Open" : "Closed")
            }

            Section("Safe testing") {
                Text("Development runs are dry-run by default. The desktop app cannot bypass the runtime safety policy, so a simulated action is always reported as simulated.")
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Reset") {
                Button("Reset settings to defaults") {
                    store.updateSettings([
                        "hotkeyEnabled": true,
                        "confirmSensitiveActions": true,
                        "confirmDangerousActions": true,
                        "backgroundExecution": true,
                        "notificationsEnabled": true,
                        "logRetentionDays": 7,
                        "debugMode": false,
                    ])
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Account screen, reachable from the sidebar footer.
struct AccountView: View {
    @EnvironmentObject private var store: DesktopStore
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeader(title: "Account", subtitle: "Lafly's local session.")

            LaflySeparator()

            Form {
                Section("Status") {
                    LabeledContent("Signed in", value: store.account.signedIn ? "Yes" : "No")
                    LabeledContent("Name", value: store.account.displayName ?? "—")
                    LabeledContent("Credential storage", value: store.account.storage)
                }

                Section {
                    if store.account.signedIn {
                        Button("Sign out", role: .destructive) { store.signOut() }
                    } else {
                        TextField("Display name", text: $name)
                        Button("Sign in") { store.signIn(name: name) }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    Text("There is no remote identity provider behind Lafly yet. This records local sign-in state only; any future token is stored in the macOS keychain and never sent to the client.")
                        .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
        }
        .onAppear { store.refreshAccount() }
    }
}
