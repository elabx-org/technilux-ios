import AppIntents
import WidgetKit

// MARK: - Toggle Blocking Intent

@available(iOS 16.0, *)
struct ToggleBlockingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle DNS Blocking"
    static var description = IntentDescription("Enables or disables DNS ad blocking")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // Save action request to shared container
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app") {
            let request = ["action": "toggle", "timestamp": Date().timeIntervalSince1970] as [String : Any]
            if let data = try? JSONSerialization.data(withJSONObject: request) {
                try? data.write(to: containerURL.appendingPathComponent("blocking_action.json"))
            }
        }

        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}

// MARK: - Enable Blocking Intent

@available(iOS 16.0, *)
struct EnableBlockingIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable DNS Blocking"
    static var description = IntentDescription("Enables DNS ad blocking")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app") {
            let request = ["action": "enable", "timestamp": Date().timeIntervalSince1970] as [String : Any]
            if let data = try? JSONSerialization.data(withJSONObject: request) {
                try? data.write(to: containerURL.appendingPathComponent("blocking_action.json"))
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Disable Blocking Intent

@available(iOS 16.0, *)
struct DisableBlockingIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable DNS Blocking"
    static var description = IntentDescription("Disables DNS ad blocking")

    @Parameter(title: "Duration (minutes)", default: 0)
    var minutes: Int

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app") {
            var request: [String: Any] = ["action": "disable", "timestamp": Date().timeIntervalSince1970]
            if minutes > 0 {
                request["minutes"] = minutes
            }
            if let data = try? JSONSerialization.data(withJSONObject: request) {
                try? data.write(to: containerURL.appendingPathComponent("blocking_action.json"))
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Quick Disable Intents

@available(iOS 16.0, *)
struct Disable5MinutesIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Blocking 5 Minutes"
    static var description = IntentDescription("Temporarily disables DNS blocking for 5 minutes")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app") {
            let request: [String: Any] = [
                "action": "disable",
                "minutes": 5,
                "timestamp": Date().timeIntervalSince1970
            ]
            if let data = try? JSONSerialization.data(withJSONObject: request) {
                try? data.write(to: containerURL.appendingPathComponent("blocking_action.json"))
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(iOS 16.0, *)
struct Disable15MinutesIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Blocking 15 Minutes"
    static var description = IntentDescription("Temporarily disables DNS blocking for 15 minutes")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app") {
            let request: [String: Any] = [
                "action": "disable",
                "minutes": 15,
                "timestamp": Date().timeIntervalSince1970
            ]
            if let data = try? JSONSerialization.data(withJSONObject: request) {
                try? data.write(to: containerURL.appendingPathComponent("blocking_action.json"))
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(iOS 16.0, *)
struct Disable30MinutesIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Blocking 30 Minutes"
    static var description = IntentDescription("Temporarily disables DNS blocking for 30 minutes")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app") {
            let request: [String: Any] = [
                "action": "disable",
                "minutes": 30,
                "timestamp": Date().timeIntervalSince1970
            ]
            if let data = try? JSONSerialization.data(withJSONObject: request) {
                try? data.write(to: containerURL.appendingPathComponent("blocking_action.json"))
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Refresh Stats Intent

@available(iOS 16.0, *)
struct RefreshStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh DNS Statistics"
    static var description = IntentDescription("Refreshes the DNS statistics widget")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 16.0, *)
struct TechniLuxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleBlockingIntent(),
            phrases: [
                "Toggle blocking in \(.applicationName)",
                "Turn blocking on or off in \(.applicationName)"
            ],
            shortTitle: "Toggle Blocking",
            systemImageName: "shield.checkmark"
        )

        AppShortcut(
            intent: EnableBlockingIntent(),
            phrases: [
                "Enable blocking in \(.applicationName)",
                "Turn on blocking in \(.applicationName)"
            ],
            shortTitle: "Enable Blocking",
            systemImageName: "shield.checkmark.fill"
        )

        AppShortcut(
            intent: Disable5MinutesIntent(),
            phrases: [
                "Disable blocking for 5 minutes in \(.applicationName)",
                "Pause blocking in \(.applicationName)"
            ],
            shortTitle: "Disable 5 Minutes",
            systemImageName: "clock.badge.xmark"
        )
    }
}
