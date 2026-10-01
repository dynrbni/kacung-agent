import SwiftUI
import AppKit

/// Visual language for the Lofly desktop app.
///
/// Typography is the system font, which is SF Pro on macOS. No font is ever
/// named explicitly, so the app follows the user's system appearance and
/// accessibility text-size settings instead of fighting them.
///
/// Spacing is a small fixed scale rather than free-form padding, which is what
/// keeps the layout reading as a native macOS utility rather than a dashboard.
public enum LoflyTheme {

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
        public static let small: CGFloat = 6
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 12
        public static let xl: CGFloat = 22
        public static let pill: CGFloat = 999
    }

    public static let sidebarWidth: CGFloat = 240
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

    public static var composerBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    public static var chatBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    public static var userBubbleBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? NSColor(white: 0.28, alpha: 1.0) : NSColor(white: 0.90, alpha: 1.0)
        }))
    }

    public static var userBubbleBorder: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? NSColor(white: 0.38, alpha: 0.8) : NSColor(white: 0.78, alpha: 0.8)
        }))
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

    /// Skill permission uses the same colour vocabulary the rest of the app
    /// already uses: neutral, then needs-attention, then destructive.
    public static func color(for permission: SkillPermissionLevel) -> Color {
        switch permission {
        case .safe: return .secondary
        case .sensitive: return .orange
        case .dangerous: return .red
        }
    }

    public static func symbol(for permission: SkillPermissionLevel) -> String {
        switch permission {
        case .safe: return "eye"
        case .sensitive: return "hand.raised"
        case .dangerous: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Shared building blocks

/// Hairline separator matching the macOS sidebar/content rhythm.
public struct LoflySeparator: View {
    private let axis: Axis

    public init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    public var body: some View {
        Rectangle()
            .fill(LoflyTheme.separator)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
    }
}

/// Section heading used across the secondary screens.
public struct LoflySectionHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(LoflyTheme.label(LoflyTheme.Size.caption))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.4)
    }
}

/// Status pill. Reserved for state that the user must notice — never decoration.
public struct LoflyStatusPill: View {
    private let text: String
    private let color: Color
    private let symbol: String?

    public init(text: String, color: Color, symbol: String? = nil) {
        self.text = text
        self.color = color
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: LoflyTheme.Space.xs) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: LoflyTheme.Size.caption))
            }
            Text(text)
                .font(LoflyTheme.label(LoflyTheme.Size.caption))
        }
        .foregroundStyle(color)
        .padding(.horizontal, LoflyTheme.Space.s)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }
}

/// "Soon" marker for features that ship later. Deliberately quiet: it marks
/// unavailable things without inviting a click.
public struct LoflySoonBadge: View {
    public init() {}

    public var body: some View {
        Text("Soon")
            .font(LoflyTheme.label(LoflyTheme.Size.caption))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel("Coming soon")
    }
}

/// Compact search field for the sidebar history list.
public struct LoflySidebarSearchField: View {
    @Binding var text: String

    public init(text: Binding<String>) {
        _text = text
    }

    public var body: some View {
        HStack(spacing: LoflyTheme.Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: LoflyTheme.Size.caption))
                .foregroundStyle(.tertiary)
            TextField("Search chats", text: $text)
                .textFieldStyle(.plain)
                .font(LoflyTheme.body(LoflyTheme.Size.callout))
                .accessibilityLabel("Search chats")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: LoflyTheme.Size.caption))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, LoflyTheme.Space.s)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                .fill(LoflyTheme.subtleFill.opacity(0.4))
        )
        .padding(.horizontal, LoflyTheme.Space.m)
        .padding(.top, LoflyTheme.Space.xs)
    }
}

/// Grouped section header for sidebar content areas (e.g. Chats).
public struct LoflySidebarHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(LoflyTheme.label(LoflyTheme.Size.caption))
            .foregroundStyle(.secondary)
    }
}

/// One sidebar row, shared by every navigation item and every history entry.
///
/// Geometry, hover and selection live here so the rows cannot drift apart:
/// a sidebar whose rows disagree about padding reads as assembled by hand.
/// Rows without a symbol start their text at the icon column's left edge,
/// which is why history titles line up with the nav symbols rather than the
/// nav labels.
public struct LoflySidebarRow<Content: View>: View {
    private let title: String
    private let symbol: String?
    private let isSelected: Bool
    private let content: Content
    private let action: () -> Void

    @State private var isHovering = false

    public init(
        _ title: String,
        symbol: String? = nil,
        isSelected: Bool = false,
        @ViewBuilder trailing: () -> Content = { EmptyView() },
        action: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.isSelected = isSelected
        self.content = trailing()
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14))
                        .frame(width: 18)
                        .foregroundStyle(isSelected ? LoflyTheme.accent : Color.secondary)
                }
                Text(title)
                    .font(.system(size: 13.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.88))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                content
            }
            .padding(.horizontal, 10)
            .frame(height: symbol != nil ? 36 : 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(background)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Selection outranks hover, matching ChatGPT's neutral elevated pill background.
    private var background: Color {
        if isSelected { return Color.primary.opacity(0.12) }
        if isHovering { return Color.primary.opacity(0.06) }
        return .clear
    }
}
