import Foundation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    var stats: DashboardStats?
    var chartData: ChartData?
    var queryResponseChart: ChartData?
    var queryTypeChart: ChartData?
    var protocolTypeChart: ChartData?
    var topClients: [TopStat] = []
    var topDomains: [TopStat] = []
    var topBlockedDomains: [TopStat] = []

    var isLoading = false
    var error: String?

    var selectedTimeRange: StatsType = .lastHour

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    private var refreshTask: Task<Void, Never>?

    func loadStats() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.getStats(
                type: selectedTimeRange,
                node: cluster.nodeParam
            )

            stats = response.stats
            chartData = response.mainChartData
            queryResponseChart = response.queryResponseChartData
            queryTypeChart = response.queryTypeChartData
            protocolTypeChart = response.protocolTypeChartData
            topClients = response.topClients ?? []
            topDomains = response.topDomains ?? []
            topBlockedDomains = response.topBlockedDomains ?? []

        } catch {
            self.error = error.localizedDescription
        }
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await loadStats()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Formatted Values

    var totalQueriesFormatted: String {
        formatNumber(stats?.totalQueries ?? 0)
    }

    var blockedQueriesFormatted: String {
        formatNumber(stats?.totalBlocked ?? 0)
    }

    var cachedQueriesFormatted: String {
        formatNumber(stats?.totalCached ?? 0)
    }

    var totalClientsFormatted: String {
        formatNumber(stats?.totalClients ?? 0)
    }

    var blockRate: Double {
        guard let stats, stats.totalQueries > 0 else { return 0 }
        return Double(stats.totalBlocked) / Double(stats.totalQueries) * 100
    }

    var cacheHitRate: Double {
        guard let stats, stats.totalQueries > 0 else { return 0 }
        return Double(stats.totalCached) / Double(stats.totalQueries) * 100
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
