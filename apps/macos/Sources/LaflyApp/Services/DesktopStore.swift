import Foundation
import SwiftUI
import Combine

/// Presentation state for the desktop app.
///
/// Reads from `AppState.shared` and `AgentClient.shared` — the same singletons
/// the notch uses — so this is a view over the agent, never a second one. It
/// holds no agent logic of its own.
@MainActor
public final class DesktopStore: ObservableObject {

    // Connection + agent state, mirrored from the shared singletons.
    @Published public private(set) var isConnected = false
    @Published public private(set) var agentState: AssistantState = .idle
    @Published public private(set) var liveTranscript: String = ""

    // Conversations
    @Published public private(set) var conversations: [ConversationSummary] = []
    @Published public private(set) var selectedConversationId: String?
    @Published public private(set) var messages: [ConversationMessage] = []
    @Published public var composerText: String = ""

    // Tasks
    @Published public private(set) var tasks: [TaskSnapshot] = []
    @Published public private(set) var activeTask: TaskSnapshot?

    // Control center data
    @Published public private(set) var integrations: [IntegrationDescriptor] = []
    @Published public private(set) var memory: [MemoryItem] = []
    @Published public private(set) var activity: [ActivityEntry] = []
    @Published public private(set) var settings: LaflySettings = .default
    @Published public private(set) var account: AccountSession = AccountSession(
        signedIn: false, displayName: nil, storage: "none", updatedAt: nil
    )

    @Published public private(set) var isSending = false
    @Published public private(set) var banner: String?

    /// Bumped whenever a message arrives so the transcript view can scroll.
    @Published public private(set) var scrollTrigger = UUID()

    private let appState: AppState
    private let client: AgentClient
    private var cancellables = Set<AnyCancellable>()
    private var didBind = false

    /// Defaults are resolved lazily because `AppState` and `AgentClient` are
    /// main-actor isolated singletons.
    public init(appState: AppState? = nil, client: AgentClient? = nil) {
        let resolvedAppState = appState ?? AppState.shared
        let resolvedClient = client ?? AgentClient.shared

        self.appState = resolvedAppState
        self.client = resolvedClient
        self.isConnected = resolvedAppState.isConnected
        self.agentState = resolvedAppState.state
        self.liveTranscript = resolvedAppState.liveTranscript
    }

    /// Wires the shared event streams exactly once.
    public func bind() {
        guard !didBind else { return }
        didBind = true

        appState.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.isConnected = value }
            .store(in: &cancellables)

