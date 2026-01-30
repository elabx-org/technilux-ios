import Foundation
import Security

/// Service for securely storing credentials in the iOS Keychain
final class KeychainService {
    static let shared = KeychainService()

    private let serviceIdentifier = "com.technilux.ios"
    private let sessionKey = "user_session"

    private init() {}

    // MARK: - Session Management

    func saveSession(_ session: UserSession) throws {
        let data = try JSONEncoder().encode(session)
        try save(data: data, forKey: sessionKey)
    }

    func loadSession() -> UserSession? {
        guard let data = load(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }

    func deleteSession() {
        delete(forKey: sessionKey)
    }

    // MARK: - Generic Keychain Operations

    private func save(data: Data, forKey key: String) throws {
        // Delete any existing item first
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .loadFailed(let status):
            return "Failed to load from Keychain: \(status)"
        }
    }
}
