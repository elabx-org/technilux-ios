import Foundation
import WidgetKit
import ActivityKit

// MARK: - Widget Data Service

/// Service for updating widget data and managing Live Activities
@MainActor
class WidgetService {
    static let shared = WidgetService()

    private let appGroupIdentifier = "group.com.technilux.app"
    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private init() {}

    // MARK: - Widget Data Updates

    /// Updates the widget data with current stats
    func updateWidgetData(
        totalQueries: Int,
        totalBlocked: Int,
        totalCached: Int,
        totalClients: Int,
        blockingEnabled: Bool,
        temporaryDisableEnd: Date? = nil,
        topDomains: [(name: String, hits: Int)] = [],
        topBlockedDomains: [(name: String, hits: Int)] = []
    ) {
        guard let containerURL else {
            print("Widget: Unable to access app group container")
            return
        }

        let data = WidgetDataModel(
            totalQueries: totalQueries,
            totalBlocked: totalBlocked,
            totalCached: totalCached,
            totalClients: totalClients,
            blockingEnabled: blockingEnabled,
            temporaryDisableEnd: temporaryDisableEnd,
            topDomains: topDomains.map { WidgetDataModel.TopDomain(name: $0.name, hits: $0.hits) },
            topBlockedDomains: topBlockedDomains.map { WidgetDataModel.TopDomain(name: $0.name, hits: $0.hits) },
            lastUpdated: Date()
        )

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: containerURL.appendingPathComponent("widget_data.json"))
            print("Widget: Updated widget data")

            // Reload all widgets
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Widget: Failed to save widget data: \(error)")
        }
    }

    /// Updates widget data from dashboard stats
    func updateFromStats(_ stats: StatsResponse, settings: DnsSettings?) {
        updateWidgetData(
            totalQueries: stats.stats.totalQueries,
            totalBlocked: stats.stats.totalBlocked,
            totalCached: stats.stats.totalCached,
            totalClients: stats.stats.totalClients,
            blockingEnabled: settings?.enableBlocking ?? true,
            temporaryDisableEnd: nil, // TODO: Parse from settings if available
            topDomains: (stats.topDomains ?? []).prefix(5).map { ($0.name, $0.hits) },
            topBlockedDomains: (stats.topBlockedDomains ?? []).prefix(5).map { ($0.name, $0.hits) }
        )
    }

    /// Reloads all widget timelines
    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Live Activities

    /// Starts a Live Activity for temporary blocking disable
    @available(iOS 16.2, *)
    func startBlockingActivity(serverName: String, disableEndTime: Date) {
        let attributes = BlockingActivityAttributes(serverName: serverName)
        let remainingMinutes = max(0, Int(disableEndTime.timeIntervalSinceNow / 60))

        let state = BlockingActivityAttributes.ContentState(
            isEnabled: false,
            disableEndTime: disableEndTime,
            remainingMinutes: remainingMinutes
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: disableEndTime),
                pushType: nil
            )
            print("Widget: Started blocking Live Activity")
        } catch {
            print("Widget: Failed to start Live Activity: \(error)")
        }
    }

    /// Updates the blocking Live Activity
    @available(iOS 16.2, *)
    func updateBlockingActivity(isEnabled: Bool, disableEndTime: Date? = nil) {
        let remainingMinutes = disableEndTime.map { max(0, Int($0.timeIntervalSinceNow / 60)) } ?? 0

        let state = BlockingActivityAttributes.ContentState(
            isEnabled: isEnabled,
            disableEndTime: disableEndTime,
            remainingMinutes: remainingMinutes
        )

        Task {
            for activity in Activity<BlockingActivityAttributes>.activities {
                await activity.update(.init(state: state, staleDate: disableEndTime))
            }
        }
    }

    /// Ends all blocking Live Activities
    @available(iOS 16.2, *)
    func endBlockingActivities() {
        Task {
            for activity in Activity<BlockingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: - Deep Link Handling

    /// Handles a widget deep link URL
    /// - Returns: The action to perform, or nil if not a widget URL
    func handleWidgetURL(_ url: URL) -> WidgetAction? {
        guard url.scheme == "technilux" else { return nil }

        switch url.host {
        case "blocking":
            if url.path == "/toggle" {
                return .toggleBlocking
            } else if url.path == "/enable" {
                return .enableBlocking
            } else if url.path == "/disable" {
                // Check for duration parameter
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let minutesStr = components.queryItems?.first(where: { $0.name == "minutes" })?.value,
                   let minutes = Int(minutesStr) {
                    return .temporaryDisable(minutes: minutes)
                }
                return .disableBlocking
            }
            return .showBlocking
        case "stats":
            return .showDashboard
        case "domains":
            return .showLogs
        case "app":
            // Handle app-specific URLs like technilux://app/advancedblocking/toggle
            if url.path == "/advancedblocking/toggle" {
                return .toggleAdvancedBlocking
            }
            return nil
        default:
            return nil
        }
    }

    /// Checks for pending widget requests (e.g., temporary disable from widget)
    func checkPendingRequests() -> DisableRequest? {
        guard let containerURL else { return nil }

        let requestURL = containerURL.appendingPathComponent("disable_request.json")

        guard let data = try? Data(contentsOf: requestURL),
              let request = try? JSONDecoder().decode(DisableRequest.self, from: data) else {
            return nil
        }

        // Remove the request file after reading
        try? FileManager.default.removeItem(at: requestURL)

        // Only process if request is recent (within last minute)
        if Date().timeIntervalSince(request.timestamp) < 60 {
            return request
        }

        return nil
    }

    /// Checks for pending blocking action from interactive widgets
    func checkPendingBlockingAction() -> BlockingActionRequest? {
        guard let containerURL else { return nil }

        let requestURL = containerURL.appendingPathComponent("blocking_action.json")

        guard let data = try? Data(contentsOf: requestURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String,
              let timestamp = json["timestamp"] as? TimeInterval else {
            return nil
        }

        // Remove the request file after reading
        try? FileManager.default.removeItem(at: requestURL)

        // Only process if request is recent (within last 30 seconds)
        if Date().timeIntervalSince1970 - timestamp < 30 {
            let minutes = json["minutes"] as? Int
            return BlockingActionRequest(action: action, minutes: minutes)
        }

        return nil
    }
}

struct BlockingActionRequest {
    let action: String // "toggle", "enable", "disable"
    let minutes: Int?  // For temporary disable
}

// MARK: - Widget Data Model (shared with widget extension)

struct WidgetDataModel: Codable {
    let totalQueries: Int
    let totalBlocked: Int
    let totalCached: Int
    let totalClients: Int
    let blockingEnabled: Bool
    let temporaryDisableEnd: Date?
    let topDomains: [TopDomain]
    let topBlockedDomains: [TopDomain]
    let lastUpdated: Date

    struct TopDomain: Codable {
        let name: String
        let hits: Int
    }
}

struct DisableRequest: Codable {
    let minutes: Int
    let timestamp: Date
}

// MARK: - Widget Actions

enum WidgetAction: Equatable {
    case toggleBlocking
    case enableBlocking
    case disableBlocking
    case temporaryDisable(minutes: Int)
    case showBlocking
    case showDashboard
    case showLogs
    case toggleAdvancedBlocking
}

// MARK: - Live Activity Attributes (shared)

struct BlockingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isEnabled: Bool
        var disableEndTime: Date?
        var remainingMinutes: Int
    }

    var serverName: String
}
