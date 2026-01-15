import Foundation
import os.log

/// In-memory cache for Personio API authentication token.
/// Tokens are stored only in memory and never persisted to disk.
actor TokenCache {

    static let shared = TokenCache()

    private var token: String?
    private var expiresAt: Date?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersonioTimer", category: "TokenCache")

    /// Default token lifetime: 23 hours (conservative; actual may be 24h).
    private let defaultTokenLifetime: TimeInterval = 23 * 60 * 60

    private init() {}

    // MARK: - Public Interface

    /// Returns the cached token if still valid.
    func getToken() -> String? {
        guard let token = token,
              let expiresAt = expiresAt,
              Date() < expiresAt else {
            logger.debug("Token cache miss or expired")
            return nil
        }
        logger.debug("Token cache hit")
        return token
    }

    /// Stores a new token with optional expiry time.
    /// If no expiry is provided, uses the default lifetime.
    func setToken(_ newToken: String, expiresIn: TimeInterval? = nil) {
        self.token = newToken
        self.expiresAt = Date().addingTimeInterval(expiresIn ?? defaultTokenLifetime)
        logger.info("Token cached")
    }

    /// Clears the cached token.
    func clearToken() {
        token = nil
        expiresAt = nil
        logger.info("Token cache cleared")
    }

    /// Returns true if a valid token is cached.
    var hasValidToken: Bool {
        return getToken() != nil
    }
}
