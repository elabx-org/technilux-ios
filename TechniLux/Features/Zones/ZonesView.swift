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
            if zone.isDisabled {
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
    @State private var showCloneSheet = false
    @State private var zoneToClone: Zone?
    @State private var showConvertSheet = false
    @State private var zoneToConvert: Zone?
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
                            zone.isDisabled ? "Enable" : "Disable",
                            systemImage: zone.isDisabled ? "checkmark.circle" : "xmark.circle"
                        )
                    }
                    .tint(zone.isDisabled ? .green : .orange)
                }
                .contextMenu {
                    Button {
                        zoneToClone = zone
                        showCloneSheet = true
                    } label: {
                        Label("Clone Zone", systemImage: "doc.on.doc")
                    }

                    if zone.type == .primary {
                        Button {
                            zoneToConvert = zone
                            showConvertSheet = true
                        } label: {
                            Label("Convert Zone", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }

                    Divider()

                    Button {
                        Task {
                            await viewModel.toggleZone(zone)
                        }
                    } label: {
                        Label(
                            zone.isDisabled ? "Enable" : "Disable",
                            systemImage: zone.isDisabled ? "checkmark.circle" : "xmark.circle"
                        )
                    }

                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteZone(zone)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .sheet(isPresented: $showCloneSheet) {
            if let zone = zoneToClone {
                CloneZoneSheet(sourceZone: zone.name) {
                    Task { await viewModel.loadZones() }
                }
            }
        }
        .sheet(isPresented: $showConvertSheet) {
            if let zone = zoneToConvert {
                ConvertZoneSheet(zone: zone) {
                    Task { await viewModel.loadZones() }
                }
            }
        }
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
                        .foregroundStyle(zone.isDisabled ? .secondary : .primary)

                    if zone.isDisabled {
                        StatusBadge(text: "Disabled", color: .orange)
                    }
                }

                HStack(spacing: 8) {
                    StatusBadge(text: zone.type.rawValue, color: .techniluxPrimary)

                    if zone.dnssec != "Unsigned" {
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

// MARK: - Clone Zone Sheet

struct CloneZoneSheet: View {
    @Environment(\.dismiss) private var dismiss

    let sourceZone: String
    let onCloned: () -> Void

    @State private var newZoneName = ""
    @State private var isCloning = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Source Zone", value: sourceZone)

                    TextField("New Zone Name", text: $newZoneName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Text("Creates a copy of all records from the source zone into a new zone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Clone Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCloning)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Clone") {
                        Task { await cloneZone() }
                    }
                    .disabled(newZoneName.isEmpty || isCloning)
                }
            }
            .disabled(isCloning)
            .overlay {
                if isCloning {
                    ProgressView("Cloning zone...")
                }
            }
        }
    }

    private func cloneZone() async {
        isCloning = true
        error = nil

        do {
            try await TechnitiumClient.shared.cloneZone(
                zone: newZoneName,
                sourceZone: sourceZone,
                node: ClusterService.shared.nodeParam
            )
            onCloned()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isCloning = false
    }
}

// MARK: - Convert Zone Sheet

struct ConvertZoneSheet: View {
    @Environment(\.dismiss) private var dismiss

    let zone: Zone
    let onConverted: () -> Void

    @State private var targetType: ZoneType = .secondary
    @State private var isConverting = false
    @State private var error: String?

    private let convertibleTypes: [ZoneType] = [.secondary, .stub, .forwarder]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Zone", value: zone.name)
                    LabeledContent("Current Type", value: zone.type.rawValue)

                    Picker("Convert To", selection: $targetType) {
                        ForEach(convertibleTypes, id: \.rawValue) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Converting a zone will change its type. This action may affect zone replication and DNS resolution.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Convert Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isConverting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Convert") {
                        Task { await convertZone() }
                    }
                    .disabled(isConverting)
                }
            }
            .disabled(isConverting)
            .overlay {
                if isConverting {
                    ProgressView("Converting zone...")
                }
            }
        }
    }

    private func convertZone() async {
        isConverting = true
        error = nil

        do {
            try await TechnitiumClient.shared.convertZone(
                zone: zone.name,
                type: targetType,
                node: ClusterService.shared.nodeParam
            )
            onConverted()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isConverting = false
    }
}

#Preview("Zones View") {
    ZonesView()
}
