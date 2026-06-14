//
//  KeychainStore.swift
//  Claude Usage
//
//  Minimal Keychain wrapper for the claude.ai session key (a high-privilege
//  credential, so it never touches disk in plain text and is pinned to this device).
//  `nonisolated` so it can be read off the main actor.
//

import Foundation
import Security

enum KeychainStore {
    nonisolated static let service = "ai.aivideoplatform.claude.usuage"
    nonisolated static let claudeSessionAccount = "claudeSessionKey"

    @discardableResult
    nonisolated static func set(_ value: String, account: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        // Pin to this device: never sync the full-account session key via iCloud Keychain
        // or include it in encrypted backups.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    nonisolated static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    nonisolated static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
