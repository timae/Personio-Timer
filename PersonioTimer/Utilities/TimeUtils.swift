import Foundation

/// Timezone-aware time formatting utilities for Personio API.
/// All date/time operations use the configured timezone (default: Europe/Zurich).
enum TimeUtils {

    // MARK: - Timezone

    /// Returns the configured timezone.
    static var timezone: TimeZone {
        let identifier = LocalStateStore.shared.timezone
        return TimeZone(identifier: identifier) ?? TimeZone(identifier: "Europe/Zurich")!
    }

    /// Returns a Calendar configured with the app's timezone.
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        return cal
    }

    // MARK: - Personio API Formatting

    /// Formats a Date as "YYYY-MM-DD" for Personio API.
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }

    /// Formats a Date as "HH:mm" for Personio API.
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }

    /// Returns today's date string in "YYYY-MM-DD" format.
    static var todayDateString: String {
        return formatDate(Date())
    }

    // MARK: - Duration Formatting

    /// Formats a duration in seconds as "Xh Ym" for display.
    static func formatDuration(seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }

    /// Formats a duration in seconds as "HH:MM" for menubar display.
    static func formatDurationShort(seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    // MARK: - Midnight Calculations

    /// Returns the Date representing 23:59:59 on the same day as the given date.
    static func endOfDay(_ date: Date) -> Date {
        let cal = calendar
        var components = cal.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return cal.date(from: components) ?? date
    }

    /// Returns the Date representing 00:00:00 on the next day.
    static func startOfNextDay(_ date: Date) -> Date {
        let cal = calendar
        guard let nextDay = cal.date(byAdding: .day, value: 1, to: date) else {
            return date
        }
        return cal.startOfDay(for: nextDay)
    }

    /// Returns the number of seconds until midnight (23:59:59) for the given date.
    static func secondsUntilMidnight(from date: Date = Date()) -> TimeInterval {
        let midnight = endOfDay(date)
        return midnight.timeIntervalSince(date)
    }

    /// Checks if two dates are on the same calendar day (in the configured timezone).
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let cal = calendar
        return cal.isDate(date1, inSameDayAs: date2)
    }

    /// Checks if the given date is today (in the configured timezone).
    static func isToday(_ date: Date) -> Bool {
        return isSameDay(date, Date())
    }

    // MARK: - Parsing

    /// Parses a "HH:mm" time string on a given date.
    static func parseTime(_ timeString: String, on date: Date) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timezone

        guard let timeOnly = formatter.date(from: timeString) else {
            return nil
        }

        let cal = calendar
        let dateComponents = cal.dateComponents([.year, .month, .day], from: date)
        let timeComponents = cal.dateComponents([.hour, .minute], from: timeOnly)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = 0

        return cal.date(from: combined)
    }

    /// Parses a "YYYY-MM-DD" date string.
    static func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timezone
        return formatter.date(from: dateString)
    }

    // MARK: - Duration Between Times

    /// Calculates duration in minutes between two "HH:mm" time strings.
    static func durationMinutes(start: String, end: String, breakMinutes: Int = 0) -> Int {
        let referenceDate = Date()
        guard let startDate = parseTime(start, on: referenceDate),
              let endDate = parseTime(end, on: referenceDate) else {
            return 0
        }
        let totalSeconds = endDate.timeIntervalSince(startDate)
        let totalMinutes = Int(totalSeconds) / 60
        return max(0, totalMinutes - breakMinutes)
    }
}
