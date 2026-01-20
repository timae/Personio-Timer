import Foundation
import os.log

/// Persists non-sensitive app state to UserDefaults.
/// Stores: employee ID, running attendance state, and user preferences.
final class LocalStateStore {

    static let shared = LocalStateStore()

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersonioTimer", category: "LocalStateStore")

    private init() {}

    // MARK: - Keys

    private enum Keys {
        static let employeeId = "employeeId"
        static let runningAttendanceId = "runningAttendanceId"
        static let runningStartTime = "runningStartTime"
        static let apiBaseURL = "apiBaseURL"
        static let timezone = "timezone"
        static let showTimerInMenubar = "showTimerInMenubar"
        static let menubarDisplayMode = "menubarDisplayMode"
        static let autoRestartAfterMidnight = "autoRestartAfterMidnight"
    }

    // MARK: - Display Mode

    enum MenubarDisplayMode: String, CaseIterable {
        case currentSession = "currentSession"
        case todayTotal = "todayTotal"

        var description: String {
            switch self {
            case .currentSession: return "Current session"
            case .todayTotal: return "Today's total"
            }
        }
    }

    // MARK: - Employee ID

    var employeeId: Int? {
        get {
            let value = defaults.integer(forKey: Keys.employeeId)
            return value > 0 ? value : nil
        }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.employeeId)
                logger.debug("Employee ID saved")
            } else {
                defaults.removeObject(forKey: Keys.employeeId)
                logger.debug("Employee ID cleared")
            }
        }
    }

    // MARK: - Running Attendance State

    /// The ID of the currently running attendance entry (if any).
    var runningAttendanceId: Int? {
        get {
            let value = defaults.integer(forKey: Keys.runningAttendanceId)
            return value > 0 ? value : nil
        }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.runningAttendanceId)
                logger.debug("Running attendance ID saved")
            } else {
                defaults.removeObject(forKey: Keys.runningAttendanceId)
                logger.debug("Running attendance ID cleared")
            }
        }
    }

    /// The start time of the currently running attendance (ISO8601 string).
    var runningStartTime: Date? {
        get {
            guard let isoString = defaults.string(forKey: Keys.runningStartTime) else {
                return nil
            }
            return ISO8601DateFormatter().date(from: isoString)
        }
        set {
            if let date = newValue {
                let isoString = ISO8601DateFormatter().string(from: date)
                defaults.set(isoString, forKey: Keys.runningStartTime)
                logger.debug("Running start time saved")
            } else {
                defaults.removeObject(forKey: Keys.runningStartTime)
                logger.debug("Running start time cleared")
            }
        }
    }

    /// Clears all running attendance state.
    func clearRunningState() {
        runningAttendanceId = nil
        runningStartTime = nil
        logger.info("Running state cleared")
    }

    /// Saves running attendance state atomically.
    func saveRunningState(attendanceId: Int, startTime: Date) {
        runningAttendanceId = attendanceId
        runningStartTime = startTime
        logger.info("Running state saved")
    }

    /// Checks if there is a running attendance.
    var hasRunningAttendance: Bool {
        return runningAttendanceId != nil && runningStartTime != nil
    }

    // MARK: - Preferences

    var apiBaseURL: String {
        get {
            return defaults.string(forKey: Keys.apiBaseURL) ?? "https://api.personio.de"
        }
        set {
            defaults.set(newValue, forKey: Keys.apiBaseURL)
        }
    }

    var timezone: String {
        get {
            return defaults.string(forKey: Keys.timezone) ?? "Europe/Zurich"
        }
        set {
            defaults.set(newValue, forKey: Keys.timezone)
        }
    }

    var showTimerInMenubar: Bool {
        get {
            // Default to true if not set
            if defaults.object(forKey: Keys.showTimerInMenubar) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.showTimerInMenubar)
        }
        set {
            defaults.set(newValue, forKey: Keys.showTimerInMenubar)
        }
    }

    var menubarDisplayMode: MenubarDisplayMode {
        get {
            guard let rawValue = defaults.string(forKey: Keys.menubarDisplayMode),
                  let mode = MenubarDisplayMode(rawValue: rawValue) else {
                return .currentSession  // Default to current session
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.menubarDisplayMode)
        }
    }

    var autoRestartAfterMidnight: Bool {
        get {
            return defaults.bool(forKey: Keys.autoRestartAfterMidnight)
        }
        set {
            defaults.set(newValue, forKey: Keys.autoRestartAfterMidnight)
        }
    }

    // MARK: - Configuration Check

    /// Returns true if all required configuration is present.
    var isConfigured: Bool {
        return KeychainStore.shared.hasCredentials && employeeId != nil
    }
}
