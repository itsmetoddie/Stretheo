//
//  KeychainManager.swift
//  Stretheo
//

import Foundation
import Security

enum KeychainAccount: String, Sendable {
    case appleUserIdentifier = "appleUserIdentifier"
}

actor KeychainManager {
    static let shared = KeychainManager()

    private let service = ServiceConstants.keychainService
    private static let legacyAppleIdentityTokenAccount = "appleIdentityToken"

    func save(_ value: String, account: KeychainAccount) throws {
        let data = Data(value.utf8)
        try delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.authenticationFailed("Keychain write failed: \(status)")
        }
    }

    func string(for account: KeychainAccount) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(account: KeychainAccount) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Sign in with Apple

    func saveAppleUserIdentifier(_ identifier: String) throws {
        try save(identifier, account: .appleUserIdentifier)
    }

    func appleUserIdentifier() -> String? {
        string(for: .appleUserIdentifier)
    }

    func deleteAppleUserIdentifier() throws {
        try delete(account: .appleUserIdentifier)
    }

    /// Removes a previously persisted Apple identity JWT that is no longer used.
    func purgeLegacyAppleIdentityToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.legacyAppleIdentityTokenAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    func wipeAll() throws {
        try delete(account: .appleUserIdentifier)
        try purgeLegacyAppleIdentityToken()
    }
}
