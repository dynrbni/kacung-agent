import SwiftUI
import AppKit

/// Integrations screen, reached from the sidebar. The list is the screen: no
/// summary cards around it, and nothing to click that only pretends to connect.
struct IntegrationsView: View {
    @EnvironmentObject private var store: DesktopStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeader(
                title: "Integrations",
                subtitle: "What Lofly can reach right now.",
                trailing: {
                    Button {
                        store.refreshIntegrations()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh integrations")
                    .accessibilityLabel("Refresh integrations")
                }
            )

            LoflySeparator()

            ScrollView {
                VStack(alignment: .leading, spacing: LoflyTheme.Space.m) {
                    IntegrationsList()

                    Text("Status comes from a live check on this Mac. Connections are configured in the agent server's .env; credentials never reach the app.")
                        .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(LoflyTheme.Space.l)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onAppear { store.refreshIntegrations() }
    }
}

/// Integration status list, grouped by category. Screen-agnostic so it can be
/// embedded anywhere the statuses are needed.
struct IntegrationsList: View {
    @EnvironmentObject private var store: DesktopStore

    private var grouped: [(IntegrationCategory, [IntegrationDescriptor])] {
        IntegrationCategory.allCases.compactMap { category in
            let items = store.integrations.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        if store.integrations.isEmpty {
            Text(store.isConnected ? "No integrations reported. Pull to refresh." : "Connect to the agent server to see integration status.")
                .font(LoflyTheme.body(LoflyTheme.Size.callout))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, LoflyTheme.Space.s)
        } else {
            VStack(alignment: .leading, spacing: LoflyTheme.Space.l) {
                ForEach(grouped, id: \.0) { category, items in
                    VStack(alignment: .leading, spacing: LoflyTheme.Space.s) {
                        LoflySectionHeader(category.title)
                        VStack(spacing: LoflyTheme.Space.s) {
                            ForEach(items) { item in
                                IntegrationRow(item: item)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One integration card. Status comes from the server's runtime probe, so it
/// can never claim a connection that does not exist. No credential is shown.
struct IntegrationRow: View {
    let item: IntegrationDescriptor

    var body: some View {
        HStack(alignment: .top, spacing: LoflyTheme.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(LoflyTheme.body(LoflyTheme.Size.body))
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: LoflyTheme.Space.s)
            LoflyStatusPill(
                text: LoflyTheme.label(for: item.status),
                color: LoflyTheme.color(for: item.status)
            )
        }
        .padding(LoflyTheme.Space.m)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                .fill(LoflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                .stroke(LoflyTheme.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name): \(LoflyTheme.label(for: item.status))")
    }
}

/// Permissions list, reused by the Settings General tab.
struct PermissionsList: View {
    @EnvironmentObject private var store: DesktopStore
    @State private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: LoflyTheme.Space.s) {
            permissionRow(
                title: "Microphone",
                detail: "Records your voice when you hold Control + Option.",
                granted: appState.isMicrophoneGranted,
                setting: "microphone",
                canRequest: true
            )
            permissionRow(
                title: "Speech Recognition",
                detail: "Transcribes what you say into text.",
                granted: appState.isSpeechGranted,
                setting: "speech",
                canRequest: true
            )
            permissionRow(
                title: "Accessibility",
                detail: "Lets Lofly move the mouse, type, and drive apps.",
                granted: appState.isAccessibilityGranted,
                setting: "accessibility",
                canRequest: true
            )
            permissionRow(
                title: "Automation",
                detail: "Required to control WhatsApp and other apps.",
                granted: appState.isAccessibilityGranted,
                setting: "automation",
                canRequest: false
            )
        }
        .onAppear { appState.checkPermissions() }
    }

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        setting: String,
        canRequest: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: LoflyTheme.Space.m) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: LoflyTheme.Size.body))
                .foregroundStyle(granted ? .green : .orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LoflyTheme.body(LoflyTheme.Size.body))
                Text(detail)
                    .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !granted {
                    Text(canRequest ? "If macOS asks, choose Allow. To change it later, open System Settings." : "Grant Accessibility to enable app automation.")
                        .font(LoflyTheme.caption(LoflyTheme.Size.caption))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: LoflyTheme.Space.s)

            HStack(spacing: LoflyTheme.Space.s) {
                if canRequest && !granted {
                    Button("Allow") {
                        if setting == "accessibility" {
                            PermissionManager.shared.requestAccessibilityPermission()
                        } else if setting == "microphone" {
                            PermissionManager.shared.requestMicrophonePermission { _ in
                                appState.checkPermissions()
                            }
                        } else {
                            PermissionManager.shared.requestSpeechRecognitionPermission { _ in
                                appState.checkPermissions()
                            }
                        }
                    }
                    .controlSize(.small)
                }
                Button("Open Settings") {
                    PermissionManager.shared.openSystemSettings(for: setting)
                }
                .controlSize(.small)
            }
        }
        .padding(LoflyTheme.Space.m)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                .fill(LoflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                .stroke(LoflyTheme.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(granted ? "granted" : "not granted")")
    }
}

/// Permissions screen. Reuses the existing `PermissionManager` rather than
/// re-implementing any TCC check.
struct PermissionsView: View {
    @EnvironmentObject private var store: DesktopStore
    @State private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeader(
                title: "Permissions",
                subtitle: "macOS access Lofly needs to hear and act.",
                trailing: {
                    Button {
                        appState.checkPermissions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh permissions")
                    .accessibilityLabel("Refresh permissions")
                }
            )

            LoflySeparator()

            ScrollView {
                VStack(alignment: .leading, spacing: LoflyTheme.Space.m) {
                    PermissionsList()
                }
                .padding(LoflyTheme.Space.l)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onAppear { appState.checkPermissions() }
    }
}
