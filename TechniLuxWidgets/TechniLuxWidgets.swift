import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct TechniLuxWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
        BlockingControlWidget()
        TopDomainsWidget()
        AdvancedBlockingWidget()
        if #available(iOS 16.2, *) {
            BlockingLiveActivity()
        }
    }
}

// MARK: - Shared Data

struct WidgetData: Codable {
    let totalQueries: Int
    let totalBlocked: Int
    let totalCached: Int
    let totalClients: Int
    let blockingEnabled: Bool
    let temporaryDisableEnd: Date?
    let topDomains: [TopDomain]
    let topBlockedDomains: [TopDomain]
    let lastUpdated: Date

    struct TopDomain: Codable, Identifiable {
        var id: String { name }
        let name: String
        let hits: Int
    }

    static let placeholder = WidgetData(
        totalQueries: 12450,
        totalBlocked: 1230,
        totalCached: 8900,
        totalClients: 15,
        blockingEnabled: true,
        temporaryDisableEnd: nil,
        topDomains: [
            TopDomain(name: "google.com", hits: 450),
            TopDomain(name: "apple.com", hits: 320),
            TopDomain(name: "cloudflare.com", hits: 210)
        ],
        topBlockedDomains: [
            TopDomain(name: "ads.example.com", hits: 120),
            TopDomain(name: "tracker.example.com", hits: 80)
        ],
        lastUpdated: Date()
    )

    static func load() -> WidgetData? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app"),
              let data = try? Data(contentsOf: containerURL.appendingPathComponent("widget_data.json")) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }

    func save() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app") else { return }
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: containerURL.appendingPathComponent("widget_data.json"))
        }
    }
}

// MARK: - Colors

extension Color {
    static let techniluxPrimary = Color(red: 0.16, green: 0.50, blue: 0.47)
    static let techniluxSecondary = Color(red: 0.20, green: 0.60, blue: 0.57)
}

// MARK: - Stats Widget

