import Foundation
import Security
import os.log

/// Secure storage for API credentials using macOS Keychain.
/// Stores client_id and client_secret; never logs or exposes these values.
final class KeychainStore {

    static let shared = KeychainStore()

    private let service = "com.example.PersonioTimer"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersonioTimer", category: "KeychainStore")

    private init() {}

    // MARK: - Public Interface

    struct Credentials {
        let clientId: String
        let clientSecret: String
    }

    /// Saves API credentials to Keychain.
    /// - Returns: true if successful, false otherwise.
    func saveCredentials(clientId: String, clientSecret: String) -> Bool {
        let clientIdSaved = save(key: "client_id", value: clientId)
        let clientSecretSaved = save(key: "client_secret", value: clientSecret)

        if clientIdSaved && clientSecretSaved {
            logger.info("Credentials saved to Keychain")
            return true
        } else {
            logger.error("Failed to save credentials to Keychain")
            return false
        }
    }

    /// Loads API credentials from Keychain.
    /// - Returns: Credentials if both values exist, nil otherwise.
    func loadCredentials() -> Credentials? {
        guard let clientId = load(key: "client_id"),
              let clientSecret = load(key: "client_secret") else {
            logger.debug("No credentials found in Keychain")
            return nil
        }
        logger.debug("Credentials loaded from Keychain")
        return Credentials(clientId: clientId, clientSecret: clientSecret)
    }

    /// Deletes all stored credentials from Keychain.
    func deleteCredentials() {
        delete(key: "client_id")
        delete(key: "client_secret")
        logger.info("Credentials deleted from Keychain")
    }

    /// Checks if credentials are stored.
    var hasCredentials: Bool {
        return load(key: "client_id") != nil && load(key: "client_secret") != nil
    }

    // MARK: - Private Keychain Operations

    private func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
