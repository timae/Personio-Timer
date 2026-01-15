import Foundation

// MARK: - API Response Wrappers

/// Generic Personio API response wrapper.
struct PersonioResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: PersonioError?
}

struct PersonioError: Decodable {
    let code: Int?
    let message: String?
}

// MARK: - Authentication

struct AuthResponse: Decodable {
    let token: String
}

// MARK: - Attendance Models

/// Attendance entry from Personio API.
struct Attendance: Decodable {
    let id: Int
    let attributes: AttendanceAttributes

    struct AttendanceAttributes: Decodable {
        let employee: Int
        let date: String          // "YYYY-MM-DD"
        let startTime: String     // "HH:mm"
        let endTime: String?      // "HH:mm" or null if open
        let breakMinutes: Int

        enum CodingKeys: String, CodingKey {
            case employee
            case date
            case startTime = "start_time"
            case endTime = "end_time"
            case breakMinutes = "break"
        }
    }
}

/// Request body for creating attendance entries.
struct CreateAttendanceRequest: Encodable {
    let attendances: [AttendanceEntry]

    struct AttendanceEntry: Encodable {
        let employee: Int
        let date: String          // "YYYY-MM-DD"
        let startTime: String     // "HH:mm"
        let endTime: String?      // "HH:mm" - optional, omit to leave entry open
        let breakMinutes: Int
        let comment: String

        enum CodingKeys: String, CodingKey {
            case employee
            case date
            case startTime = "start_time"
            case endTime = "end_time"
            case breakMinutes = "break"
            case comment
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(employee, forKey: .employee)
            try container.encode(date, forKey: .date)
            try container.encode(startTime, forKey: .startTime)
            // Only encode endTime if it has a value
            if let endTime = endTime {
                try container.encode(endTime, forKey: .endTime)
            }
            try container.encode(breakMinutes, forKey: .breakMinutes)
            try container.encode(comment, forKey: .comment)
        }
    }
}

/// Response when creating attendance entries.
struct CreateAttendanceResponse: Decodable {
    let id: [Int]?
    let message: String?
}

/// Request body for updating (patching) an attendance entry.
struct UpdateAttendanceRequest: Encodable {
    let endTime: String       // "HH:mm"
    let breakMinutes: Int

    enum CodingKeys: String, CodingKey {
        case endTime = "end_time"
        case breakMinutes = "break"
    }
}

// MARK: - Computed Properties

extension Attendance {
    /// Returns the duration in minutes (excluding break).
    var durationMinutes: Int {
        guard let end = attributes.endTime else { return 0 }
        return TimeUtils.durationMinutes(
            start: attributes.startTime,
            end: end,
            breakMinutes: attributes.breakMinutes
        )
    }

    /// Returns true if this attendance is still open (no end time).
    var isOpen: Bool {
        return attributes.endTime == nil || attributes.endTime?.isEmpty == true
    }
}

// MARK: - API Error Types

enum PersonioAPIError: Error, LocalizedError {
    case noCredentials
    case invalidCredentials
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case tokenExpired
    case notConfigured
    case attendanceNotFound
    case overlapDetected

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No API credentials configured"
        case .invalidCredentials:
            return "Invalid API credentials"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Personio API"
        case .apiError(let message):
            return "API error: \(message)"
        case .tokenExpired:
            return "Authentication token expired"
        case .notConfigured:
            return "Employee ID not configured"
        case .attendanceNotFound:
            return "Attendance entry not found"
        case .overlapDetected:
            return "Overlapping attendance detected"
        }
    }
}