struct StatsWidget: Widget {
    let kind = "StatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            StatsWidgetView(entry: entry)
        }
        .configurationDisplayName("DNS Statistics")
        .description("View your DNS query statistics at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct StatsEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        completion(StatsEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        let entry = StatsEntry(date: Date(), data: data)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct StatsWidgetView: View {
    var entry: StatsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.techniluxPrimary)
                Text("TechniLux")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("\(formatNumber(entry.data.totalQueries))")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Queries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                StatItem(value: formatNumber(entry.data.totalBlocked), label: "Blocked", color: .red)
                StatItem(value: formatNumber(entry.data.totalCached), label: "Cached", color: .orange)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left side - main stats
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.techniluxPrimary)
                    Text("TechniLux")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(formatNumber(entry.data.totalQueries))")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Total Queries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Right side - breakdown
            VStack(alignment: .leading, spacing: 8) {
                StatRow(icon: "hand.raised.fill", label: "Blocked", value: formatNumber(entry.data.totalBlocked), color: .red)
                StatRow(icon: "memorychip", label: "Cached", value: formatNumber(entry.data.totalCached), color: .orange)
                StatRow(icon: "person.2.fill", label: "Clients", value: "\(entry.data.totalClients)", color: .blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.techniluxPrimary)
                Text("TechniLux DNS")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(entry.data.lastUpdated, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Queries", value: formatNumber(entry.data.totalQueries), icon: "arrow.up.arrow.down", color: .techniluxPrimary)
                StatCard(title: "Blocked", value: formatNumber(entry.data.totalBlocked), icon: "hand.raised.fill", color: .red)
                StatCard(title: "Cached", value: formatNumber(entry.data.totalCached), icon: "memorychip", color: .orange)
                StatCard(title: "Clients", value: "\(entry.data.totalClients)", icon: "person.2.fill", color: .blue)
            }

            Divider()

            // Top domains
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Domains")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(entry.data.topDomains.prefix(3)) { domain in
                    HStack {
                        Text(domain.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(domain.hits)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Blocking Control Widget

struct BlockingControlWidget: Widget {
    let kind = "BlockingControlWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BlockingProvider()) { entry in
            BlockingWidgetView(entry: entry)
        }
        .configurationDisplayName("Blocking Control")
        .description("Quickly toggle DNS blocking on or off.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct BlockingEntry: TimelineEntry {
    let date: Date
    let isEnabled: Bool
    let temporaryDisableEnd: Date?
}

struct BlockingProvider: TimelineProvider {
    func placeholder(in context: Context) -> BlockingEntry {
        BlockingEntry(date: Date(), isEnabled: true, temporaryDisableEnd: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BlockingEntry) -> Void) {
        let data = WidgetData.load()
        completion(BlockingEntry(
            date: Date(),
            isEnabled: data?.blockingEnabled ?? true,
            temporaryDisableEnd: data?.temporaryDisableEnd
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BlockingEntry>) -> Void) {
        let data = WidgetData.load()
        let entry = BlockingEntry(
            date: Date(),
            isEnabled: data?.blockingEnabled ?? true,
            temporaryDisableEnd: data?.temporaryDisableEnd
        )

        // Refresh frequently if temp disabled
        let nextUpdate: Date
        if let disableEnd = data?.temporaryDisableEnd, disableEnd > Date() {
            nextUpdate = min(disableEnd, Calendar.current.date(byAdding: .minute, value: 1, to: Date())!)
        } else {
            nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        }

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct BlockingWidgetView: View {
    var entry: BlockingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 12) {
            Image(systemName: entry.isEnabled ? "shield.checkmark.fill" : "shield.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(entry.isEnabled ? .green : .red)

            Text(entry.isEnabled ? "Blocking On" : "Blocking Off")
                .font(.headline)

            if let disableEnd = entry.temporaryDisableEnd, disableEnd > Date() {
                Text("Resumes \(disableEnd, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "technilux://blocking/toggle"))
    }

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.isEnabled ? "shield.checkmark.fill" : "shield.slash.fill")
                .font(.title2)
        }
        .widgetURL(URL(string: "technilux://blocking/toggle"))
    }

    private var accessoryRectangularView: some View {
        HStack {
            Image(systemName: entry.isEnabled ? "shield.checkmark.fill" : "shield.slash.fill")
                .font(.title2)
            VStack(alignment: .leading) {
                Text(entry.isEnabled ? "Blocking Active" : "Blocking Disabled")
                    .font(.headline)
                if let disableEnd = entry.temporaryDisableEnd, disableEnd > Date() {
                    Text("Resumes \(disableEnd, style: .timer)")
                        .font(.caption)
                }
            }
        }
        .widgetURL(URL(string: "technilux://blocking/toggle"))
    }
}

// MARK: - Top Domains Widget

struct TopDomainsWidget: Widget {
    let kind = "TopDomainsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TopDomainsProvider()) { entry in
            TopDomainsWidgetView(entry: entry)
        }
        .configurationDisplayName("Top Domains")
        .description("See your most queried domains.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct TopDomainsEntry: TimelineEntry {
    let date: Date
    let domains: [WidgetData.TopDomain]
    let blockedDomains: [WidgetData.TopDomain]
}

struct TopDomainsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TopDomainsEntry {
        TopDomainsEntry(date: Date(), domains: WidgetData.placeholder.topDomains, blockedDomains: WidgetData.placeholder.topBlockedDomains)
    }

    func getSnapshot(in context: Context, completion: @escaping (TopDomainsEntry) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        completion(TopDomainsEntry(date: Date(), domains: data.topDomains, blockedDomains: data.topBlockedDomains))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TopDomainsEntry>) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        let entry = TopDomainsEntry(date: Date(), domains: data.topDomains, blockedDomains: data.topBlockedDomains)

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TopDomainsWidgetView: View {
    var entry: TopDomainsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.techniluxPrimary)
                Text("Top Domains")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            if family == .systemLarge {
                HStack(alignment: .top, spacing: 16) {
                    domainList(title: "Most Queried", domains: entry.domains, color: .blue)
                    Divider()
                    domainList(title: "Most Blocked", domains: entry.blockedDomains, color: .red)
                }
            } else {
                domainList(title: nil, domains: entry.domains, color: .blue)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func domainList(title: String?, domains: [WidgetData.TopDomain], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(domains.prefix(family == .systemLarge ? 5 : 4)) { domain in
                HStack {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(domain.name)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text("\(domain.hits)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Advanced Blocking Widget

struct AppBlockingData: Codable {
    let appName: String
    let enabled: Bool
    let lastUpdated: Date

    static func load() -> AppBlockingData? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.technilux.app"),
              let data = try? Data(contentsOf: containerURL.appendingPathComponent("app_blocking_state.json")) else {
            return nil
        }
        return try? JSONDecoder().decode(AppBlockingData.self, from: data)
    }
}

struct AdvancedBlockingWidget: Widget {
    let kind = "AdvancedBlockingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AdvancedBlockingProvider()) { entry in
            AdvancedBlockingWidgetView(entry: entry)
        }
        .configurationDisplayName("Advanced Blocking")
        .description("Toggle the Advanced Blocking app on or off.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct AdvancedBlockingEntry: TimelineEntry {
    let date: Date
    let appName: String?
    let isEnabled: Bool
}

struct AdvancedBlockingProvider: TimelineProvider {
    func placeholder(in context: Context) -> AdvancedBlockingEntry {
        AdvancedBlockingEntry(date: Date(), appName: "Advanced Blocking Plus", isEnabled: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (AdvancedBlockingEntry) -> Void) {
        let data = AppBlockingData.load()
        completion(AdvancedBlockingEntry(
            date: Date(),
            appName: data?.appName ?? "Advanced Blocking Plus",
            isEnabled: data?.enabled ?? true
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AdvancedBlockingEntry>) -> Void) {
        let data = AppBlockingData.load()
        let entry = AdvancedBlockingEntry(
            date: Date(),
            appName: data?.appName ?? "Advanced Blocking Plus",
            isEnabled: data?.enabled ?? true
        )

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct AdvancedBlockingWidgetView: View {
    var entry: AdvancedBlockingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.isEnabled ? "hand.raised.fill" : "hand.raised.slash.fill")
                .font(.system(size: 36))
                .foregroundColor(entry.isEnabled ? .techniluxPrimary : .gray)

            Text("Adv. Blocking")
                .font(.caption)
                .fontWeight(.semibold)

            Text(entry.isEnabled ? "Enabled" : "Disabled")
                .font(.headline)
                .foregroundColor(entry.isEnabled ? .green : .red)

            Text("Tap to toggle")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "technilux://app/advancedblocking/toggle"))
    }

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.isEnabled ? "hand.raised.fill" : "hand.raised.slash.fill")
                .font(.title2)
        }
        .widgetURL(URL(string: "technilux://app/advancedblocking/toggle"))
    }

    private var accessoryRectangularView: some View {
        HStack {
            Image(systemName: entry.isEnabled ? "hand.raised.fill" : "hand.raised.slash.fill")
                .font(.title2)
            VStack(alignment: .leading) {
                Text("Adv. Blocking")
                    .font(.headline)
                Text(entry.isEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundColor(entry.isEnabled ? .green : .red)
            }
        }
        .widgetURL(URL(string: "technilux://app/advancedblocking/toggle"))
    }
}