        appState.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.agentState = value }
            .store(in: &cancellables)

        appState.$liveTranscript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.liveTranscript = value }
            .store(in: &cancellables)

        // Live task updates arrive over the same socket the notch uses.
        client.onTaskUpdate = { [weak self] task in
            Task { @MainActor in self?.applyTaskUpdate(task) }
        }

        // Permission changes are already tracked by AppState; reflect them.
        appState.$isAccessibilityGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Tasks

    private func applyTaskUpdate(_ task: TaskSnapshot) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.insert(task, at: 0)
        }
        if task.isRunning {
            activeTask = task
        } else if activeTask?.id == task.id {
            activeTask = nil
        }
        NotificationService.shared.notifyTask(
            task,
            isForeground: NSApp.isActive
        )
    }

    public func refreshTasks() {
        client.listTasks { [weak self] result in
            if case .success(let list) = result {
                self?.tasks = list
                self?.activeTask = list.first(where: { $0.isRunning })
            }
        }
    }

    public func cancelActiveTask() {
        guard let task = activeTask else { return }
        // Cancel through the same path the notch uses.
        appState.cancelCurrentTask()
        client.cancelTask(id: task.id)
    }

    // MARK: - Conversations

    public func refreshConversations(search: String? = nil) {
        client.listConversations(search: search) { [weak self] result in
            if case .success(let list) = result {
                self?.conversations = list
            }
        }
    }

    public func newConversation() {
        client.createConversation { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let conversation):
                self.messages = []
                self.selectedConversationId = conversation.id
                self.refreshConversations()
            case .failure(let error):
                self.banner = error.localizedDescription
            }
        }
    }

    public func selectConversation(_ id: String) {
        selectedConversationId = id
        client.loadConversation(id: id) { [weak self] result in
            if case .success(let conversation) = result {
                self?.messages = conversation.messages
                self?.scrollTrigger = UUID()
            }
        }
    }

    public func renameConversation(_ id: String, to title: String) {
        client.renameConversation(id: id, title: title) { [weak self] result in
            if case .success(let conversation) = result {
                self?.conversations = self?.conversations.map {
                    var summary = $0
                    if summary.id == conversation.id { summary.title = conversation.title }
                    return summary
                } ?? []
            }
        }
    }

    public func deleteConversation(_ id: String) {
        client.deleteConversation(id: id) { [weak self] _ in
            guard let self else { return }
            if self.selectedConversationId == id {
                self.selectedConversationId = nil
                self.messages = []
            }
            self.refreshConversations()
        }
    }

    // MARK: - Sending

    /// Sends the composer text down the same endpoint the notch's typed input
    /// uses, so text and voice converge on one pipeline.
    public func send() {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        composerText = ""
        isSending = true

        // Optimistically show the user turn; the server echoes the stored copy back.
        messages.append(
            ConversationMessage(id: "local-\(UUID().uuidString)", role: .user, text: text, createdAt: Date().timeIntervalSince1970 * 1000, taskId: nil, error: nil)
        )
        scrollTrigger = UUID()

        client.sendQuery(text: text) { [weak self] result in
            guard let self else { return }
            self.isSending = false

            switch result {
            case .success(let response):
                if self.selectedConversationId == nil {
                    self.selectedConversationId = nil
                }
                self.messages.append(
                    ConversationMessage(
                        id: "local-\(UUID().uuidString)",
                        role: .assistant,
                        text: response.text,
                        createdAt: Date().timeIntervalSince1970 * 1000,
                        taskId: nil,
                        error: response.error
                    )
                )
                self.scrollTrigger = UUID()
                self.refreshConversations()
                self.refreshTasks()
            case .failure(let error):
                self.banner = error.localizedDescription
                self.messages.append(
                    ConversationMessage(
                        id: "local-\(UUID().uuidString)",
                        role: .assistant,
                        text: "Gue nggak bisa menghubungi agent server.",
                        createdAt: Date().timeIntervalSince1970 * 1000,
                        taskId: nil,
                        error: error.localizedDescription
                    )
                )
                self.scrollTrigger = UUID()
            }
        }
    }

    public func cancelCurrentTask() {
        cancelActiveTask()
    }

    // MARK: - Control center

    public func refreshIntegrations() {
        client.listIntegrations { [weak self] result in
            if case .success(let list) = result { self?.integrations = list }
        }
    }

    public func refreshMemory() {
        client.listMemory { [weak self] result in
            if case .success(let list) = result { self?.memory = list }
        }
    }

    public func updateMemory(_ item: MemoryItem, content: String) {
        client.updateMemory(id: item.id, content: content) { [weak self] _ in
            self?.refreshMemory()
        }
    }

    public func deleteMemory(_ item: MemoryItem) {
        client.deleteMemory(id: item.id) { [weak self] _ in
            self?.refreshMemory()
        }
    }

    public func clearAllMemory() {
        client.clearMemory { [weak self] _ in
            self?.refreshMemory()
        }
    }

    public func refreshActivity() {
        client.listActivity { [weak self] result in
            if case .success(let list) = result { self?.activity = list }
        }
    }

    public func refreshSettings() {
        client.loadSettings { [weak self] result in
            if case .success(let value) = result { self?.settings = value }
        }
    }

    public func updateSettings(_ patch: [String: Any]) {
        client.updateSettings(patch) { [weak self] result in
            if case .success(let value) = result { self?.settings = value }
        }
    }

    public func refreshAccount() {
        client.loadAccount { [weak self] result in
            if case .success(let value) = result { self?.account = value }
        }
    }

    public func signIn(name: String) {
        client.signIn(displayName: name) { [weak self] result in
            switch result {
            case .success(let session): self?.account = session
            case .failure(let error): self?.banner = error.localizedDescription
            }
        }
    }

    public func signOut() {
        client.signOut { [weak self] result in
            if case .success(let session) = result { self?.account = session }
        }
    }

    public func dismissBanner() {
        banner = nil
    }
}
