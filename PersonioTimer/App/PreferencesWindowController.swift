import AppKit
import SwiftUI
import os.log

/// Window controller for the Preferences panel.
final class PreferencesWindowController: NSWindowController {

    convenience init() {
        let preferencesView = PreferencesView()
        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "PersonioTimer Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 440))
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
    @State private var autoRestartAfterMidnight: Bool = false

    @State private var isTestingConnection: Bool = false
    @State private var connectionResult: ValidationResult?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersonioTimer", category: "Preferences")

    enum ValidationResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        Form {
            // API Credentials Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Credentials")
                        .font(.headline)

                    TextField("Client ID", text: $clientId)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Client Secret", text: $clientSecret)
                        .textFieldStyle(.roundedBorder)

                    Text("Get credentials from Personio: Settings > Integrations > API credentials")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Employee ID Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Employee Settings")
                        .font(.headline)

                    HStack {
                        Text("Employee ID:")
                        TextField("12345", text: $employeeIdString)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }

                    Text("Find your ID in Personio URL: /staff/employees/12345")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Connection Test Section
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Connection Test")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Button(action: testFullConnection) {
                            HStack {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text("Test Connection")
                            }
                        }
                        .disabled(clientId.isEmpty || clientSecret.isEmpty || employeeIdString.isEmpty || isTestingConnection)
                        .buttonStyle(.borderedProminent)

                        if let result = connectionResult {
                            resultView(for: result)
                        }
                    }

                    Text("Tests API authentication and verifies Employee ID can access attendance data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Display Options Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Options")
                        .font(.headline)

                    Toggle("Show timer in menubar", isOn: $showTimerInMenubar)

                    Toggle("Auto-restart after midnight", isOn: $autoRestartAfterMidnight)
                }
            }

            Spacer()

            // Buttons
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
                .disabled(employeeIdString.isEmpty || clientId.isEmpty || clientSecret.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 450, minHeight: 420)
        .onAppear {
            loadSettings()
        }
    }

    @ViewBuilder
    private func resultView(for result: ValidationResult) -> some View {
        switch result {
        case .success(let message):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(message)
                    .foregroundColor(.green)
                    .font(.caption)
            }
        case .failure(let message):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Settings Management

    private func loadSettings() {
        // Load credentials (if any)
        if let credentials = KeychainStore.shared.loadCredentials() {
            clientId = credentials.clientId
            clientSecret = credentials.clientSecret
        }

        // Load employee ID
        if let empId = LocalStateStore.shared.employeeId {
            employeeIdString = String(empId)
        }

        // Load preferences
        showTimerInMenubar = LocalStateStore.shared.showTimerInMenubar
        autoRestartAfterMidnight = LocalStateStore.shared.autoRestartAfterMidnight
    }

    private func saveSettings() {
        // Save credentials to Keychain
        if !clientId.isEmpty && !clientSecret.isEmpty {
            _ = KeychainStore.shared.saveCredentials(clientId: clientId, clientSecret: clientSecret)
        }

        // Save employee ID
        if let empId = Int(employeeIdString) {
            LocalStateStore.shared.employeeId = empId
        }

        // Save preferences
        LocalStateStore.shared.showTimerInMenubar = showTimerInMenubar
        LocalStateStore.shared.autoRestartAfterMidnight = autoRestartAfterMidnight

        logger.info("Settings saved")

        // Notify that preferences were saved so menu can refresh
        NotificationCenter.default.post(name: .preferencesDidSave, object: nil)
    }

    private func testFullConnection() {
        guard !clientId.isEmpty, !clientSecret.isEmpty, !employeeIdString.isEmpty else { return }
        guard let employeeId = Int(employeeIdString) else {
            connectionResult = .failure("Invalid Employee ID format")
            return
        }

        isTestingConnection = true
        connectionResult = nil

        // Save credentials temporarily for testing
        _ = KeychainStore.shared.saveCredentials(clientId: clientId, clientSecret: clientSecret)

        Task {
            do {
                // Step 1: Test authentication
                logger.info("Testing API authentication...")
                let isValid = try await PersonioAPIClient.shared.validateCredentials()

                if !isValid {
                    await MainActor.run {
                        isTestingConnection = false
                        connectionResult = .failure("Invalid credentials")
                    }
                    return
                }

                // Step 2: Test fetching attendances for the employee
                logger.info("Testing attendance access for employee \(employeeId)...")
                let attendances = try await PersonioAPIClient.shared.getTodayAttendances(employeeId: employeeId)

                await MainActor.run {
                    isTestingConnection = false
                    let count = attendances.count
                    connectionResult = .success("Connected! Found \(count) attendance(s) today")
                }
            } catch let error as PersonioAPIError {
                await MainActor.run {
                    isTestingConnection = false
                    switch error {
                    case .invalidCredentials:
                        connectionResult = .failure("Invalid API credentials")
                    case .networkError(let underlying):
                        connectionResult = .failure("Network error: \(underlying.localizedDescription)")
                    case .apiError(let message):
                        connectionResult = .failure("API error: \(message)")
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

// MARK: - Preview

#if DEBUG
struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
    }
}
#endif
