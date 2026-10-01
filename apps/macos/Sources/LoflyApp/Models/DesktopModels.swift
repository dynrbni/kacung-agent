import Foundation

/// Which detail surface the desktop window is showing. Chat is the default;
/// the rest are reached from the sidebar.
public enum DesktopSurface: String, Hashable {
    case chat
    case activity
    case integrations
    case skills
    case account
    case settings
}

public enum MessageRating: String, Codable {
    case thumbsUp
    case thumbsDown
}

// MARK: - Voice session

/// A transient push-to-talk capture shown in the desktop chat panel while the
/// desktop window is open (the notch stays hidden then). In-memory only: the
/// query goes to the server marked as voice, so it never lands in the
/// conversation history on either side.
public struct VoiceSession: Codable, Hashable {
    public var transcript: String
    public var isRunning: Bool
    public var responseText: String?
    public var errorMessage: String?

    public init(transcript: String) {
        self.transcript = transcript
        self.isRunning = true
        self.responseText = nil
        self.errorMessage = nil
    }
}

// MARK: - Task lifecycle

/// Mirrors the server's TaskStatus. The notch and the desktop app both render
/// whatever the server reports, so neither owns a private state machine.
public enum TaskStatus: String, Codable, CaseIterable {
    case queued
    case planning
    case executing
    case waiting
    case completed
    case failed
    case cancelled
    case requiresForeground = "requires_foreground"
    case pending
    case inProgress = "in_progress"

    public var title: String {
        switch self {
        case .queued: return "Queued"
        case .planning: return "Planning"
        case .executing: return "Executing"
        case .waiting: return "Waiting"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .requiresForeground: return "Needs Attention"
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        }
    }

    /// States in which the task can still make progress.
    public var isActive: Bool {
        switch self {
        case .queued, .planning, .executing, .waiting, .requiresForeground, .pending, .inProgress:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }

    public var isTerminal: Bool { !isActive }
}

public enum TaskStepState: String, Codable {
    case pending
    case running
    case completed
    case failed
    case cancelled
    case skipped
}

public struct TaskStep: Codable, Identifiable, Hashable {
    public let id: String
    public var label: String
    public var state: TaskStepState
    public var toolName: String?
    public var error: String?
}

public struct TaskSnapshot: Codable, Identifiable, Hashable {
    public let id: String
    public var conversationId: String
    public var title: String
    public var status: TaskStatus
    public var steps: [TaskStep]
    public var createdAt: Double
    public var updatedAt: Double

    public var isRunning: Bool { status.isActive }
}

// MARK: - Conversations

public enum ConversationMessageRole: String, Codable {
    case user
    case assistant
    case system
}

public struct ConversationMessage: Codable, Identifiable, Hashable {
    public let id: String
    public var role: ConversationMessageRole
    public var text: String
    public var createdAt: Double
    public var taskId: String?
    public var error: String?
}

/// Sidebar entry. Message bodies are omitted by the server to keep the list
/// payload small.
public struct ConversationSummary: Codable, Identifiable, Hashable {
    public let id: String
    public var title: String
    public var createdAt: Double
    public var updatedAt: Double
    public var taskReferences: [String]
    public var messageCount: Int
}

public struct Conversation: Codable, Identifiable, Hashable {
    public let id: String
    public var title: String
    public var createdAt: Double
    public var updatedAt: Double
    public var messages: [ConversationMessage]
    public var taskReferences: [String]
}

// MARK: - Activity

public enum ActivityStatus: String, Codable {
    case success
    case failure
    case cancelled
    case simulated

    public var title: String {
        switch self {
        case .success: return "Done"
        case .failure: return "Failed"
        case .cancelled: return "Cancelled"
        case .simulated: return "Simulated"
        }
    }
}

public struct ActivityEntry: Codable, Identifiable, Hashable {
    public let id: String
    public var timestamp: Double
    public var taskId: String?
    public var conversationId: String?
    public var label: String
    public var toolName: String?
    public var status: ActivityStatus
    public var detail: String?
    /// True when the runtime policy suppressed the side effect.
    public var dryRun: Bool
}

// MARK: - Integrations

public enum IntegrationStatus: String, Codable {
    case connected
    case notConnected = "not_connected"
    case needsAuthentication = "needs_authentication"
    case needsPermission = "needs_permission"
    case error
}

public enum IntegrationCategory: String, Codable, CaseIterable {
    case messaging
    case browser
    case music
    case developer
    case system

