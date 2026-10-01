import SwiftUI
import AppKit

/// Visual language for the Lafly desktop app.
///
/// Typography is the system font, which is SF Pro on macOS. No font is ever
/// named explicitly, so the app follows the user's system appearance and
/// accessibility text-size settings instead of fighting them.
///
/// Spacing is a small fixed scale rather than free-form padding, which is what
/// keeps the layout reading as a native macOS utility rather than a dashboard.
public enum LaflyTheme {

    // MARK: - Typography (SF Pro)

    public static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    public static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    public static func body(_ size: CGFloat) -> Font { .system(size: size) }
    public static func callout(_ size: CGFloat) -> Font { .system(size: size) }
    public static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .medium) }
    public static func caption(_ size: CGFloat) -> Font { .system(size: size) }
    public static func mono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }

    /// Sizes used across the app, so screens agree with each other.
    public enum Size {
        public static let windowTitle: CGFloat = 15
        public static let sectionTitle: CGFloat = 13
        public static let body: CGFloat = 13
        public static let callout: CGFloat = 12
        public static let caption: CGFloat = 11
        public static let metric: CGFloat = 22
    }

    // MARK: - Spacing

    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let small: CGFloat = 5
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 12
    }

    public static let sidebarWidth: CGFloat = 232
    public static let taskPanelWidth: CGFloat = 280

    // MARK: - Colour
    //
    // Accent is used sparingly: for the active state and for genuinely
    // meaningful status. Everything else relies on native separators and
    // materials so the app does not read as neon or glass-heavy.

    public static let accent = Color.accentColor

    public static var separator: Color {
        Color(nsColor: .separatorColor)
    }

    public static var surface: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    public static var subtleFill: Color {
        Color(nsColor: .quaternaryLabelColor)
    }

    public static func color(for status: TaskStatus) -> Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        case .requiresForeground: return .orange
        case .waiting, .queued, .planning, .executing, .pending, .inProgress: return .accentColor
        }
    }

    public static func color(for step: TaskStep) -> Color {
        switch step.state {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        case .running: return .accentColor
        case .pending, .skipped: return .secondary
        }
    }

    public static func symbol(for step: TaskStep) -> String {
        switch step.state {
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        case .running: return "circle.dotted"
        case .pending: return "circle"
        case .skipped: return "slash.circle"
        }
    }

    public static func color(for activity: ActivityStatus) -> Color {
        switch activity {
        case .success: return .green
        case .failure: return .red
        case .cancelled: return .secondary
        case .simulated: return .orange
        }
    }

    public static func symbol(for activity: ActivityStatus) -> String {
        switch activity {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        case .simulated: return "shield.lefthalf.filled"
        }
    }

    public static func color(for integration: IntegrationStatus) -> Color {
        switch integration {
        case .connected: return .green
        case .notConnected: return .secondary
        case .needsAuthentication: return .orange
        case .needsPermission: return .orange
        case .error: return .red
        }
    }

    public static func label(for integration: IntegrationStatus) -> String {
        switch integration {
        case .connected: return "Connected"
        case .notConnected: return "Not Connected"
        case .needsAuthentication: return "Needs Authentication"
        case .needsPermission: return "Needs Permission"
        case .error: return "Error"
        }
    }
}

// MARK: - Shared building blocks

/// Hairline separator matching the macOS sidebar/content rhythm.
public struct LaflySeparator: View {
    private let axis: Axis

    public init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    public var body: some View {
        Rectangle()
            .fill(LaflyTheme.separator)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
    }
}

/// Section heading used across the secondary screens.
public struct LaflySectionHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(LaflyTheme.label(LaflyTheme.Size.caption))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.4)
    }
}

/// Status pill. Reserved for state that the user must notice — never decoration.
public struct LaflyStatusPill: View {
    private let text: String
    private let color: Color
    private let symbol: String?

    public init(text: String, color: Color, symbol: String? = nil) {
        self.text = text
        self.color = color
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: LaflyTheme.Space.xs) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: LaflyTheme.Size.caption))
            }
            Text(text)
                .font(LaflyTheme.label(LaflyTheme.Size.caption))
        }
        .foregroundStyle(color)
        .padding(.horizontal, LaflyTheme.Space.s)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }
}
