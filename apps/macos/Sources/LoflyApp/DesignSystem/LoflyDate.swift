import Foundation

/// Every timestamp the desktop app renders goes through here.
///
/// The sidebar history and the task cards both answer "when?", so a second copy
/// of the relative formatter is exactly how the two would start disagreeing.
/// The absolute day and clock labels live here for the same reason: one owner,
/// one format. Server timestamps are epoch milliseconds.
enum LoflyDate {

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }()

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Relative label, e.g. "2h ago". Used by the chat list and task cards.
    static func relative(milliseconds: Double) -> String {
        relativeFormatter.localizedString(
            for: date(milliseconds),
            relativeTo: Date()
        )
    }

    /// Day heading for the activity log, e.g. "Wednesday 1 October".
    static func day(milliseconds: Double) -> String {
        dayFormatter.string(from: date(milliseconds))
    }

    /// Clock label for an activity entry, e.g. "11:04".
    static func clock(milliseconds: Double) -> String {
        clockFormatter.string(from: date(milliseconds))
    }

    private static func date(_ milliseconds: Double) -> Date {
        Date(timeIntervalSince1970: milliseconds / 1000)
    }
}
