import SwiftUI
import AppKit

/// Settings screen, opened from the sidebar footer gear. Sections are cards
/// on a scrollable page rather than a rigid form, with a segmented pill bar
/// for the category tabs. Advanced diagnostics stay on their own tab.
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
            screenHeader(title: "Settings", subtitle: "Configure how Lofly behaves.")

            tabBar
                .padding(.horizontal, LoflyTheme.Space.l)
                .padding(.bottom, LoflyTheme.Space.s)

            LoflySeparator()

            ScrollView {
                content
                    .padding(LoflyTheme.Space.l)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .onAppear {
            store.refreshSettings()
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: LoflyTheme.Space.xs) {
            ForEach(Tab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.system(size: LoflyTheme.Size.caption))
                        Text(item.title)
                            .font(LoflyTheme.label(LoflyTheme.Size.callout))
                    }
                    .padding(.horizontal, LoflyTheme.Space.m)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                            .fill(tab == item ? LoflyTheme.accent.opacity(0.16) : .clear)
                    )
                    .foregroundStyle(tab == item ? LoflyTheme.accent : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
            Spacer()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general: generalTab
        case .voice: voiceTab
        case .models: modelsTab
        case .agent: agentTab
        case .privacy: privacyTab
        case .advanced: advancedTab
        }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.m) {
            settingsCard(title: "Language", symbol: "globe") {
                Picker("Languages", selection: Binding(
                    get: { store.settings.languages },
                    set: { store.updateSettings(["languages": $0]) }
                )) {
                    Text("Indonesian").tag(["id"])
                    Text("English").tag(["en"])
                    Text("Indonesian + English").tag(["id", "en"])
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            settingsCard(title: "Assistant", symbol: "sparkles") {
                LabeledContent("Name", value: store.agentState == .idle ? "Lofly" : store.agentState.title)
                LabeledContent("Wake phrase", value: "Woi Lofly")
            }

            settingsCard(title: "Permissions", symbol: "lock.shield") {
                PermissionsList()
            }
        }
    }

    private var voiceTab: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.m) {
            settingsCard(title: "Push to talk", symbol: "mic.fill") {
                Toggle("Enable hotkey", isOn: Binding(
                    get: { store.settings.hotkeyEnabled },
                    set: { store.updateSettings(["hotkeyEnabled": $0]) }
                ))
                LabeledContent("Shortcut", value: store.settings.hotkeyFallback)
                Text("Hold Control + Option to listen, release to submit. With the desktop open the capture appears in the chat panel; otherwise the notch handles it.")
                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            settingsCard(title: "Microphone", symbol: "waveform") {
                LabeledContent("Status", value: appState.isMicrophoneGranted ? "Granted" : "Not granted")
                LabeledContent("Speech recognition", value: appState.isSpeechGranted ? "Granted" : "Not granted")
                Button("Re-check permissions") { appState.checkPermissions() }
            }
        }
        .onAppear { appState.checkPermissions() }
    }

    private var modelsTab: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.m) {
            settingsCard(title: "Latency", symbol: "speedometer") {
                Picker("Preference", selection: Binding(
                    get: { store.settings.latencyPreference },
                    set: { store.updateSettings(["latencyPreference": $0.rawValue]) }
                )) {
                    ForEach(LatencyPreference.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(store.settings.latencyPreference.detail)
                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
            }

            settingsCard(title: "Provider", symbol: "cpu") {
                Text("The model provider is configured in the agent server's .env file. Changing it here is intentionally not supported.")
                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var agentTab: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.m) {
            settingsCard(title: "Confirmation policy", symbol: "checkmark.shield") {
                Toggle("Confirm sensitive actions", isOn: Binding(
                    get: { store.settings.confirmSensitiveActions },
                    set: { store.updateSettings(["confirmSensitiveActions": $0]) }
                ))
                Toggle("Confirm dangerous actions", isOn: Binding(
                    get: { store.settings.confirmDangerousActions },
                    set: { store.updateSettings(["confirmDangerousActions": $0]) }
                ))
            }

            settingsCard(title: "Execution", symbol: "bolt") {
                Toggle("Keep running in background", isOn: Binding(
                    get: { store.settings.backgroundExecution },
                    set: { store.updateSettings(["backgroundExecution": $0]) }
                ))
                Text("Closing this window keeps tasks running. The menu bar notch stays available as the quick surface.")
                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.m) {
            settingsCard(title: "Notifications", symbol: "bell") {
                Toggle("Notify on task events", isOn: Binding(
                    get: { store.settings.notificationsEnabled },
                    set: { store.updateSettings(["notificationsEnabled": $0]) }
                ))
            }

            settingsCard(title: "Data", symbol: "externaldrive") {
                Picker("Log retention", selection: Binding(
                    get: { store.settings.logRetentionDays },
                    set: { store.updateSettings(["logRetentionDays": $0]) }
                )) {
                    Text("1 day").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            settingsCard(title: "Memory", symbol: "brain") {
                HStack {
                    Text("Manage what Lofly remembers.")
                        .font(LoflyTheme.body(LoflyTheme.Size.callout))
                        .foregroundStyle(.secondary)
                    Spacer()
                    LoflySoonBadge()
                }
            }

            settingsCard(title: "Credentials", symbol: "key") {
                LabeledContent("Storage", value: KeychainStore.has("session") ? "macOS Keychain" : "Not stored")
                Text("API keys and tokens are never written to chat history, task history, or logs.")
                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.m) {
            settingsCard(title: "Diagnostics", symbol: "stethoscope") {
                Toggle("Debug mode", isOn: Binding(
                    get: { store.settings.debugMode },
                    set: { store.updateSettings(["debugMode": $0]) }
                ))
                LabeledContent("Agent server", value: store.isConnected ? "Connected" : "Disconnected")
                LabeledContent("Endpoint", value: "127.0.0.1:3847")
                LabeledContent("WebSocket", value: store.isConnected ? "Open" : "Closed")
            }

            settingsCard(title: "Safe testing", symbol: "shield.lefthalf.filled") {
                Text("Development runs are dry-run by default. The desktop app cannot bypass the runtime safety policy, so a simulated action is always reported as simulated.")
                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            settingsCard(title: "Reset", symbol: "arrow.counterclockwise") {
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
    }

    // MARK: - Card building block

    /// One rounded section card with an icon + title header. The card carries
    /// the visual weight so the content inside stays plain controls.
    private func settingsCard<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.m) {
            HStack(spacing: LoflyTheme.Space.s) {
                Image(systemName: symbol)
                    .font(.system(size: LoflyTheme.Size.callout))
                    .foregroundStyle(LoflyTheme.accent)
                    .frame(width: 18)
                Text(title)
                    .font(LoflyTheme.label(LoflyTheme.Size.sectionTitle))
            }

            VStack(alignment: .leading, spacing: LoflyTheme.Space.s) {
                content()
            }
        }
        .padding(LoflyTheme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.large, style: .continuous)
                .fill(LoflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.large, style: .continuous)
                .stroke(LoflyTheme.separator, lineWidth: 0.5)
        )
    }
}

/// Account screen, reachable from the sidebar footer.
struct AccountView: View {
    @EnvironmentObject private var store: DesktopStore
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeader(title: "Account", subtitle: "Lofly's local session.")

            LoflySeparator()

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
                    Text("There is no remote identity provider behind Lofly yet. This records local sign-in state only; any future token is stored in the macOS keychain and never sent to the client.")
                        .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
        }
        .onAppear { store.refreshAccount() }
    }
}
