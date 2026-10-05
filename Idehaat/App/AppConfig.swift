import Foundation

/// Edit these two values after you deploy the pass server (see README).
enum AppConfig {
    /// Full URL of your pass-signing endpoint, e.g. https://idehaat-pass-server.onrender.com/v1/passes
    static let passServerURL = URL(string: "https://idehaat-pass-server.onrender.com/v1/passes")!

    /// One of the values you put in the server's API_KEYS variable.
    static let passServerAPIKey = "PASTE-YOUR-API-KEY-HERE"

    static var isWalletConfigured: Bool {
        !passServerURL.absoluteString.contains("YOUR-SERVER-URL") && !passServerAPIKey.hasPrefix("PASTE-")
    }
}