    public var title: String {
        switch self {
        case .messaging: return "Messaging"
        case .browser: return "Browser"
        case .music: return "Music"
        case .developer: return "Developer"
        case .system: return "System"
        }
    }
}

public struct IntegrationDescriptor: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var category: IntegrationCategory
    public var status: IntegrationStatus
    public var detail: String?
}

// MARK: - Skills

/// How much a skill can affect the Mac. Mirrors the server's PermissionLevel,
/// so the label on screen is the same contract the executor enforces.
public enum SkillPermissionLevel: String, Codable, CaseIterable, Identifiable {
    case safe = "SAFE"
    case sensitive = "SENSITIVE"
    case dangerous = "DANGEROUS"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .safe: return "Safe"
        case .sensitive: return "Needs confirmation"
        case .dangerous: return "Dangerous"
        }
    }

    /// Why a skill sits in this group. Taken from the documented meaning of
    /// each level, not guessed per tool.
    public var detail: String {
        switch self {
        case .safe: return "Read-only. Runs without asking."
        case .sensitive: return "Changes files or sends messages. Lofly asks first."
        case .dangerous: return "Can delete or reconfigure. Lofly always asks."
        }
    }

    /// An unknown level is shown as the most restricted one, so a new server
    /// value can never be presented as harmless.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SkillPermissionLevel(rawValue: raw) ?? .dangerous
    }
}

/// One capability reported by the agent's tool registry.
public struct SkillDescriptor: Codable, Identifiable, Hashable {
    public let id: String
    /// How the capability reads on screen: "Open an app", never the activity
    /// log's past tense ("Opened application") and never the raw tool name.
    public var name: String
    /// The first sentence of the description, whole. Optional so an older agent
    /// server still renders a complete row instead of decoding to nothing.
    public var summary: String?
    /// Full description, shown in the tooltip.
    public var description: String
    public var permissionLevel: SkillPermissionLevel
    /// Raw side-effect class from the tool's own declaration. Kept as a string
    /// so a level added later never breaks decoding.
    public var sideEffect: String
    /// True while the execution policy simulates the action.
    public var simulated: Bool

    public var sideEffectTitle: String {
        switch sideEffect {
        case "none": return "Read-only"
        case "reversible": return "Reversible"
        case "external": return "Reaches others"
        case "destructive": return "Destructive"
        default: return sideEffect
        }
    }
}

// MARK: - Memory

public enum MemoryCategory: String, Codable, CaseIterable, Identifiable {
    case preference
    case fact
    case project
    case instruction

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .preference: return "Preferences"
        case .fact: return "Facts"
        case .project: return "Project"
        case .instruction: return "Instructions"
        }
    }

    public var symbol: String {
        switch self {
        case .preference: return "slider.horizontal.3"
        case .fact: return "text.bubble"
        case .project: return "folder"
        case .instruction: return "list.bullet"
        }
    }
}

public struct MemoryItem: Codable, Identifiable, Hashable {
    public let id: String
    public var category: MemoryCategory
    public var content: String
    public var createdAt: Double
    public var updatedAt: Double
}

// MARK: - Account & settings

public struct AccountSession: Codable, Hashable {
    public var signedIn: Bool
    public var displayName: String?
    /// Where a token would live. The token itself is never sent to the client.
    public var storage: String
    public var updatedAt: Double?
}

public enum LatencyPreference: String, Codable, CaseIterable, Identifiable {
    case fast
    case balanced
    case advanced

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fast: return "Fast"
        case .balanced: return "Balanced"
        case .advanced: return "Advanced"
        }
    }

    public var detail: String {
        switch self {
        case .fast: return "Lowest latency. Best for short commands."
        case .balanced: return "Default. Responsive without sacrificing correctness."
        case .advanced: return "Highest reasoning effort. Best for complex tasks."
        }
    }
}

public struct LoflySettings: Codable, Hashable {
    public var hotkeyEnabled: Bool
    public var hotkeyFallback: String
    public var languages: [String]
    public var latencyPreference: LatencyPreference
    public var confirmSensitiveActions: Bool
    public var confirmDangerousActions: Bool
    public var backgroundExecution: Bool
    public var notificationsEnabled: Bool
    public var logRetentionDays: Int
    public var debugMode: Bool

    public static let `default` = LoflySettings(
        hotkeyEnabled: true,
        hotkeyFallback: "Control+Option",
        languages: ["id", "en"],
        latencyPreference: .balanced,
        confirmSensitiveActions: true,
        confirmDangerousActions: true,
        backgroundExecution: true,
        notificationsEnabled: true,
        logRetentionDays: 7,
        debugMode: false
    )
}
