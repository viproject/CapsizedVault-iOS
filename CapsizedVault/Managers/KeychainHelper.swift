import Foundation
import Security
import CryptoKit

enum KeychainHelper {

    private static let pinKey = "io.capsized.vault.pin-hash"

    // MARK: - Wallet file passwords

    @discardableResult
    static func saveWalletPassword(_ password: String, for walletId: String) -> Bool {
        let key = walletPasswordKey(walletId)
        deleteItem(forKey: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func walletPassword(for walletId: String) -> String? {
        readItem(forKey: walletPasswordKey(walletId))
    }

    @discardableResult
    static func deleteWalletPassword(for walletId: String) -> Bool {
        deleteItem(forKey: walletPasswordKey(walletId))
    }

    private static func walletPasswordKey(_ walletId: String) -> String {
        "io.capsized.vault.wallet-password.\(walletId)"
    }

    static func savePIN(_ pin: String) -> Bool {
        let hash = hashPIN(pin)
        deleteItem(forKey: pinKey)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: pinKey,
            kSecValueData as String: Data(hash.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func verifyPIN(_ pin: String) -> Bool {
        guard let storedHash = readItem(forKey: pinKey) else { return false }
        return hashPIN(pin) == storedHash
    }

    static func hasPIN() -> Bool {
        readItem(forKey: pinKey) != nil
    }

    static func deletePIN() -> Bool {
        deleteItem(forKey: pinKey)
    }

    private static func hashPIN(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data(pin.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func readItem(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private static func deleteItem(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
