import SwiftUI

@MainActor
@Observable
final class DHCPViewModel {
    var scopes: [DhcpScope] = []
    var selectedScope: DhcpScope?
    var leases: [DhcpLease] = []
    var isLoading = false
    var error: String?

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    func loadScopes() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.listDhcpScopes(node: cluster.nodeParam)
            scopes = response.scopes
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadLeases(for scope: String) async {
        do {
            let response = try await client.listDhcpLeases(scope: scope, node: cluster.nodeParam)
            leases = response.leases
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleScope(_ scope: DhcpScope) async {
        do {
            if scope.enabled {
                try await client.disableDhcpScope(name: scope.name, node: cluster.nodeParam)
            } else {
                try await client.enableDhcpScope(name: scope.name, node: cluster.nodeParam)
            }
            await loadScopes()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteScope(_ scope: DhcpScope) async {
        do {
            try await client.deleteDhcpScope(name: scope.name, node: cluster.nodeParam)
            await loadScopes()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeLease(_ lease: DhcpLease) async {
        do {
            try await client.removeDhcpLease(
                scope: lease.scope,
                hardwareAddress: lease.hardwareAddress,
                node: cluster.nodeParam
            )
            await loadLeases(for: lease.scope)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct DHCPView: View {
    @State private var viewModel = DHCPViewModel()
    @Bindable var cluster = ClusterService.shared

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.scopes.isEmpty {
                    ProgressView("Loading DHCP scopes...")
                } else if viewModel.scopes.isEmpty {
                    EmptyStateView(
                        icon: "network",
                        title: "No DHCP Scopes",
                        description: "Create a scope to start managing DHCP"
                    )
                } else {
                    scopesList
                }
            }
            .navigationTitle("DHCP")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ClusterNodePicker()
                }
            }
            .refreshable {
                await viewModel.loadScopes()
            }
            .task {
                await viewModel.loadScopes()
            }
            .onChange(of: cluster.selectedNode) { _, _ in
                Task { await viewModel.loadScopes() }
            }
        }
    }

    private var scopesList: some View {
        List(viewModel.scopes) { scope in
            NavigationLink {
                DHCPScopeDetailView(scope: scope, viewModel: viewModel)
            } label: {
                ScopeRow(scope: scope)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    Task { await viewModel.deleteScope(scope) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    Task { await viewModel.toggleScope(scope) }
                } label: {
                    Label(
                        scope.enabled ? "Disable" : "Enable",
                        systemImage: scope.enabled ? "xmark.circle" : "checkmark.circle"
                    )
                }
                .tint(scope.enabled ? .orange : .green)
            }
        }
        .listStyle(.plain)
    }
}

struct ScopeRow: View {
    let scope: DhcpScope

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(scope.name)
                        .font(.headline)

                    if !scope.enabled {
                        StatusBadge(text: "Disabled", color: .orange)
                    }
                }

                Text("\(scope.startingAddress) - \(scope.endingAddress)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Subnet: \(scope.subnetMask)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct DHCPScopeDetailView: View {
    let scope: DhcpScope
    @Bindable var viewModel: DHCPViewModel

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Text("Info").tag(0)
                Text("Leases").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                scopeInfoView
            } else {
                leasesView
            }
        }
        .navigationTitle(scope.name)
        .task {
            if selectedTab == 1 {
                await viewModel.loadLeases(for: scope.name)
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 1 {
                Task { await viewModel.loadLeases(for: scope.name) }
            }
        }
    }

    private var scopeInfoView: some View {
        List {
            Section("Address Range") {
                InfoRow(label: "Start", value: scope.startingAddress)
                InfoRow(label: "End", value: scope.endingAddress)
                InfoRow(label: "Subnet Mask", value: scope.subnetMask)
            }

            Section("Lease Time") {
                if let days = scope.leaseTimeDays {
                    InfoRow(label: "Days", value: "\(days)")
                }
                if let hours = scope.leaseTimeHours {
                    InfoRow(label: "Hours", value: "\(hours)")
                }
                if let minutes = scope.leaseTimeMinutes {
                    InfoRow(label: "Minutes", value: "\(minutes)")
                }
            }

            if let router = scope.routerAddress {
                Section("Network") {
                    InfoRow(label: "Router", value: router)
                    if let domain = scope.domainName {
                        InfoRow(label: "Domain", value: domain)
                    }
                }
            }

            if let dnsServers = scope.dnsServers, !dnsServers.isEmpty {
                Section("DNS Servers") {
                    ForEach(dnsServers, id: \.self) { server in
                        Text(server)
                    }
                }
            }
        }
    }

    private var leasesView: some View {
        Group {
            if viewModel.leases.isEmpty {
                EmptyStateView(
                    icon: "network",
                    title: "No Leases",
                    description: "No active DHCP leases in this scope"
                )
            } else {
                List(viewModel.leases) { lease in
                    LeaseRow(lease: lease)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await viewModel.removeLease(lease) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct LeaseRow: View {
    let lease: DhcpLease

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(lease.address)
                    .font(.headline)

                Spacer()

                StatusBadge(
                    text: lease.type,
                    color: lease.type == "Reserved" ? .techniluxPrimary : .secondary
                )
            }

            if let hostname = lease.hostName {
                Text(hostname)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(lease.hardwareAddress)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview("DHCP View") {
    DHCPView()
}
