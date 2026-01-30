import SwiftUI

@MainActor
@Observable
final class ZoneDetailViewModel {
    var zone: Zone?
    var records: [DnsRecord] = []
    var filteredRecords: [DnsRecord] = []
    var isLoading = false
    var error: String?
    var searchText = ""
    var typeFilter: RecordType?

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    let zoneName: String

    init(zoneName: String) {
        self.zoneName = zoneName
    }

    func loadData() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Load zone info and records in parallel
            async let zonesTask = client.listZones(node: cluster.nodeParam)
            async let recordsTask = client.getRecords(zone: zoneName, node: cluster.nodeParam)

            let zonesResponse = try await zonesTask
            zone = zonesResponse.zones.first { $0.name == zoneName }

            let recordsResponse = try await recordsTask
            records = recordsResponse.records
            applyFilters()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyFilters() {
        var result = records

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.type.rawValue.lowercased().contains(query) ||
                $0.rDataString.lowercased().contains(query)
            }
        }

        if let typeFilter {
            result = result.filter { $0.type == typeFilter }
        }

        filteredRecords = result
    }

    func addRecord(domain: String, type: RecordType, ttl: Int, recordData: [String: Any]) async throws {
        try await client.addRecord(
            zone: zoneName,
            domain: domain,
            type: type,
            ttl: ttl,
            recordData: recordData,
            node: cluster.nodeParam
        )
        await loadData()
    }

    func updateRecord(original: DnsRecord, newDomain: String, ttl: Int, recordData: [String: Any], disable: Bool) async throws {
        try await client.updateRecord(
            zone: zoneName,
            domain: original.name,
            type: original.type,
            ttl: ttl,
            newDomain: newDomain,
            recordData: recordData,
            disable: disable,
            node: cluster.nodeParam
        )
        await loadData()
    }

    func deleteRecord(_ record: DnsRecord) async {
        do {
            // Build rData for delete - need original values
            var deleteData: [String: Any] = [:]

            switch record.type {
            case .a, .aaaa:
                if let ip = record.rData["ipAddress"]?.description ?? record.rData["address"]?.description {
                    deleteData["ipAddress"] = ip
                }
            case .cname, .aname:
                if let cname = record.rData["cname"]?.description {
                    deleteData["cname"] = cname
                }
            case .ptr:
                if let ptrName = record.rData["ptrName"]?.description {
                    deleteData["ptrName"] = ptrName
                }
            case .mx:
                if let pref = record.rData["preference"]?.description {
                    deleteData["preference"] = Int(pref) ?? 10
                }
                if let exch = record.rData["exchange"]?.description {
                    deleteData["exchange"] = exch
                }
            case .txt:
                if let text = record.rData["text"]?.description {
                    deleteData["text"] = text
                }
            case .ns:
                if let ns = record.rData["nameServer"]?.description ?? record.rData["nsDomainName"]?.description {
                    deleteData["nameServer"] = ns
                }
            case .srv:
                if let p = record.rData["priority"]?.description { deleteData["priority"] = Int(p) ?? 0 }
                if let w = record.rData["weight"]?.description { deleteData["weight"] = Int(w) ?? 0 }
                if let port = record.rData["port"]?.description { deleteData["port"] = Int(port) ?? 0 }
                if let t = record.rData["target"]?.description { deleteData["target"] = t }
            case .caa:
                if let f = record.rData["flags"]?.description { deleteData["flags"] = Int(f) ?? 0 }
                if let t = record.rData["tag"]?.description { deleteData["tag"] = t }
                if let v = record.rData["value"]?.description { deleteData["value"] = v }
            default:
                // For other types, copy all rData
                for (key, value) in record.rData {
                    deleteData[key] = value.description
                }
            }

            try await client.deleteRecord(
                zone: zoneName,
                domain: record.name,
                type: record.type,
                recordData: deleteData,
                node: cluster.nodeParam
            )
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleRecord(_ record: DnsRecord) async {
        do {
            // Build rData for update
            var updateData: [String: Any] = [:]

            switch record.type {
            case .a, .aaaa:
                if let ip = record.rData["ipAddress"]?.description ?? record.rData["address"]?.description {
                    updateData["ipAddress"] = ip
                }
            case .cname, .aname:
                if let cname = record.rData["cname"]?.description {
                    updateData["cname"] = cname
                }
            case .ptr:
                if let ptrName = record.rData["ptrName"]?.description {
                    updateData["ptrName"] = ptrName
                }
            case .mx:
                if let pref = record.rData["preference"]?.description {
                    updateData["preference"] = Int(pref) ?? 10
                }
                if let exch = record.rData["exchange"]?.description {
                    updateData["exchange"] = exch
                }
            case .txt:
                if let text = record.rData["text"]?.description {
                    updateData["text"] = text
                }
            case .ns:
                if let ns = record.rData["nameServer"]?.description ?? record.rData["nsDomainName"]?.description {
                    updateData["nameServer"] = ns
                }
            case .srv:
                if let p = record.rData["priority"]?.description { updateData["priority"] = Int(p) ?? 0 }
                if let w = record.rData["weight"]?.description { updateData["weight"] = Int(w) ?? 0 }
                if let port = record.rData["port"]?.description { updateData["port"] = Int(port) ?? 0 }
                if let t = record.rData["target"]?.description { updateData["target"] = t }
            case .caa:
                if let f = record.rData["flags"]?.description { updateData["flags"] = Int(f) ?? 0 }
                if let t = record.rData["tag"]?.description { updateData["tag"] = t }
                if let v = record.rData["value"]?.description { updateData["value"] = v }
            default:
                for (key, value) in record.rData {
                    updateData[key] = value.description
                }
            }

            try await client.updateRecord(
                zone: zoneName,
                domain: record.name,
                type: record.type,
                ttl: record.ttl,
                newDomain: record.name,
                recordData: updateData,
                disable: !record.disabled,
                node: cluster.nodeParam
            )
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ZoneDetailView: View {
    let zoneName: String

    @State private var viewModel: ZoneDetailViewModel
    @State private var showAddSheet = false
    @State private var recordToEdit: DnsRecord?
    @State private var recordToDelete: DnsRecord?
    @State private var showDeleteConfirm = false
    @State private var showDNSSECSheet = false
    @State private var showOptionsMenu = false
    @State private var showPTRSheet = false
    @State private var showPermissionsSheet = false
    @Bindable var cluster = ClusterService.shared

    private var hasAddressRecords: Bool {
        viewModel.records.contains { $0.type == .a || $0.type == .aaaa }
    }

    init(zoneName: String) {
        self.zoneName = zoneName
        _viewModel = State(initialValue: ZoneDetailViewModel(zoneName: zoneName))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.records.isEmpty {
                ProgressView("Loading records...")
            } else if let error = viewModel.error, viewModel.records.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Failed to load records")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task {
                            await viewModel.loadData()
                        }
                    }
                }
                .padding()
            } else if viewModel.records.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Records",
                    description: "Add a DNS record to get started",
                    action: { showAddSheet = true },
                    actionTitle: "Add Record"
                )
            } else {
                recordsList
            }
        }
        .navigationTitle(zoneName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search records")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.applyFilters()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !(viewModel.zone?.internal ?? true) {
                    // Options menu
                    Menu {
                        if viewModel.zone?.type == .primary {
                            Button {
                                showDNSSECSheet = true
                            } label: {
                                Label("DNSSEC", systemImage: "shield.checkered")
                            }
                        }

                        if hasAddressRecords {
                            Button {
                                showPTRSheet = true
                            } label: {
                                Label("Manage PTR Records", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }

                        Button {
                            showPermissionsSheet = true
                        } label: {
                            Label("Permissions", systemImage: "lock.shield")
                        }

                        Divider()

                        Button {
                            Task {
                                if let zone = viewModel.zone {
                                    if zone.isDisabled {
                                        try? await TechnitiumClient.shared.enableZone(name: zoneName, node: cluster.nodeParam)
                                    } else {
                                        try? await TechnitiumClient.shared.disableZone(name: zoneName, node: cluster.nodeParam)
                                    }
                                    await viewModel.loadData()
                                }
                            }
                        } label: {
                            Label(
                                viewModel.zone?.isDisabled == true ? "Enable Zone" : "Disable Zone",
                                systemImage: viewModel.zone?.isDisabled == true ? "checkmark.circle" : "xmark.circle"
                            )
                        }

                        if viewModel.zone?.type == .secondary || viewModel.zone?.type == .stub {
                            Button {
                                Task {
                                    try? await TechnitiumClient.shared.resyncZone(zone: zoneName, node: cluster.nodeParam)
                                    await viewModel.loadData()
                                }
                            } label: {
                                Label("Resync Zone", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }

                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
        }
        .onChange(of: cluster.selectedNode) { _, _ in
            Task {
                await viewModel.loadData()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddRecordSheet(zoneName: zoneName) { domain, type, ttl, recordData in
                try await viewModel.addRecord(domain: domain, type: type, ttl: ttl, recordData: recordData)
            }
        }
        .sheet(item: $recordToEdit) { record in
            EditRecordSheet(zoneName: zoneName, record: record) { original, newDomain, ttl, recordData, disable in
                try await viewModel.updateRecord(original: original, newDomain: newDomain, ttl: ttl, recordData: recordData, disable: disable)
            }
        }
        .alert("Delete Record", isPresented: $showDeleteConfirm, presenting: recordToDelete) { record in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteRecord(record)
                }
            }
        } message: { record in
            Text("Are you sure you want to delete this \(record.type.rawValue) record for \(record.name)?")
        }
        .sheet(isPresented: $showDNSSECSheet) {
            if let zone = viewModel.zone {
                DNSSECSheet(
                    zoneName: zoneName,
                    dnssecStatus: zone.dnssec,
                    onSign: {
                        await viewModel.loadData()
                    },
                    onUnsign: {
                        await viewModel.loadData()
                    }
                )
            }
        }
        .sheet(isPresented: $showPTRSheet) {
            PTRManagementSheet(
                zoneName: zoneName,
                records: viewModel.records,
                onComplete: {
                    Task { await viewModel.loadData() }
                }
            )
        }
        .sheet(isPresented: $showPermissionsSheet) {
            ZonePermissionsSheet(
                zoneName: zoneName,
                onSaved: {
                    Task { await viewModel.loadData() }
                }
            )
        }
    }

    private var recordsList: some View {
        List {
            // Zone info header
            if let zone = viewModel.zone {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                StatusBadge(text: zone.type.rawValue, color: .techniluxPrimary)

                                if zone.isDisabled {
                                    StatusBadge(text: "Disabled", color: .orange)
                                }

                                if zone.dnssec != "Unsigned" {
                                    StatusBadge(text: "DNSSEC", color: .green)
                                }
                            }

                            if let serial = zone.soaSerial {
                                Text("Serial: \(serial)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text("\(viewModel.records.count) records")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Records list
            Section {
                ForEach(viewModel.filteredRecords) { record in
                    RecordRowView(
                        record: record,
                        isInternal: viewModel.zone?.internal ?? true,
                        onEdit: {
                            recordToEdit = record
                        },
                        onDelete: {
                            recordToDelete = record
                            showDeleteConfirm = true
                        },
                        onToggle: {
                            Task {
                                await viewModel.toggleRecord(record)
                            }
                        }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct RecordRowView: View {
    let record: DnsRecord
    let isInternal: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.name)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(record.disabled ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                StatusBadge(text: record.type.rawValue, color: typeColor)
            }

            Text(formatRData())
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text("TTL: \(record.ttl)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if record.disabled {
                    StatusBadge(text: "Disabled", color: .orange)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isInternal {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    onToggle()
                } label: {
                    Label(
                        record.disabled ? "Enable" : "Disable",
                        systemImage: record.disabled ? "checkmark.circle" : "xmark.circle"
                    )
                }
                .tint(record.disabled ? .green : .orange)

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .contextMenu {
            if !isInternal {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button {
                    onToggle()
                } label: {
                    Label(record.disabled ? "Enable" : "Disable",
                          systemImage: record.disabled ? "checkmark.circle" : "xmark.circle")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var typeColor: Color {
        switch record.type {
        case .a, .aaaa:
            return .blue
        case .cname, .aname:
            return .purple
        case .mx:
            return .orange
        case .txt:
            return .green
        case .ns:
            return .cyan
        case .ptr:
            return .pink
        case .soa:
            return .gray
        case .srv:
            return .indigo
        case .caa:
            return .brown
        default:
            return .techniluxPrimary
        }
    }

    private func formatRData() -> String {
        let rData = record.rData

        switch record.type {
        case .a, .aaaa:
            return rData["ipAddress"]?.description ?? rData["address"]?.description ?? ""
        case .cname, .aname:
            return rData["cname"]?.description ?? ""
        case .ptr:
            return rData["ptrName"]?.description ?? ""
        case .mx:
            let pref = rData["preference"]?.description ?? "10"
            let exch = rData["exchange"]?.description ?? ""
            return "\(pref) \(exch)"
        case .txt:
            return rData["text"]?.description ?? ""
        case .ns:
            return rData["nameServer"]?.description ?? rData["nsDomainName"]?.description ?? ""
        case .srv:
            let priority = rData["priority"]?.description ?? "0"
            let weight = rData["weight"]?.description ?? "0"
            let port = rData["port"]?.description ?? "0"
            let target = rData["target"]?.description ?? ""
            return "\(priority) \(weight) \(port) \(target)"
        case .caa:
            let flags = rData["flags"]?.description ?? "0"
            let tag = rData["tag"]?.description ?? ""
            let value = rData["value"]?.description ?? ""
            return "\(flags) \(tag) \"\(value)\""
        case .soa:
            let primary = rData["primaryNameServer"]?.description ?? ""
            let serial = rData["serial"]?.description ?? ""
            return "\(primary) (serial: \(serial))"
        default:
            return record.rDataString
        }
    }
}
