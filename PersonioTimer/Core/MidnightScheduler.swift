import Foundation
import os.log

/// Schedules auto-stop at midnight to prevent attendance entries from spanning days.
/// Optionally auto-restarts tracking after midnight if configured.
@MainActor
final class MidnightScheduler {

    static let shared = MidnightScheduler()

    private var midnightTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersonioTimer", category: "MidnightScheduler")

    private init() {}

    // MARK: - Public Interface

    /// Starts monitoring for midnight if tracking is active.
    func startMonitoring() {
        guard AttendanceService.shared.isRunning else {
            logger.debug("Not running, no need to monitor midnight")
            return
        }

        scheduleMidnightStop()
    }

    /// Stops all midnight monitoring.
    func stopMonitoring() {
        midnightTask?.cancel()
        midnightTask = nil
        restartTask?.cancel()
        restartTask = nil
        logger.debug("Midnight monitoring stopped")
    }

    // MARK: - Private Implementation

    private func scheduleMidnightStop() {
        midnightTask?.cancel()

        let secondsUntilMidnight = TimeUtils.secondsUntilMidnight()
        guard secondsUntilMidnight > 0 else {
            logger.warning("Midnight calculation returned non-positive value")
            return
        }

        logger.info("Scheduling midnight stop in \(Int(secondsUntilMidnight)) seconds")

        midnightTask = Task { [weak self] in
            do {
                // Wait until just before midnight (23:59:59)
                try await Task.sleep(nanoseconds: UInt64(secondsUntilMidnight * 1_000_000_000))

                guard !Task.isCancelled else { return }

                self?.logger.info("Midnight reached, triggering auto-stop")

                // Stop the current attendance
                await AttendanceService.shared.stopAtMidnight()

                // Schedule restart if enabled
                if LocalStateStore.shared.autoRestartAfterMidnight {
                    self?.scheduleNewDayStart()
                }
            } catch {
                self?.logger.error("Midnight task cancelled or failed: \(error.localizedDescription)")
            }
        }
    }

    private func scheduleNewDayStart() {
        restartTask?.cancel()

        // Wait 2 seconds into the new day to ensure clean date boundary
        let delaySeconds: UInt64 = 2

        logger.info("Scheduling new day start in \(delaySeconds) seconds")

        restartTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)

                guard !Task.isCancelled else { return }

                self?.logger.info("Starting tracking for new day")
                await AttendanceService.shared.startNewDay()

                // Re-schedule midnight monitoring for the new day
                self?.scheduleMidnightStop()
            } catch {
                self?.logger.error("New day start task failed: \(error.localizedDescription)")
            }
        }
    }

    /// Called when tracking starts to begin midnight monitoring.
    func onTrackingStarted() {
        scheduleMidnightStop()
    }

    /// Called when tracking stops to cancel midnight monitoring.
    func onTrackingStopped() {
        stopMonitoring()
    }
}
