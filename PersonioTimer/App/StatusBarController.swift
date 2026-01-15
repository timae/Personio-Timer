import AppKit
import Combine
import os.log

/// Controls the menubar status item and menu.
/// Displays tracking state, timer, and provides Start/Stop actions.
@MainActor
final class StatusBarController {

    // MARK: - Callback

    var onPreferencesRequested: (() -> Void)?

    // MARK: - Private Properties

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    private let attendanceService = AttendanceService.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersonioTimer", category: "StatusBarController")

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // Menu item references for dynamic updates
    private var startStopItem: NSMenuItem?
    private var todayTotalItem: NSMenuItem?
    private var statusIndicatorItem: NSMenuItem?
    private var statusItem_button: NSStatusBarButton?

    // MARK: - Initialization

    init() {
        setupStatusItem()
        setupMenu()
        bindToService()
        startUIUpdateTimer()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Public Interface

    func recoverState() async {
        await attendanceService.recoverState()
        updateMenuState()
        updateStatusBarTitle()
    }

    func refreshAfterPreferencesChange() async {
        logger.info("Refreshing after preferences change")
        updateMenuState()
        updateStatusBarTitle()
        await attendanceService.syncTodayTotal()
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Personio Timer")
            button.image?.isTemplate = true
            statusItem_button = button
        }
    }

    // MARK: - Menu Setup

    private func setupMenu() {
        menu = NSMenu()
        menu?.autoenablesItems = false

        // Status indicator (shows config state / errors)
        statusIndicatorItem = NSMenuItem(title: "Status: Checking...", action: nil, keyEquivalent: "")
        statusIndicatorItem?.isEnabled = false
        menu?.addItem(statusIndicatorItem!)

        menu?.addItem(NSMenuItem.separator())

        // Start/Stop item
        startStopItem = NSMenuItem(title: "Start", action: #selector(toggleTracking), keyEquivalent: "s")
        startStopItem?.target = self
        menu?.addItem(startStopItem!)

        // Today total
        todayTotalItem = NSMenuItem(title: "Today: 0h 00m", action: nil, keyEquivalent: "")
        todayTotalItem?.isEnabled = false
        menu?.addItem(todayTotalItem!)

        menu?.addItem(NSMenuItem.separator())

        // Sync now
        let syncItem = NSMenuItem(title: "Sync Now", action: #selector(syncNow), keyEquivalent: "r")
        syncItem.target = self
        menu?.addItem(syncItem)

        // Open Personio
        let openPersonioItem = NSMenuItem(title: "Open Personio", action: #selector(openPersonio), keyEquivalent: "o")
        openPersonioItem.target = self
        menu?.addItem(openPersonioItem)

        menu?.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu?.addItem(prefsItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit PersonioTimer", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Service Binding

    private func bindToService() {
        attendanceService.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuState()
                self?.updateStatusBarTitle()
            }
            .store(in: &cancellables)

        attendanceService.$todayTotal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] total in
                self?.updateTodayTotal(total)
            }
            .store(in: &cancellables)

        attendanceService.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.updateStatusIndicator()
                if let error = error {
                    self?.showError(error)
                }
            }
            .store(in: &cancellables)

        attendanceService.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIndicator()
            }
            .store(in: &cancellables)
    }

    // MARK: - UI Update Timer

    private func startUIUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusBarTitle()
            }
        }
    }

    // MARK: - UI Updates

    private func updateMenuState() {
        if attendanceService.isRunning {
            startStopItem?.title = "Stop"
            startStopItem?.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")
        } else {
            startStopItem?.title = "Start"
            startStopItem?.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Start")
        }

        // Disable Start if not configured
        let isConfigured = attendanceService.isConfigured
        startStopItem?.isEnabled = isConfigured || attendanceService.isRunning

        // Update status indicator
        updateStatusIndicator()
    }

    private func updateStatusIndicator() {
        let hasCredentials = KeychainStore.shared.hasCredentials
        let employeeId = LocalStateStore.shared.employeeId

        if attendanceService.isLoading {
            statusIndicatorItem?.title = "Status: Loading..."
        } else if let error = attendanceService.lastError {
            statusIndicatorItem?.title = "Error: \(error)"
        } else if !hasCredentials {
            statusIndicatorItem?.title = "Status: No API credentials"
        } else if employeeId == nil {
            statusIndicatorItem?.title = "Status: No Employee ID"
        } else if attendanceService.isRunning {
            statusIndicatorItem?.title = "Status: Tracking (ID: \(employeeId!))"
        } else {
            statusIndicatorItem?.title = "Status: Ready (ID: \(employeeId!))"
        }
    }

    private func updateStatusBarTitle() {
        guard let button = statusItem_button else { return }

        if attendanceService.isRunning && LocalStateStore.shared.showTimerInMenubar {
            let duration = attendanceService.runningDuration
            let timeString = TimeUtils.formatDurationShort(seconds: duration)
            button.title = " \(timeString)"
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Tracking")
        } else if attendanceService.isRunning {
            button.title = ""
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Tracking")
        } else {
            button.title = ""
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Personio Timer")
        }

        button.image?.isTemplate = true
    }

    private func updateTodayTotal(_ total: TimeInterval) {
        let formatted = TimeUtils.formatDuration(seconds: total)
        todayTotalItem?.title = "Today: \(formatted)"
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "PersonioTimer Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Actions

    @objc private func toggleTracking() {
        logger.info("Toggle tracking clicked. isConfigured=\(self.attendanceService.isConfigured), isRunning=\(self.attendanceService.isRunning)")

        if !attendanceService.isConfigured && !attendanceService.isRunning {
            logger.warning("Not configured, opening preferences")
            showPreferences()
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            if self.attendanceService.isRunning {
                self.logger.info("Stopping tracking...")
                await self.attendanceService.stop()
            } else {
                self.logger.info("Starting tracking...")
                await self.attendanceService.start()
                self.logger.info("Start completed. isRunning=\(self.attendanceService.isRunning), lastError=\(self.attendanceService.lastError ?? "none")")
            }
        }
    }

    @objc private func syncNow() {
        Task {
            await attendanceService.syncTodayTotal()
        }
    }

    @objc private func openPersonio() {
        if let url = URL(string: "https://app.personio.de") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showPreferences() {
        onPreferencesRequested?()
    }

    @objc private func quitApp() {
        // If running, offer to stop first
        if attendanceService.isRunning {
            let alert = NSAlert()
            alert.messageText = "Stop tracking before quitting?"
            alert.informativeText = "You have an active tracking session. Would you like to stop it before quitting?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Stop and Quit")
            alert.addButton(withTitle: "Quit Anyway")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                Task {
                    await attendanceService.stop()
                    NSApp.terminate(nil)
                }
                return
            case .alertSecondButtonReturn:
                NSApp.terminate(nil)
            default:
                return
            }
        } else {
            NSApp.terminate(nil)
        }
    }
}
