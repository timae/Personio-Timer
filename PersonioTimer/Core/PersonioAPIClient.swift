import Foundation
import os.log

/// HTTP client for Personio API.
/// Handles authentication, token caching, and attendance CRUD operations.
actor PersonioAPIClient {

    static let shared = PersonioAPIClient()

    private let session: URLSession
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersonioTimer", category: "PersonioAPIClient")

    private var baseURL: String {
        LocalStateStore.shared.apiBaseURL
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Authentication

    /// Authenticates with Personio and returns a token.
    /// Uses cached token if still valid.
    func authenticate() async throws -> String {
        // Check cache first
        if let cached = await TokenCache.shared.getToken() {
            return cached
        }

        // Load credentials from Keychain
        guard let credentials = KeychainStore.shared.loadCredentials() else {
            throw PersonioAPIError.noCredentials
        }

        logger.info("Authenticating with Personio API")

        let url = URL(string: "\(baseURL)/v1/auth")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": credentials.clientId,
            "client_secret": credentials.clientSecret
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PersonioAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw PersonioAPIError.invalidCredentials
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Auth failed: \(errorMessage)")
            throw PersonioAPIError.apiError(errorMessage)
        }

        let decoded = try JSONDecoder().decode(PersonioResponse<AuthResponse>.self, from: data)

        guard decoded.success, let authData = decoded.data else {
            throw PersonioAPIError.apiError(decoded.error?.message ?? "Authentication failed")
        }

        // Cache the token
        await TokenCache.shared.setToken(authData.token)
        logger.info("Authentication successful")

        return authData.token
    }

    /// Validates stored credentials by attempting authentication.
    func validateCredentials() async throws -> Bool {
        // Clear cached token to force fresh auth
        await TokenCache.shared.clearToken()

        do {
            _ = try await authenticate()
            return true
        } catch PersonioAPIError.invalidCredentials {
            return false
        }
    }

    // MARK: - Attendance Operations

    /// Creates a new attendance entry.
    /// - Parameters:
    ///   - employeeId: The employee ID
    ///   - date: Date string in "YYYY-MM-DD" format
    ///   - startTime: Start time in "HH:mm" format
    ///   - endTime: End time in "HH:mm" format, or nil to leave entry open
    /// - Returns: The created attendance ID
    func createAttendance(
        employeeId: Int,
        date: String,
        startTime: String,
        endTime: String? = nil,
        breakMinutes: Int = 0
    ) async throws -> Int {
        let token = try await authenticate()

        logger.info("Creating attendance for \(date) \(startTime)-\(endTime ?? "open")")

        let url = URL(string: "\(baseURL)/v1/company/attendances")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = CreateAttendanceRequest(
            attendances: [
                .init(
                    employee: employeeId,
                    date: date,
                    startTime: startTime,
                    endTime: endTime,
                    breakMinutes: breakMinutes,
                    comment: "PersonioTimer"
                )
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequest(request, token: token)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PersonioAPIError.invalidResponse
        }

        // Handle overlap error (Personio typically returns 400 or 409)
        if httpResponse.statusCode == 400 || httpResponse.statusCode == 409 {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            if errorBody.lowercased().contains("overlap") {
                throw PersonioAPIError.overlapDetected
            }
            throw PersonioAPIError.apiError(errorBody)
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PersonioAPIError.apiError(errorMessage)
        }

        let decoded = try JSONDecoder().decode(PersonioResponse<CreateAttendanceResponse>.self, from: data)

        guard decoded.success, let responseData = decoded.data, let ids = responseData.id, !ids.isEmpty else {
            throw PersonioAPIError.apiError(decoded.error?.message ?? "Failed to create attendance")
        }

        let attendanceId = ids[0]
        logger.info("Attendance created with ID \(attendanceId)")
        return attendanceId
    }

    /// Updates an existing attendance entry's end time.
    func updateAttendance(
        attendanceId: Int,
        endTime: String,
        breakMinutes: Int = 0
    ) async throws {
        let token = try await authenticate()

        logger.info("Updating attendance \(attendanceId) with end time \(endTime)")

        let url = URL(string: "\(baseURL)/v1/company/attendances/\(attendanceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = UpdateAttendanceRequest(endTime: endTime, breakMinutes: breakMinutes)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequest(request, token: token)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PersonioAPIError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw PersonioAPIError.attendanceNotFound
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PersonioAPIError.apiError(errorMessage)
        }

        logger.info("Attendance \(attendanceId) updated successfully")
    }

    /// Deletes an attendance entry.
    func deleteAttendance(attendanceId: Int) async throws {
        let token = try await authenticate()

        logger.info("Deleting attendance \(attendanceId)")

        let url = URL(string: "\(baseURL)/v1/company/attendances/\(attendanceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request, token: token)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PersonioAPIError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw PersonioAPIError.attendanceNotFound
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PersonioAPIError.apiError(errorMessage)
        }

        logger.info("Attendance \(attendanceId) deleted")
    }

    /// Fetches attendances for a specific employee and date range.
    func getAttendances(
        employeeId: Int,
        startDate: String,
        endDate: String
    ) async throws -> [Attendance] {
        let token = try await authenticate()

        logger.debug("Fetching attendances for employee \(employeeId) from \(startDate) to \(endDate)")

        var components = URLComponents(string: "\(baseURL)/v1/company/attendances")!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate),
            URLQueryItem(name: "employees[]", value: String(employeeId))
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request, token: token)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PersonioAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PersonioAPIError.apiError(errorMessage)
        }

        let decoded = try JSONDecoder().decode(PersonioResponse<[Attendance]>.self, from: data)

        guard decoded.success, let attendances = decoded.data else {
            throw PersonioAPIError.apiError(decoded.error?.message ?? "Failed to fetch attendances")
        }

        logger.debug("Fetched \(attendances.count) attendance(s)")
        return attendances
    }

    /// Fetches today's attendances for the configured employee.
    func getTodayAttendances(employeeId: Int) async throws -> [Attendance] {
        let today = TimeUtils.todayDateString
        return try await getAttendances(employeeId: employeeId, startDate: today, endDate: today)
    }

    // MARK: - Private Helpers

    /// Performs a request with automatic retry on token expiry.
    private func performRequest(_ request: URLRequest, token: String) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await session.data(for: request)

            // Check for token expiry
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                logger.info("Token expired, refreshing...")
                await TokenCache.shared.clearToken()
                _ = try await authenticate()

                // Retry with new token
                var retryRequest = request
                let newToken = try await authenticate()
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                return try await session.data(for: retryRequest)
            }

            return (data, response)
        } catch let error as URLError {
            throw PersonioAPIError.networkError(error)
        }
    }
}
