import Foundation
import SwiftUI

/// Service for managing authentication state
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    var isAuthenticated = false
    var currentSession: UserSession?
    var isLoading = false
    var error: String?

    // Biometric settings
    var biometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometricEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometricEnabled") }
    }

    var hasSavedCredentials: Bool {
        keychain.hasSavedCredentials()
    }

    var canUseBiometrics: Bool {
        keychain.canUseBiometrics()
    }

    var biometricType: BiometricType {
        keychain.biometricType()
    }

    private let keychain = KeychainService.shared
    private let client = TechnitiumClient.shared

    private init() {}

    // MARK: - Authentication

    func login(serverURL: String, username: String, password: String, saveCredentials: Bool = false) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let url = URL(string: serverURL) else {
            throw AuthError.invalidServerURL
        }

        // Configure client with server URL
        client.configure(serverURL: url)

        // Attempt login
        let response = try await client.login(username: username, password: password)

        guard let token = response.token else {
            throw AuthError.loginFailed
        }

        // Create and save session
        let session = UserSession(
            username: response.username ?? username,
            displayName: response.displayName,
            token: token,
            serverURL: serverURL
        )

        try keychain.saveSession(session)

        // Save credentials for biometric login if requested
        if saveCredentials && canUseBiometrics {
            try keychain.saveCredentials(serverURL: serverURL, username: username, password: password)
            biometricEnabled = true
        }

        currentSession = session
        isAuthenticated = true
    }

    func loginWithBiometrics() async throws {
        guard biometricEnabled, hasSavedCredentials else {
            throw AuthError.biometricsNotAvailable
        }

        // Authenticate with biometrics
        let authenticated = try await keychain.authenticateWithBiometrics()

        guard authenticated else {
            throw AuthError.biometricsFailed
        }

        // Load saved credentials
        guard let credentials = keychain.loadCredentials() else {
            throw AuthError.noSavedCredentials
        }

        // Login with saved credentials
        try await login(
            serverURL: credentials.serverURL,
            username: credentials.username,
            password: credentials.password,
            saveCredentials: false
        )
    }

    func logout() {
        client.clearSession()
        keychain.deleteSession()
        currentSession = nil
        isAuthenticated = false
        // Don't delete credentials - user may want to use biometrics next time
    }

    func logoutAndClearCredentials() {
        logout()
        keychain.deleteCredentials()
        biometricEnabled = false
    }

    func restoreSession() async {
        guard let session = keychain.loadSession() else {
            isAuthenticated = false
            return
        }

        guard let url = URL(string: session.serverURL) else {
            keychain.deleteSession()
            isAuthenticated = false
            return
        }

        // Configure client with saved session
        client.configure(serverURL: url, token: session.token)

        // Validate session is still valid
        do {
            _ = try await client.checkSession()
            currentSession = session
            isAuthenticated = true
        } catch {
            // Session invalid, clear it
            keychain.deleteSession()
            client.clearSession()
            isAuthenticated = false
        }
    }

    func updateServerURL(_ newURL: String) throws {
        guard let url = URL(string: newURL) else {
            throw AuthError.invalidServerURL
        }

        guard var session = currentSession else {
            throw AuthError.notAuthenticated
        }

        // Update session with new URL
        session = UserSession(
            username: session.username,
            displayName: session.displayName,
            token: session.token,
            serverURL: newURL
        )

        try keychain.saveSession(session)
        currentSession = session
        client.configure(serverURL: url, token: session.token)
    }
}

enum AuthError: LocalizedError {
    case invalidServerURL
    case loginFailed
    case notAuthenticated
    case biometricsNotAvailable
    case biometricsFailed
    case noSavedCredentials

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Invalid server URL"
        case .loginFailed:
            return "Login failed"
        case .notAuthenticated:
            return "Not authenticated"
        case .biometricsNotAvailable:
            return "Biometric authentication not available"
        case .biometricsFailed:
            return "Biometric authentication failed"
        case .noSavedCredentials:
            return "No saved credentials found"
        }
    }
}
