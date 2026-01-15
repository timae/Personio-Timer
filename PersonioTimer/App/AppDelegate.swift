import AppKit
import os.log

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var preferencesWindow: PreferencesWindowController?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersonioTimer", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("PersonioTimer starting up")

        // Setup main menu with Edit commands (required for paste to work in TextFields)
        setupMainMenu()

        // Initialize the status bar controller
        statusBarController = StatusBarController()
        statusBarController?.onPreferencesRequested = { [weak self] in
            self?.showPreferences()
        }

        // Check configuration and recover state
        Task {
            await statusBarController?.recoverState()

            // If not configured, prompt for preferences on first launch
            if !LocalStateStore.shared.isConfigured {
                await MainActor.run {
                    logger.info("Not configured, showing preferences")
                    showPreferences()
                }
            }
        }

        // Listen for preferences saved notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidSave),
            name: .preferencesDidSave,
            object: nil
        )

        logger.info("PersonioTimer ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("PersonioTimer shutting down")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menubar app: do not quit when windows close
        return false
    }

    private func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController()
        }
        preferencesWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About PersonioTimer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferencesFromMenu), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit PersonioTimer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (required for copy/paste to work)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func openPreferencesFromMenu() {
        showPreferences()
    }

    @objc private func preferencesDidSave() {
        logger.info("Preferences saved, refreshing state")
        Task {
            await statusBarController?.refreshAfterPreferencesChange()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let preferencesDidSave = Notification.Name("preferencesDidSave")
}
