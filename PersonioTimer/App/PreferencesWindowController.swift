import AppKit
import SwiftUI
import os.log

/// Window controller for the Preferences panel.
final class PreferencesWindowController: NSWindowController {

    convenience init() {
        let preferencesView = PreferencesView()
        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 460))
        window.center()

        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - SwiftUI Preferences View

struct PreferencesView: View {

    @State private var clientId: String = ""
    @State private var clientSecret: String = ""
    @State private var employeeIdString: String = ""
    @State private var showTimerInMenubar: Bool = true
    @State private var menubarDisplayMode: LocalStateStore.MenubarDisplayMode = .currentSession

    @State private var isTestingConnection: Bool = false
    @State private var connectionResult: ValidationResult?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersonioTimer", category: "Preferences")

    enum ValidationResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // API Credentials Section
                    PreferenceSection(title: "API Credentials", icon: "key.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledField(label: "Client ID") {
                                TextField("Enter Client ID", text: $clientId)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }

                            LabeledField(label: "Client Secret") {
                                SecureField("Enter Client Secret", text: $clientSecret)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }

                            LabeledField(label: "Employee ID") {
                                TextField("e.g. 12345", text: $employeeIdString)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                    .frame(width: 120)
                            }

                            // Connection Test
                            HStack(spacing: 12) {
                                Button(action: testFullConnection) {
                                    HStack(spacing: 6) {
                                        if isTestingConnection {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: "bolt.fill")
                                                .font(.system(size: 11))
                                        }
                                        Text("Test Connection")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(clientId.isEmpty || clientSecret.isEmpty || employeeIdString.isEmpty || isTestingConnection)

                                if let result = connectionResult {
                                    connectionResultView(for: result)
                                }

                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }

                    // Display Options Section
                    PreferenceSection(title: "Menubar Display", icon: "menubar.rectangle") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $showTimerInMenubar) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Show timer in menubar")
                                        .font(.system(size: 13))
                                    Text("Display time next to the clock icon")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)

                            if showTimerInMenubar {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Display mode")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)

                                    Picker("", selection: $menubarDisplayMode) {
                                        ForEach(LocalStateStore.MenubarDisplayMode.allCases, id: \.self) { mode in
                                            Text(mode.description).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 220)

                                    Text(menubarDisplayMode == .currentSession
                                         ? "Shows time since tracking started"
                                         : "Shows total time tracked today")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 4)
                                .transition(.opacity)
                            }
                        }
                    }

                    // Help Section
                    PreferenceSection(title: "Help", icon: "questionmark.circle.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            HelpLink(
                                text: "Get API credentials from Personio",
                                detail: "Settings → Integrations → API credentials"
                            )
                            HelpLink(
                                text: "Find your Employee ID",
                                detail: "Check your profile URL: /staff/employees/ID"
                            )
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer Buttons
            HStack {
                Spacer()

                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveSettings()
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(employeeIdString.isEmpty || clientId.isEmpty || clientSecret.isEmpty)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 420, height: 460)
        .onAppear {
            loadSettings()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func connectionResultView(for result: ValidationResult) -> some View {
        switch result {
        case .success(let message):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                Text(message)
                    .foregroundColor(.green)
                    .font(.system(size: 11))
            }
        case .failure(let message):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                Text(message)
                    .foregroundColor(.red)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Settings Management

    private func loadSettings() {
        if let credentials = KeychainStore.shared.loadCredentials() {
            clientId = credentials.clientId
            clientSecret = credentials.clientSecret
        }

        if let empId = LocalStateStore.shared.employeeId {
            employeeIdString = String(empId)
        }

        showTimerInMenubar = LocalStateStore.shared.showTimerInMenubar
        menubarDisplayMode = LocalStateStore.shared.menubarDisplayMode
    }

    private func saveSettings() {
        if !clientId.isEmpty && !clientSecret.isEmpty {
            _ = KeychainStore.shared.saveCredentials(clientId: clientId, clientSecret: clientSecret)
        }

        if let empId = Int(employeeIdString) {
            LocalStateStore.shared.employeeId = empId
        }

        LocalStateStore.shared.showTimerInMenubar = showTimerInMenubar
        LocalStateStore.shared.menubarDisplayMode = menubarDisplayMode

        logger.info("Settings saved")
        NotificationCenter.default.post(name: .preferencesDidSave, object: nil)
    }

    private func testFullConnection() {
        guard !clientId.isEmpty, !clientSecret.isEmpty, !employeeIdString.isEmpty else { return }
        guard let employeeId = Int(employeeIdString) else {
            connectionResult = .failure("Invalid Employee ID")
            return
        }

        isTestingConnection = true
        connectionResult = nil

        _ = KeychainStore.shared.saveCredentials(clientId: clientId, clientSecret: clientSecret)

        Task {
            do {
                logger.info("Testing API authentication...")
                let isValid = try await PersonioAPIClient.shared.validateCredentials()

                if !isValid {
                    await MainActor.run {
                        isTestingConnection = false
                        connectionResult = .failure("Invalid credentials")
                    }
                    return
                }

                logger.info("Testing attendance access for employee \(employeeId)...")
                let attendances = try await PersonioAPIClient.shared.getTodayAttendances(employeeId: employeeId)

                await MainActor.run {
                    isTestingConnection = false
                    connectionResult = .success("Connected (\(attendances.count) entries today)")
                }
            } catch let error as PersonioAPIError {
                await MainActor.run {
                    isTestingConnection = false
                    switch error {
                    case .invalidCredentials:
                        connectionResult = .failure("Invalid credentials")
                    case .networkError:
                        connectionResult = .failure("Network error")
                    case .apiError(let message):
                        connectionResult = .failure(message)
                    default:
                        connectionResult = .failure(error.localizedDescription)
                    }
                }
            } catch {
                await MainActor.run {
                    isTestingConnection = false
                    connectionResult = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

// MARK: - Helper Views

struct PreferenceSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }

            content
                .padding(.leading, 2)
        }
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            content
        }
    }
}

struct HelpLink: View {
    let text: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.system(size: 12))
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
    }
}
#endif
