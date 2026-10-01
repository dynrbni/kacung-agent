import SwiftUI
import AppKit

/// Integrations screen. Status comes from the server's runtime probe, so it can
/// never claim a connection that does not exist. No credential is displayed.
struct IntegrationsView: View {
    @EnvironmentObject private var store: DesktopStore

    private var grouped: [(IntegrationCategory, [IntegrationDescriptor])] {
        IntegrationCategory.allCases.compactMap { category in
            let items = store.integrations.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            screenHeader(
                title: "Integrations",
                subtitle: "What Lafly can reach right now.",
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

            LaflySeparator()

            if store.integrations.isEmpty {
                emptyState(
                    "No integrations reported",
                    store.isConnected ? "Pull to refresh." : "Connect to the agent server to see integration status."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: LaflyTheme.Space.l) {
                        ForEach(grouped, id: \.0) { category, items in
                            VStack(alignment: .leading, spacing: LaflyTheme.Space.s) {
                                LaflySectionHeader(category.title)
                                ForEach(items) { item in
                                    IntegrationRow(item: item)
                                }
                            }
                        }
                    }
                    .padding(LaflyTheme.Space.l)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .onAppear { store.refreshIntegrations() }
    }
}

private struct IntegrationRow: View {
    let item: IntegrationDescriptor

    var body: some View {
        HStack(alignment: .top, spacing: LaflyTheme.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(LaflyTheme.body(LaflyTheme.Size.body))
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: LaflyTheme.Space.s)
            LaflyStatusPill(
                text: LaflyTheme.label(for: item.status),
                color: LaflyTheme.color(for: item.status)
            )
        }
        .padding(LaflyTheme.Space.m)
        .background(
            RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                .fill(LaflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                .stroke(LaflyTheme.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name): \(LaflyTheme.label(for: item.status))")
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
                subtitle: "macOS access Lafly needs to hear and act.",
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

            LaflySeparator()

            ScrollView {
                VStack(alignment: .leading, spacing: LaflyTheme.Space.m) {
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
                        detail: "Lets Lafly move the mouse, type, and drive apps.",
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
                .padding(LaflyTheme.Space.l)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
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
        HStack(alignment: .top, spacing: LaflyTheme.Space.m) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: LaflyTheme.Size.body))
                .foregroundStyle(granted ? .green : .orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LaflyTheme.body(LaflyTheme.Size.body))
                Text(detail)
                    .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !granted {
                    Text(canRequest ? "If macOS asks, choose Allow. To change it later, open System Settings." : "Grant Accessibility to enable app automation.")
                        .font(LaflyTheme.caption(LaflyTheme.Size.caption))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: LaflyTheme.Space.s)

            HStack(spacing: LaflyTheme.Space.s) {
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
        .padding(LaflyTheme.Space.m)
        .background(
            RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                .fill(LaflyTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LaflyTheme.Radius.medium, style: .continuous)
                .stroke(LaflyTheme.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(granted ? "granted" : "not granted")")
    }
}
