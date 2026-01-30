import Foundation
import Security
import LocalAuthentication

/// Service for securely storing credentials in the iOS Keychain with biometric support
final class KeychainService {
    static let shared = KeychainService()

    private let serviceIdentifier = "com.technilux.ios"
    private let sessionKey = "user_session"
    private let credentialsKey = "user_credentials"

    private init() {}

    // MARK: - Biometric Authentication

    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticateWithBiometrics() async throws -> Bool {
        let context = LAContext()
        context.localizedReason = "Unlock TechniLux"

        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to access TechniLux"
        )
    }

    func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }

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

    // MARK: - Credentials Storage (for biometric login)

    func saveCredentials(serverURL: String, username: String, password: String) throws {
        let credentials = SavedCredentials(serverURL: serverURL, username: username, password: password)
        let data = try JSONEncoder().encode(credentials)
        try save(data: data, forKey: credentialsKey)
    }

    func loadCredentials() -> SavedCredentials? {
        guard let data = load(forKey: credentialsKey) else { return nil }
        return try? JSONDecoder().decode(SavedCredentials.self, from: data)
    }

    func deleteCredentials() {
        delete(forKey: credentialsKey)
    }

    func hasSavedCredentials() -> Bool {
        return loadCredentials() != nil
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

// MARK: - Supporting Types

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID

    var name: String {
        switch self {
        case .none: return "Biometrics"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "lock.fill"
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        case .opticID: return "opticid"
        }
    }
}

struct SavedCredentials: Codable {
    let serverURL: String
    let username: String
    let password: String
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
