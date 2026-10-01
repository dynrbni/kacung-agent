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
    public static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    public static func callout(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    public static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .medium) }
    public static func caption(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    public static func mono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }

    /// Standard sizes across Lofly
    public enum Size {
        public static let pageGreeting: CGFloat = 34
        public static let windowTitle: CGFloat = 14.5
        public static let sectionTitle: CGFloat = 13.5
        public static let body: CGFloat = 14.5
        public static let callout: CGFloat = 13
        public static let caption: CGFloat = 11.5
        public static let metadata: CGFloat = 11
        public static let metric: CGFloat = 22
    }

    // MARK: - Spacing System (Multiples of 4/8)

    public enum Space {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 48
    }

    // MARK: - Radius System

    public enum Radius {
        public static let small: CGFloat = 6
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 12
        public static let container: CGFloat = 18
        public static let composer: CGFloat = 18
        public static let pill: CGFloat = 999
    }

    public static let sidebarWidth: CGFloat = 240
    public static let taskPanelWidth: CGFloat = 280
    public static let contentMaxWidth: CGFloat = 720

    // MARK: - Colour System (Black / Graphite Dark Theme)
    //
    // Tuned dark graphite layers avoid pure #000000 flatness while creating
    // quiet, calm depth. Restrained indigo-violet accent is reserved strictly
    // for active states, selected indicators, and the logo mark.

    public static let accent = Color(red: 0.44, green: 0.40, blue: 0.90)

    public static let windowBackground = Color(red: 0.094, green: 0.094, blue: 0.094) // #181818
    public static let sidebarBackground = Color(red: 0.082, green: 0.082, blue: 0.082) // #151515
    public static let contentBackground = Color(red: 0.094, green: 0.094, blue: 0.094) // #181818
    public static let surface = Color(red: 0.118, green: 0.118, blue: 0.118) // #1E1E1E
    public static let surfaceElevated = Color(red: 0.133, green: 0.133, blue: 0.133) // #222222
    public static let composerBackground = Color(red: 0.125, green: 0.125, blue: 0.125) // #202020

    public static let primaryText = Color(white: 0.93)
    public static let secondaryText = Color(white: 0.60)
    public static let tertiaryText = Color(white: 0.38)

    public static let borderSubtle = Color.white.opacity(0.065)
    public static let borderMedium = Color.white.opacity(0.10)
    public static let separator = Color.white.opacity(0.06)

    public static let subtleFill = Color.white.opacity(0.04)
    public static let hoverFill = Color.white.opacity(0.05)
    public static let selectedFill = Color.white.opacity(0.085)

    public static var chatBackground: Color { contentBackground }

    public static let userBubbleBackground = Color(red: 0.141, green: 0.141, blue: 0.141) // #242424
    public static let userBubbleBorder = Color.white.opacity(0.075)

    public static func color(for status: TaskStatus) -> Color {
        switch status {
        case .completed: return Color(red: 0.35, green: 0.78, blue: 0.48)
        case .failed: return Color(red: 0.92, green: 0.36, blue: 0.34)
        case .cancelled: return secondaryText
        case .requiresForeground: return Color(red: 0.95, green: 0.65, blue: 0.25)
        case .waiting, .queued, .planning, .executing, .pending, .inProgress: return accent
        }
    }

    public static func color(for step: TaskStep) -> Color {
        switch step.state {
        case .completed: return Color(red: 0.35, green: 0.78, blue: 0.48)
        case .failed: return Color(red: 0.92, green: 0.36, blue: 0.34)
        case .cancelled: return secondaryText
        case .running: return accent
        case .pending, .skipped: return secondaryText
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
        case .success: return Color(red: 0.35, green: 0.78, blue: 0.48)
        case .failure: return Color(red: 0.92, green: 0.36, blue: 0.34)
        case .cancelled: return secondaryText
        case .simulated: return Color(red: 0.95, green: 0.65, blue: 0.25)
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
        case .connected: return Color(red: 0.35, green: 0.78, blue: 0.48)
        case .notConnected: return secondaryText
        case .needsAuthentication: return Color(red: 0.95, green: 0.65, blue: 0.25)
        case .needsPermission: return Color(red: 0.95, green: 0.65, blue: 0.25)
        case .error: return Color(red: 0.92, green: 0.36, blue: 0.34)
        }
    }

    public static func label(for integration: IntegrationStatus) -> String {
        switch integration {
        case .connected: return "Connected"
        case .notConnected: return "Not Connected"
        case .needsAuthentication: return "Needs Auth"
        case .needsPermission: return "Needs Permission"
        case .error: return "Error"
        }
    }

    public static func color(for permission: SkillPermissionLevel) -> Color {
        switch permission {
        case .safe: return secondaryText
        case .sensitive: return Color(red: 0.95, green: 0.65, blue: 0.25)
        case .dangerous: return Color(red: 0.92, green: 0.36, blue: 0.34)
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

/// Section heading used across the app (Recents, Integrations, etc.)
public struct LoflySectionHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(LoflyTheme.tertiaryText)
            .textCase(.uppercase)
            .kerning(0.6)
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
            .foregroundStyle(LoflyTheme.secondaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(LoflyTheme.subtleFill, in: Capsule())
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
                .font(.system(size: 12))
                .foregroundStyle(LoflyTheme.tertiaryText)
            TextField("Search chats...", text: $text)
                .textFieldStyle(.plain)
                .font(LoflyTheme.body(12.5))
                .foregroundStyle(LoflyTheme.primaryText)
                .accessibilityLabel("Search chats")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(LoflyTheme.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: LoflyTheme.Radius.small, style: .continuous)
                .fill(LoflyTheme.subtleFill)
        )
    }
}

/// Grouped section header for sidebar content areas (e.g. Chats).
public struct LoflySidebarHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(LoflyTheme.tertiaryText)
            .kerning(0.5)
    }
}

/// One sidebar row, shared by every navigation item and every history entry.
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
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 13.5))
                        .frame(width: 18)
                        .foregroundStyle(isSelected ? LoflyTheme.accent : LoflyTheme.secondaryText)
                }
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? LoflyTheme.primaryText : LoflyTheme.secondaryText.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                content
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: LoflyTheme.Radius.medium, style: .continuous)
                    .fill(background)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Subtle graphite highlight for selected item, no bright blue fill
    private var background: Color {
        if isSelected { return LoflyTheme.selectedFill }
        if isHovering { return LoflyTheme.hoverFill }
        return .clear
    }
}
