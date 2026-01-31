import AppIntents
import WidgetKit

// MARK: - Toggle Blocking Intent

@available(iOS 17.0, *)
struct ToggleBlockingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle DNS Blocking"
    static var description = IntentDescription("Enable or disable DNS blocking")

    @Parameter(title: "Action")
    var action: BlockingAction

    enum BlockingAction: String, AppEnum {
        case enable
        case disable
        case toggleTemporary

        static var typeDisplayRepresentation: TypeDisplayRepresentation = "Blocking Action"
        static var caseDisplayRepresentations: [BlockingAction: DisplayRepresentation] = [
            .enable: "Enable Blocking",
            .disable: "Disable Blocking",
            .toggleTemporary: "Temporary Disable"
        ]
    }

    func perform() async throws -> some IntentResult {
        // This will be handled by the main app via deep link
        // The widget URL will trigger the action
        return .result()
    }
}

// MARK: - Temporary Disable Intent

@available(iOS 17.0, *)
struct TemporaryDisableBlockingIntent: AppIntent {
    static var title: LocalizedStringResource = "Temporarily Disable Blocking"
    static var description = IntentDescription("Disable DNS blocking for a specified duration")

    @Parameter(title: "Duration", default: 5)
    var minutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Disable blocking for \(\.$minutes) minutes")
    }

    func perform() async throws -> some IntentResult {
        // Store the request in shared container
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app") else {
            throw IntentError.generic(message: "Unable to access shared container")
        }

        let request = DisableRequest(minutes: minutes, timestamp: Date())
        let data = try JSONEncoder().encode(request)
        try data.write(to: containerURL.appendingPathComponent("disable_request.json"))

        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}

struct DisableRequest: Codable {
    let minutes: Int
    let timestamp: Date
}

// MARK: - Refresh Stats Intent

@available(iOS 17.0, *)
struct RefreshStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh DNS Statistics"
    static var description = IntentDescription("Refresh the DNS statistics widget")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Toggle Advanced Blocking Intent

@available(iOS 17.0, *)
struct ToggleAdvancedBlockingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Advanced Blocking"
    static var description = IntentDescription("Toggle the Advanced Blocking app on or off")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Store the request in shared container for main app to process
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app") else {
            throw IntentError.generic(message: "Unable to access shared container")
        }

        let action = AppBlockingActionRequest(
            appName: "Advanced Blocking Plus",
            action: "toggle",
            timestamp: Date()
        )

        let data = try JSONEncoder().encode(action)
        try data.write(to: containerURL.appendingPathComponent("app_blocking_action.json"))

        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}

struct AppBlockingActionRequest: Codable {
    let appName: String
    let action: String
    let timestamp: Date
}

// MARK: - Intent Errors

enum IntentError: Error {
    case generic(message: String)
}

extension IntentError: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .generic(let message):
            return LocalizedStringResource(stringLiteral: message)
        }
    }
}
