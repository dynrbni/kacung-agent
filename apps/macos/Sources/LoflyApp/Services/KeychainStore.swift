import Foundation
import Security

/// Thin wrapper over the macOS keychain.
///
/// Secrets must never be written to disk or returned over the wire, so any
/// credential the desktop app holds lives here and only the derived session
/// state travels through the API.
public enum KeychainStore {

    private static let service = "com.dynrbni.lofly"

    public enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)
        case encodingFailed

        public var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
                return "Keychain error \(status): \(message)"
            case .encodingFailed:
                return "Could not encode the value for keychain storage."
            }
        }
    }

    @discardableResult
    public static func set(_ value: String, for account: String) throws -> Bool {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete first so the stored value is replaced rather than duplicated.
        SecItemDelete(baseQuery(account: account) as CFDictionary)

        var attributes = baseQuery(account: account)
        attributes[kSecValueData as String] = data
        // Accessible after first unlock: available to background tasks without
        // requiring the user to unlock again mid-run.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        return true
    }

    public static func get(_ account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    @discardableResult
    public static func delete(_ account: String) -> Bool {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// True when the app currently holds a credential for this account.
    public static func has(_ account: String) -> Bool {
        let status = SecItemCopyMatching(baseQuery(account: account) as CFDictionary, nil)
        return status == errSecSuccess
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
