import SwiftUI

@MainActor
@Observable
final class ZonesViewModel {
    var zones: [Zone] = []
    var filteredZones: [Zone] = []
    var isLoading = false
    var error: String?
    var searchText = ""

    var filterType: ZoneType?

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    func loadZones() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.listZones(node: cluster.nodeParam)
            zones = response.zones
            applyFilters()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyFilters() {
        var result = zones

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        if let filterType {
            result = result.filter { $0.type == filterType }
        }

        filteredZones = result
    }

    func deleteZone(_ zone: Zone) async {
        do {
            try await client.deleteZone(name: zone.name, node: cluster.nodeParam)
            await loadZones()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleZone(_ zone: Zone) async {
        do {
            if zone.disabled {
                try await client.enableZone(name: zone.name, node: cluster.nodeParam)
            } else {
                try await client.disableZone(name: zone.name, node: cluster.nodeParam)
            }
            await loadZones()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ZonesView: View {
    @State private var viewModel = ZonesViewModel()
    @State private var showCreateSheet = false
    @Bindable var cluster = ClusterService.shared

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.zones.isEmpty {
                    ProgressView("Loading zones...")
                } else if viewModel.zones.isEmpty {
                    EmptyStateView(
                        icon: "globe",
                        title: "No Zones",
                        description: "Create a zone to get started",
                        action: { showCreateSheet = true },
                        actionTitle: "Create Zone"
                    )
                } else {
                    zonesList
                }
            }
            .navigationTitle("Zones")
            .searchable(text: $viewModel.searchText, prompt: "Search zones")
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.applyFilters()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        ClusterNodePicker()

                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadZones()
            }
            .task {
                await viewModel.loadZones()
            }
            .onChange(of: cluster.selectedNode) { _, _ in
                Task {
                    await viewModel.loadZones()
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateZoneSheet(onCreated: {
                    Task {
                        await viewModel.loadZones()
                    }
                })
            }
        }
    }

    private var zonesList: some View {
        List {
            ForEach(viewModel.filteredZones) { zone in
                NavigationLink {
                    ZoneDetailView(zoneName: zone.name)
                } label: {
                    ZoneRow(zone: zone)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteZone(zone)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        Task {
                            await viewModel.toggleZone(zone)
                        }
                    } label: {
                        Label(
                            zone.disabled ? "Enable" : "Disable",
                            systemImage: zone.disabled ? "checkmark.circle" : "xmark.circle"
                        )
                    }
                    .tint(zone.disabled ? .green : .orange)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct ZoneRow: View {
    let zone: Zone

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(zone.name)
                        .font(.headline)
                        .foregroundStyle(zone.disabled ? .secondary : .primary)

                    if zone.disabled {
                        StatusBadge(text: "Disabled", color: .orange)
                    }
                }

                HStack(spacing: 8) {
                    StatusBadge(text: zone.type.rawValue, color: .techniluxPrimary)

                    if zone.dnssecStatus != "Unsigned" {
                        StatusBadge(text: "DNSSEC", color: .green)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct CreateZoneSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var zoneName = ""
    @State private var zoneType: ZoneType = .primary
    @State private var isCreating = false
    @State private var error: String?

    let onCreated: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Zone Name", text: $zoneName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Type", selection: $zoneType) {
                        ForEach(ZoneType.allCases, id: \.rawValue) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createZone()
                        }
                    }
                    .disabled(zoneName.isEmpty || isCreating)
                }
            }
        }
    }

    private func createZone() async {
        isCreating = true
        error = nil
        defer { isCreating = false }

        do {
            try await TechnitiumClient.shared.createZone(
                name: zoneName,
                type: zoneType,
                node: ClusterService.shared.nodeParam
            )
            onCreated()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ZoneDetailView: View {
    let zoneName: String

    @State private var records: [DnsRecord] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading && records.isEmpty {
                ProgressView("Loading records...")
            } else if records.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Records",
                    description: "This zone has no records"
                )
            } else {
                List(records) { record in
                    RecordRow(record: record)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(zoneName)
        .task {
            await loadRecords()
        }
        .refreshable {
            await loadRecords()
        }
    }

    private func loadRecords() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await TechnitiumClient.shared.getRecords(
                zone: zoneName,
                node: ClusterService.shared.nodeParam
            )
            records = response.records
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct RecordRow: View {
    let record: DnsRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                StatusBadge(text: record.type.rawValue, color: .techniluxPrimary)
            }

            Text(record.rDataString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text("TTL: \(record.ttl)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if record.disabled {
                    StatusBadge(text: "Disabled", color: .orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Zones View") {
    ZonesView()
}
