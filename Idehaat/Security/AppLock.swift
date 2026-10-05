import Foundation
import LocalAuthentication
import Observation

@Observable
final class AppLock {
    private static let enabledKey = "lockEnabled"

    private(set) var isEnabled: Bool
    var isLocked: Bool
    var isAuthenticating = false

    init() {
        let enabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        isEnabled = enabled
        isLocked = enabled
    }

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return String(localized: "Passcode")
        }
    }

    var biometrySymbol: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        if !enabled { isLocked = false }
    }

    func lock() {
        if isEnabled { isLocked = true }
    }

    @MainActor
    func authenticate() async {
        guard isLocked, !isAuthenticating else { return }
        let context = LAContext()
        var error: NSError?
        // If the phone has no passcode at all we cannot protect the app; don't lock the user out.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isLocked = false
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "Unlock to view your cards")
            )
            if ok { isLocked = false }
        } catch {
            // User cancelled — stay locked.
        }
    }

    /// Used when turning the lock off in Settings: confirm it's really the owner.
    @MainActor
    func confirmOwner() async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return true }
        return (try? await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: String(localized: "Confirm it's you")
        )) ?? false
    }
}
