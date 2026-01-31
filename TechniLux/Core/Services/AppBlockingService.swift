import Foundation

/// Service for managing app-specific blocking settings (Advanced Blocking Plus, etc.)
@MainActor
class AppBlockingService {
    static let shared = AppBlockingService()

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    private let appGroupIdentifier = "group.com.technilux.app"
    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private init() {}

    // MARK: - Advanced Blocking Plus

    /// Known app names for Advanced Blocking
    static let advancedBlockingNames = [
        "Advanced Blocking",
        "Advanced Blocking Plus"
    ]

    /// Check if Advanced Blocking is installed and get its name
    func getInstalledAdvancedBlockingApp() async -> String? {
        do {
            let response = try await client.listApps(node: cluster.nodeParam)
            for app in response.appsList {
                if Self.advancedBlockingNames.contains(app.name) {
                    return app.name
                }
            }
        } catch {
            print("AppBlockingService: Failed to list apps: \(error)")
        }
        return nil
    }

    /// Get the current Advanced Blocking enable state
    func getAdvancedBlockingEnabled(appName: String) async -> Bool? {
        do {
            let configResponse = try await client.getAppConfig(name: appName, node: cluster.nodeParam)
            let configJson = configResponse.config
            guard let data = configJson.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let enableBlocking = json["enableBlocking"] as? Bool else {
                return nil
            }
            return enableBlocking
        } catch {
            print("AppBlockingService: Failed to get config: \(error)")
        }
        return nil
    }

    /// Toggle Advanced Blocking enabled state
    func toggleAdvancedBlocking(appName: String) async throws -> Bool {
        // Get current config
        let configResponse = try await client.getAppConfig(name: appName, node: cluster.nodeParam)
        let configJson = configResponse.config
        guard let data = configJson.data(using: .utf8),
              var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppBlockingError.invalidConfig
        }

        // Toggle the enableBlocking field
        let currentEnabled = json["enableBlocking"] as? Bool ?? true
        let newEnabled = !currentEnabled
        json["enableBlocking"] = newEnabled

        // Save config back
        let newData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        guard let newConfigJson = String(data: newData, encoding: .utf8) else {
            throw AppBlockingError.invalidConfig
        }

        try await client.setAppConfig(name: appName, config: newConfigJson, node: cluster.nodeParam)

        // Update widget data
        updateWidgetAppState(appName: appName, enabled: newEnabled)

        return newEnabled
    }

    /// Set Advanced Blocking enabled state explicitly
    func setAdvancedBlocking(appName: String, enabled: Bool) async throws {
        // Get current config
        let configResponse = try await client.getAppConfig(name: appName, node: cluster.nodeParam)
        let configJson = configResponse.config
        guard let data = configJson.data(using: .utf8),
              var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppBlockingError.invalidConfig
        }

        // Set the enableBlocking field
        json["enableBlocking"] = enabled

        // Save config back
        let newData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        guard let newConfigJson = String(data: newData, encoding: .utf8) else {
            throw AppBlockingError.invalidConfig
        }

        try await client.setAppConfig(name: appName, config: newConfigJson, node: cluster.nodeParam)

        // Update widget data
        updateWidgetAppState(appName: appName, enabled: enabled)
    }

    // MARK: - Widget Data

    /// Update widget with app blocking state
    private func updateWidgetAppState(appName: String, enabled: Bool) {
        guard let containerURL else { return }

        let state = AppBlockingState(
            appName: appName,
            enabled: enabled,
            lastUpdated: Date()
        )

        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: containerURL.appendingPathComponent("app_blocking_state.json"))
        } catch {
            print("AppBlockingService: Failed to save widget state: \(error)")
        }
    }

    /// Check for pending app blocking action from widgets
    func checkPendingAppBlockingAction() -> AppBlockingAction? {
        guard let containerURL else { return nil }

        let requestURL = containerURL.appendingPathComponent("app_blocking_action.json")

        guard let data = try? Data(contentsOf: requestURL),
              let action = try? JSONDecoder().decode(AppBlockingAction.self, from: data) else {
            return nil
        }

        // Remove the request file after reading
        try? FileManager.default.removeItem(at: requestURL)

        // Only process if request is recent (within last 30 seconds)
        if Date().timeIntervalSince(action.timestamp) < 30 {
            return action
        }

        return nil
    }
}

// MARK: - Models

struct AppBlockingState: Codable {
    let appName: String
    let enabled: Bool
    let lastUpdated: Date
}

struct AppBlockingAction: Codable {
    let appName: String
    let action: String // "toggle", "enable", "disable"
    let timestamp: Date
}

enum AppBlockingError: LocalizedError {
    case invalidConfig
    case appNotFound

    var errorDescription: String? {
        switch self {
        case .invalidConfig:
            return "Invalid app configuration"
        case .appNotFound:
            return "Advanced Blocking app not found"
        }
    }
}
