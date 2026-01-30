import SwiftUI
import Charts

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @Bindable var cluster = ClusterService.shared

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range picker
                    timeRangePicker

                    // Stats cards
                    statsGrid

                    // Main chart
                    if let chartData = viewModel.chartData {
                        mainChart(chartData)
                    }

                    // Pie charts row
                    pieChartsSection

                    // Top lists
                    topListsSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ClusterNodePicker()
                }
            }
            .refreshable {
                await viewModel.loadStats()
            }
            .task {
                await viewModel.loadStats()
            }
            .onAppear {
                viewModel.startAutoRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
            .onChange(of: cluster.selectedNode) { _, _ in
                Task {
                    await viewModel.loadStats()
                }
            }
        }
    }

    // MARK: - Components

    private var timeRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatsType.allCases.filter { $0 != .custom }, id: \.rawValue) { type in
                    Button {
                        viewModel.selectedTimeRange = type
                        Task {
                            await viewModel.loadStats()
                        }
                    } label: {
                        Text(timeRangeLabel(type))
                            .font(.subheadline)
                            .fontWeight(viewModel.selectedTimeRange == type ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedTimeRange == type
                                    ? Color.techniluxPrimary
                                    : Color.clear
                            )
                            .foregroundStyle(
                                viewModel.selectedTimeRange == type
                                    ? .white
                                    : .primary
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            StatCard(
                icon: "magnifyingglass",
                value: viewModel.totalQueriesFormatted,
                label: "Total Queries",
                color: .techniluxPrimary
            )

            StatCard(
                icon: "hand.raised.fill",
                value: viewModel.blockedQueriesFormatted,
                label: "Blocked",
                color: .techniluxDestructive
            )

            StatCard(
                icon: "bolt.fill",
                value: viewModel.cachedQueriesFormatted,
                label: "Cached",
                color: .techniluxSuccess
            )

            StatCard(
                icon: "person.2.fill",
                value: viewModel.totalClientsFormatted,
                label: "Clients",
                color: .techniluxInfo
            )
        }
    }

    @ViewBuilder
    private func mainChart(_ data: ChartData) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Queries Over Time")
                    .font(.headline)

                Chart {
                    ForEach(Array(data.labels.enumerated()), id: \.offset) { index, label in
                        if let dataset = data.datasets.first,
                           index < dataset.data.count {
                            LineMark(
                                x: .value("Time", label),
                                y: .value("Queries", dataset.data[index])
                            )
                            .foregroundStyle(Color.techniluxPrimary)

                            AreaMark(
                                x: .value("Time", label),
                                y: .value("Queries", dataset.data[index])
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.techniluxPrimary.opacity(0.3),
                                        Color.techniluxPrimary.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            }
        }
    }

    private var pieChartsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                if let data = viewModel.queryResponseChart {
                    pieChart(title: "Response Types", data: data)
                }

                if let data = viewModel.queryTypeChart {
                    pieChart(title: "Query Types", data: data)
                }

                if let data = viewModel.protocolTypeChart {
                    pieChart(title: "Protocols", data: data)
                }
            }
        }
    }

    @ViewBuilder
    private func pieChart(title: String, data: ChartData) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let dataset = data.datasets.first {
                    Chart {
                        ForEach(Array(data.labels.enumerated()), id: \.offset) { index, label in
                            if index < dataset.data.count {
                                SectorMark(
                                    angle: .value("Value", dataset.data[index]),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(by: .value("Type", label))
                                .cornerRadius(4)
                            }
                        }
                    }
                    .frame(width: 150, height: 150)
                    .chartLegend(.hidden)
                }
            }
        }
        .frame(width: 200)
    }

    private var topListsSection: some View {
        VStack(spacing: 16) {
            topListCard(
                title: "Top Clients",
                icon: "person.2",
                items: viewModel.topClients
            )

            topListCard(
                title: "Top Domains",
                icon: "globe",
                items: viewModel.topDomains
            )

            topListCard(
                title: "Top Blocked",
                icon: "hand.raised",
                items: viewModel.topBlockedDomains
            )
        }
    }

    @ViewBuilder
    private func topListCard(title: String, icon: String, items: [TopStat]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(.techniluxPrimary)
                    Text(title)
                        .font(.headline)
                }

                if items.isEmpty {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(items.prefix(5)) { item in
                        HStack {
                            Text(item.name)
                                .font(.subheadline)
                                .lineLimit(1)

                            Spacer()

                            Text(formatNumber(item.hits))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func timeRangeLabel(_ type: StatsType) -> String {
        switch type {
        case .lastHour: return "1H"
        case .lastDay: return "24H"
        case .lastWeek: return "7D"
        case .lastMonth: return "30D"
        case .lastYear: return "1Y"
        case .custom: return "Custom"
        }
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

// MARK: - Previews

#Preview("Dashboard") {
    DashboardView()
}
