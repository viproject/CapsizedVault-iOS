import Foundation
import Combine
import LocalAuthentication

final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published var isAppLockEnabled: Bool {
        didSet { UserDefaults.standard.set(isAppLockEnabled, forKey: "appLockEnabled") }
    }
    @Published var isBiometricEnabled: Bool {
        didSet { UserDefaults.standard.set(isBiometricEnabled, forKey: "biometricEnabled") }
    }
    /// When true, amounts are forced hidden on every cold launch and foreground resume.
    /// When false, the user's last shown/hidden state persists across launches.
    @Published var isAmountHiddenEnabled: Bool {
        didSet { UserDefaults.standard.set(isAmountHiddenEnabled, forKey: "amountHiddenEnabled") }
    }
    @Published var isLocked = false

    var shouldShowSecurityOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: "hasShownSecurityOnboarding") && !isAppLockEnabled
    }

    func markSecurityOnboardingShown() {
        UserDefaults.standard.set(true, forKey: "hasShownSecurityOnboarding")
    }

    private var backgroundDate: Date?
    private let lockTimeout: TimeInterval = 30

    private init() {
        self.isAppLockEnabled = UserDefaults.standard.bool(forKey: "appLockEnabled")
        self.isBiometricEnabled = UserDefaults.standard.object(forKey: "biometricEnabled") as? Bool ?? false
        self.isAmountHiddenEnabled = UserDefaults.standard.object(forKey: "amountHiddenEnabled") as? Bool ?? false

        if isAppLockEnabled && KeychainHelper.hasPIN() {
            isLocked = true
        }
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }

    var isBiometricAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func appMovedToBackground() {
        backgroundDate = Date()
    }

    func appMovedToForeground() {
        guard isAppLockEnabled, KeychainHelper.hasPIN() else { return }
        guard let backgroundDate else { return }
        if Date().timeIntervalSince(backgroundDate) >= lockTimeout {
            isLocked = true
        }
        self.backgroundDate = nil
    }

    func evaluateBiometrics(reason: String = "Unlock Capsized Vault") async -> Bool {
        guard isBiometricAvailable else { return false }

        let context = LAContext()
        context.localizedCancelTitle = "Use PIN"

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }

    func authenticateWithBiometrics() async -> Bool {
        guard isBiometricEnabled else { return false }
        let success = await evaluateBiometrics()
        if success {
            await MainActor.run { isLocked = false }
        }
        return success
    }

    func authenticateWithPIN(_ pin: String) -> Bool {
        if KeychainHelper.verifyPIN(pin) {
            isLocked = false
            return true
        }
        return false
    }

    func enableAppLock(pin: String) -> Bool {
        guard KeychainHelper.savePIN(pin) else { return false }
        isAppLockEnabled = true
        return true
    }

    func disableAppLock() {
        isAppLockEnabled = false
        isBiometricEnabled = false
        KeychainHelper.deletePIN()
        isLocked = false
    }

    func changePIN(from oldPIN: String, to newPIN: String) -> Bool {
        guard KeychainHelper.verifyPIN(oldPIN) else { return false }
        return KeychainHelper.savePIN(newPIN)
    }

    func authenticateWithDevicePasscode() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Verify your identity to reset your PIN"
            )
        } catch {
            return false
        }
    }

    func resetPIN(_ newPIN: String) -> Bool {
        guard KeychainHelper.savePIN(newPIN) else { return false }
        isLocked = false
        return true
    }
}
