import Foundation
import os.log

/// Business logic orchestrator for attendance tracking.
/// Manages start/stop operations, state recovery, and today's totals.
@MainActor
final class AttendanceService: ObservableObject {

    static let shared = AttendanceService()

    // MARK: - Published State

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var runningDuration: TimeInterval = 0
    @Published private(set) var todayTotal: TimeInterval = 0
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private Properties

    private let api = PersonioAPIClient.shared
    private let stateStore = LocalStateStore.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersonioTimer", category: "AttendanceService")

    private var timerTask: Task<Void, Never>?
    private var runningStartTime: Date?

    private init() {}

    // MARK: - Configuration Check

    var isConfigured: Bool {
        return stateStore.isConfigured
    }

    var employeeId: Int? {
        return stateStore.employeeId
    }

    // MARK: - Start Tracking

    /// Starts a new attendance tracking session.
    func start() async {
        guard !isRunning else {
            logger.warning("Already running, ignoring start request")
            return
        }

        guard let employeeId = stateStore.employeeId else {
            lastError = "Employee ID not configured"
            logger.error("Cannot start: employee ID not configured")
            return
        }

        isLoading = true
        lastError = nil

        do {
            let now = Date()
            let dateString = TimeUtils.formatDate(now)
            let startTime = TimeUtils.formatTime(now)

            // Check for existing open attendance today
            let existing = try await api.getTodayAttendances(employeeId: employeeId)
            if let openAttendance = existing.first(where: { $0.isOpen }) {
                logger.info("Found existing open attendance \(openAttendance.id), resuming")
                // Resume existing attendance
                stateStore.saveRunningState(attendanceId: openAttendance.id, startTime: now)
                startTimer(from: now)
                isRunning = true
                isLoading = false
                return
            }

            // Create new attendance without end time (leaves it open)
            let attendanceId = try await api.createAttendance(
                employeeId: employeeId,
                date: dateString,
                startTime: startTime
                // endTime omitted - entry stays open until stopped
            )

            // Persist state
            stateStore.saveRunningState(attendanceId: attendanceId, startTime: now)
            runningStartTime = now
            startTimer(from: now)
            isRunning = true

            logger.info("Tracking started: attendance \(attendanceId)")

        } catch {
            lastError = error.localizedDescription
            logger.error("Failed to start: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Stop Tracking

    /// Stops the current attendance tracking session.
    func stop() async {
        guard isRunning else {
            logger.warning("Not running, ignoring stop request")
            return
        }

        guard let attendanceId = stateStore.runningAttendanceId else {
            logger.error("No running attendance ID found")
            clearRunningState()
            return
        }

        isLoading = true
        lastError = nil

        do {
            let now = Date()
            let endTime = TimeUtils.formatTime(now)

            try await api.updateAttendance(attendanceId: attendanceId, endTime: endTime)

            clearRunningState()
            logger.info("Tracking stopped: attendance \(attendanceId)")

            // Refresh today's total
            await syncTodayTotal()

        } catch {
            lastError = error.localizedDescription
            logger.error("Failed to stop: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - State Recovery

    /// Attempts to recover running state after app restart.
    func recoverState() async {
        logger.info("Recovering state...")

        guard stateStore.hasRunningAttendance,
              let attendanceId = stateStore.runningAttendanceId,
              let startTime = stateStore.runningStartTime else {
            logger.info("No running state to recover")
            await syncTodayTotal()
            return
        }

        // Check if start time is from today
        guard TimeUtils.isToday(startTime) else {
            logger.warning("Persisted start time is from a different day, clearing state")
            clearRunningState()
            await syncTodayTotal()
            return
        }

        guard let employeeId = stateStore.employeeId else {
            logger.error("No employee ID configured")
            clearRunningState()
            return
        }

        do {
            // Verify the attendance still exists and is open
            let attendances = try await api.getTodayAttendances(employeeId: employeeId)
            if let attendance = attendances.first(where: { $0.id == attendanceId }) {
                if attendance.isOpen {
                    logger.info("Recovered open attendance \(attendanceId)")
                    runningStartTime = startTime
                    startTimer(from: startTime)
                    isRunning = true
                } else {
                    logger.info("Attendance \(attendanceId) is already closed")
                    clearRunningState()
                }
            } else {
                logger.warning("Attendance \(attendanceId) not found, clearing state")
                clearRunningState()
            }
        } catch {
            logger.error("Failed to verify attendance: \(error.localizedDescription)")
            // Keep the state in case of network error; user can retry
        }

        await syncTodayTotal()
    }

    // MARK: - Sync Today's Total

    /// Fetches and updates today's total tracked time.
    func syncTodayTotal() async {
        guard let employeeId = stateStore.employeeId else {
            todayTotal = 0
            return
        }

        do {
            let attendances = try await api.getTodayAttendances(employeeId: employeeId)
            let totalMinutes = attendances.reduce(0) { $0 + $1.durationMinutes }
            todayTotal = TimeInterval(totalMinutes * 60)
            logger.debug("Today's total: \(totalMinutes) minutes")
        } catch {
            logger.error("Failed to sync today's total: \(error.localizedDescription)")
        }
    }

    // MARK: - Midnight Stop

    /// Stops tracking at midnight (called by MidnightScheduler).
    func stopAtMidnight() async {
        guard isRunning else { return }

        logger.info("Midnight reached, stopping tracking")

        guard let attendanceId = stateStore.runningAttendanceId else {
            clearRunningState()
            return
        }

        do {
            // Stop at 23:59
            try await api.updateAttendance(attendanceId: attendanceId, endTime: "23:59")
            clearRunningState()
            logger.info("Tracking stopped at midnight")
        } catch {
            logger.error("Failed to stop at midnight: \(error.localizedDescription)")
            lastError = "Failed to stop at midnight: \(error.localizedDescription)"
        }
    }

    /// Starts tracking for the new day (called by MidnightScheduler if auto-restart is enabled).
    func startNewDay() async {
        guard !isRunning else { return }

        logger.info("Starting tracking for new day")
        await start()
    }

    // MARK: - Private Helpers

    private func startTimer(from startTime: Date) {
        runningStartTime = startTime
        timerTask?.cancel()

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, let start = self.runningStartTime else { break }
                await MainActor.run {
                    self.runningDuration = Date().timeIntervalSince(start)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }

    private func clearRunningState() {
        timerTask?.cancel()
        timerTask = nil
        runningStartTime = nil
        runningDuration = 0
        isRunning = false
        stateStore.clearRunningState()
    }
}
