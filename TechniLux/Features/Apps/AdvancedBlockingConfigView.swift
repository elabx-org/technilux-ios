import SwiftUI

// MARK: - Models

struct BlockListUrl: Codable, Equatable {
    var url: String
    var blockAsNxDomain: Bool?
    var blockingAddresses: [String]?
}

struct BlockingGroup: Codable, Identifiable, Equatable {
    var id: String { name }
    var name: String
    var description: String?
    var enableBlocking: Bool
    var allowTxtBlockingReport: Bool?
    var blockAsNxDomain: Bool
    var blockingAddresses: [String]
    var allowed: [String]
    var blocked: [String]
    var allowListUrls: [String]
    var blockListUrls: [String]
    var allowedRegex: [String]
    var blockedRegex: [String]
    var regexAllowListUrls: [String]
    var regexBlockListUrls: [String]
    var adblockListUrls: [String]

    static var `default`: BlockingGroup {
        BlockingGroup(
            name: "default",
            description: nil,
            enableBlocking: true,
            allowTxtBlockingReport: true,
            blockAsNxDomain: false,
            blockingAddresses: [],
            allowed: [],
            blocked: [],
            allowListUrls: [],
            blockListUrls: [],
            allowedRegex: [],
            blockedRegex: [],
            regexAllowListUrls: [],
            regexBlockListUrls: [],
            adblockListUrls: []
        )
    }
}

struct NetworkMapping: Codable, Identifiable, Equatable {
    var id: String { addresses.joined(separator: ",") }
    var addresses: [String]
    var groups: [String]
    var note: String?
    var lastModified: String?
}

struct AdvancedBlockingConfig: Codable {
    var enableBlocking: Bool
    var blockingAnswerTtl: Int
    var blockListUrlUpdateIntervalHours: Int
    var localEndPointGroupMap: [String: String]
    var networkGroupMap: [String: StringOrArray]
    var networkMappings: [NetworkMapping]?
    var groups: [BlockingGroup]

    static var `default`: AdvancedBlockingConfig {
        AdvancedBlockingConfig(
            enableBlocking: true,
            blockingAnswerTtl: 30,
            blockListUrlUpdateIntervalHours: 24,
            localEndPointGroupMap: [:],
            networkGroupMap: [:],
            networkMappings: [],
            groups: [.default]
        )
    }
}

// Handle networkGroupMap values that can be string or array
enum StringOrArray: Codable, Equatable {
    case string(String)
    case array([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([String].self) {
            self = .array(array)
        } else {
            throw DecodingError.typeMismatch(StringOrArray.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or array"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        }
    }

    var groups: [String] {
        switch self {
        case .string(let s): return [s]
        case .array(let a): return a
        }
    }
}

// MARK: - View Model

@MainActor
@Observable
final class AdvancedBlockingViewModel {
    var config: AdvancedBlockingConfig
    var activeGroupIndex: Int = 0
    var error: String?

    // Dialog states
    var showNetworkMappingSheet = false
    var editingMappingIndex: Int?
    var newMappingAddresses: [String] = []
    var newMappingGroups: [String] = []
    var newMappingNote: String = ""
    var manualAddressInput: String = ""

    // For adding items to lists
    var newItemText: String = ""

    let isMultiGroupMode: Bool
    let onSave: (String) async -> Void
    let onCancel: () -> Void

    init(configJson: String, appName: String, onSave: @escaping (String) async -> Void, onCancel: @escaping () -> Void) {
        self.isMultiGroupMode = appName.lowercased().contains("plus")
        self.onSave = onSave
        self.onCancel = onCancel

        // Parse config
        if let data = configJson.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(AdvancedBlockingConfig.self, from: data) {
            self.config = parsed
            // Migrate networkGroupMap to networkMappings if needed
            if config.networkMappings == nil || config.networkMappings!.isEmpty {
                migrateNetworkGroupMap()
            }
        } else {
            self.config = .default
        }
    }

    private func migrateNetworkGroupMap() {
        guard !config.networkGroupMap.isEmpty else {
            config.networkMappings = []
            return
        }

        // Group by identical group sets
        var grouped: [String: (addresses: [String], groups: [String])] = [:]
        for (address, groupValue) in config.networkGroupMap {
            let groups = groupValue.groups
            let key = groups.sorted().joined(separator: "|")
            if var existing = grouped[key] {
                existing.addresses.append(address)
                grouped[key] = existing
            } else {
                grouped[key] = (addresses: [address], groups: groups)
            }
        }

        config.networkMappings = grouped.values.map { entry in
            NetworkMapping(
                addresses: entry.addresses,
                groups: entry.groups,
                note: nil,
                lastModified: ISO8601DateFormatter().string(from: Date())
            )
        }
    }

    var currentGroup: BlockingGroup? {
        guard activeGroupIndex < config.groups.count else { return nil }
        return config.groups[activeGroupIndex]
    }

    func addGroup() {
        let newGroup = BlockingGroup(
            name: "group-\(config.groups.count + 1)",
            description: nil,
            enableBlocking: true,
            allowTxtBlockingReport: true,
            blockAsNxDomain: false,
            blockingAddresses: [],
            allowed: [],
            blocked: [],
            allowListUrls: [],
            blockListUrls: [],
            allowedRegex: [],
            blockedRegex: [],
            regexAllowListUrls: [],
            regexBlockListUrls: [],
            adblockListUrls: []
        )
        config.groups.append(newGroup)
        activeGroupIndex = config.groups.count - 1
    }

    func deleteGroup(at index: Int) {
        guard config.groups.count > 1 else { return }
        let removedName = config.groups[index].name
        config.groups.remove(at: index)

        // Remove from mappings
        if var mappings = config.networkMappings {
            for i in mappings.indices {
                mappings[i].groups.removeAll { $0 == removedName }
            }
            config.networkMappings = mappings.filter { !$0.groups.isEmpty }
        }

        if activeGroupIndex >= config.groups.count {
            activeGroupIndex = config.groups.count - 1
        }
    }

    func duplicateGroup(at index: Int) {
        var copy = config.groups[index]
        copy.name = "\(copy.name)-copy"
        config.groups.append(copy)
        activeGroupIndex = config.groups.count - 1
    }

    func renameGroup(at index: Int, to newName: String) {
        let oldName = config.groups[index].name
        config.groups[index].name = newName

        // Update mappings
        if var mappings = config.networkMappings {
            for i in mappings.indices {
                mappings[i].groups = mappings[i].groups.map { $0 == oldName ? newName : $0 }
            }
            config.networkMappings = mappings
        }
    }

    // Network mapping
    func openAddMapping() {
        editingMappingIndex = nil
        newMappingAddresses = []
        newMappingGroups = []
        newMappingNote = ""
        manualAddressInput = ""
        showNetworkMappingSheet = true
    }

    func openEditMapping(at index: Int) {
        guard let mappings = config.networkMappings, index < mappings.count else { return }
        let mapping = mappings[index]
        editingMappingIndex = index
        newMappingAddresses = mapping.addresses
        newMappingGroups = mapping.groups
        newMappingNote = mapping.note ?? ""
        manualAddressInput = ""
        showNetworkMappingSheet = true
    }

    func addManualAddress() {
        let addr = manualAddressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addr.isEmpty, !newMappingAddresses.contains(addr) else { return }
        newMappingAddresses.append(addr)
        manualAddressInput = ""
    }

    func removeAddress(_ addr: String) {
        newMappingAddresses.removeAll { $0 == addr }
    }

    func toggleGroupInSelection(_ groupName: String) {
        if newMappingGroups.contains(groupName) {
            newMappingGroups.removeAll { $0 == groupName }
        } else {
            newMappingGroups.append(groupName)
        }
    }

    func saveMapping() {
        guard !newMappingAddresses.isEmpty, !newMappingGroups.isEmpty else { return }

        let mapping = NetworkMapping(
            addresses: newMappingAddresses,
            groups: newMappingGroups,
            note: newMappingNote.isEmpty ? nil : newMappingNote,
            lastModified: ISO8601DateFormatter().string(from: Date())
        )

        if config.networkMappings == nil {
            config.networkMappings = []
        }

        if let editIndex = editingMappingIndex {
            // Remove old addresses from networkGroupMap
            let oldMapping = config.networkMappings![editIndex]
            for addr in oldMapping.addresses {
                config.networkGroupMap.removeValue(forKey: addr)
            }
            config.networkMappings![editIndex] = mapping
        } else {
            config.networkMappings!.append(mapping)
        }

        // Update legacy networkGroupMap
        for addr in mapping.addresses {
            config.networkGroupMap[addr] = isMultiGroupMode ? .array(mapping.groups) : .string(mapping.groups[0])
        }

        showNetworkMappingSheet = false
    }

    func deleteMapping(at index: Int) {
        guard var mappings = config.networkMappings, index < mappings.count else { return }
        let mapping = mappings[index]

        // Remove from networkGroupMap
        for addr in mapping.addresses {
            config.networkGroupMap.removeValue(forKey: addr)
        }

        mappings.remove(at: index)
        config.networkMappings = mappings
    }

    // List operations
    func addToList(_ value: String, keyPath: WritableKeyPath<BlockingGroup, [String]>) {
        guard !value.isEmpty else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !config.groups[activeGroupIndex][keyPath: keyPath].contains(trimmed) else { return }
        config.groups[activeGroupIndex][keyPath: keyPath].append(trimmed)
    }

    func removeFromList(at index: Int, keyPath: WritableKeyPath<BlockingGroup, [String]>) {
        config.groups[activeGroupIndex][keyPath: keyPath].remove(at: index)
    }

    func save() async {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            if let json = String(data: data, encoding: .utf8) {
                await onSave(json)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Main View

struct AdvancedBlockingConfigView: View {
    @Bindable var viewModel: AdvancedBlockingViewModel
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                // Global Settings
                globalSettingsSection

                // Network Mappings
                networkMappingsSection

                // Groups
                groupsSection
            }
            .navigationTitle("Advanced Blocking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            await viewModel.save()
                            isSaving = false
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $viewModel.showNetworkMappingSheet) {
                NetworkMappingSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Global Settings

    private var globalSettingsSection: some View {
        Section("General Settings") {
            Toggle("Enable Blocking", isOn: $viewModel.config.enableBlocking)

            HStack {
                Text("Blocking Answer TTL")
                Spacer()
                TextField("30", value: $viewModel.config.blockingAnswerTtl, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("sec")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Update Interval")
                Spacer()
                TextField("24", value: $viewModel.config.blockListUrlUpdateIntervalHours, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("hrs")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Network Mappings

    private var networkMappingsSection: some View {
        Section {
            if let mappings = viewModel.config.networkMappings, !mappings.isEmpty {
                ForEach(Array(mappings.enumerated()), id: \.element.id) { index, mapping in
                    NetworkMappingRow(mapping: mapping) {
                        viewModel.openEditMapping(at: index)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.deleteMapping(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } else {
                Text("No network mappings. All clients use the default group.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            Button {
                viewModel.openAddMapping()
            } label: {
                Label("Add Mapping", systemImage: "plus")
            }
        } header: {
            HStack {
                Text("Network Group Mapping")
                Spacer()
                if let count = viewModel.config.networkMappings?.count, count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Groups

    private var groupsSection: some View {
        Section {
            // Group picker - more reliable than custom buttons
            HStack {
                Picker("Group", selection: $viewModel.activeGroupIndex) {
                    ForEach(Array(viewModel.config.groups.enumerated()), id: \.offset) { index, group in
                        Text(group.name).tag(index)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    viewModel.addGroup()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.techniluxPrimary)
                }
                .buttonStyle(.plain)
            }

            if viewModel.activeGroupIndex < viewModel.config.groups.count {
                GroupConfigView(
                    group: Binding(
                        get: { viewModel.config.groups[viewModel.activeGroupIndex] },
                        set: { viewModel.config.groups[viewModel.activeGroupIndex] = $0 }
                    ),
                    viewModel: viewModel,
                    groupIndex: viewModel.activeGroupIndex
                )
                .id(viewModel.activeGroupIndex) // Force recreation when switching groups
            }
        } header: {
            HStack {
                Text("Blocking Groups")
                Spacer()
                Text("\(viewModel.config.groups.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Supporting Views

struct NetworkMappingRow: View {
    let mapping: NetworkMapping
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 4) {
                // Addresses
                HStack {
                    ForEach(mapping.addresses.prefix(3), id: \.self) { addr in
                        Text(addr)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if mapping.addresses.count > 3 {
                        Text("+\(mapping.addresses.count - 3)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Groups
                HStack {
                    ForEach(mapping.groups, id: \.self) { group in
                        Text(group)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.techniluxPrimary.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                // Note
                if let note = mapping.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct NetworkMappingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AdvancedBlockingViewModel

    var body: some View {
        NavigationStack {
            List {
                // Addresses
                Section("Network Addresses") {
                    HStack {
                        TextField("IP or subnet (e.g., 10.0.0.5)", text: $viewModel.manualAddressInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit {
                                viewModel.addManualAddress()
                            }
                        Button("Add") {
                            viewModel.addManualAddress()
                        }
                        .disabled(viewModel.manualAddressInput.isEmpty)
                    }

                    if !viewModel.newMappingAddresses.isEmpty {
                        ForEach(viewModel.newMappingAddresses, id: \.self) { addr in
                            HStack {
                                Text(addr)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button {
                                    viewModel.removeAddress(addr)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Groups
                Section {
                    ForEach(viewModel.config.groups) { group in
                        Button {
                            viewModel.toggleGroupInSelection(group.name)
                        } label: {
                            HStack {
                                Image(systemName: viewModel.newMappingGroups.contains(group.name) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.newMappingGroups.contains(group.name) ? .techniluxPrimary : .secondary)

                                VStack(alignment: .leading) {
                                    Text(group.name)
                                        .foregroundStyle(.primary)
                                    if let desc = group.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("Groups")
                        if viewModel.isMultiGroupMode {
                            Text("(Multi-select)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Note
                Section("Note (Optional)") {
                    TextField("e.g., Living room devices", text: $viewModel.newMappingNote)
                }
            }
            .navigationTitle(viewModel.editingMappingIndex != nil ? "Edit Mapping" : "Add Mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.editingMappingIndex != nil ? "Update" : "Add") {
                        viewModel.saveMapping()
                    }
                    .disabled(viewModel.newMappingAddresses.isEmpty || viewModel.newMappingGroups.isEmpty)
                }
            }
        }
    }
}

struct GroupConfigView: View {
    @Binding var group: BlockingGroup
    @Bindable var viewModel: AdvancedBlockingViewModel
    let groupIndex: Int

    @State private var newAllowed = ""
    @State private var newBlocked = ""
    @State private var newAllowUrl = ""
    @State private var newBlockUrl = ""
    @State private var newAllowRegex = ""
    @State private var newBlockRegex = ""
    @State private var newAdblockUrl = ""
    @State private var newBlockingAddress = ""

    var body: some View {
        // Group name & settings
        TextField("Group Name", text: $group.name)
            .onChange(of: group.name) { oldValue, newValue in
                if oldValue != newValue {
                    viewModel.renameGroup(at: groupIndex, to: newValue)
                }
            }

        TextField("Description (optional)", text: Binding(
            get: { group.description ?? "" },
            set: { group.description = $0.isEmpty ? nil : $0 }
        ))
        .font(.subheadline)

        Toggle("Enable Blocking", isOn: $group.enableBlocking)
        Toggle("Block as NxDomain", isOn: $group.blockAsNxDomain)

        // Group actions
        HStack {
            Button {
                viewModel.duplicateGroup(at: groupIndex)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
                    .font(.caption)
            }

            Spacer()

            if viewModel.config.groups.count > 1 {
                Button(role: .destructive) {
                    viewModel.deleteGroup(at: groupIndex)
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.borderless)

        // Blocking Addresses
        DisclosureGroup("Blocking Addresses (\(group.blockingAddresses.count))") {
            listEditor(
                items: $group.blockingAddresses,
                newItem: $newBlockingAddress,
                placeholder: "0.0.0.0 or ::",
                suggestions: ["0.0.0.0", "::", "127.0.0.1"]
            )
        }

        // Allowed Domains
        DisclosureGroup("Allowed Domains (\(group.allowed.count))") {
            listEditor(
                items: $group.allowed,
                newItem: $newAllowed,
                placeholder: "domain.com"
            )
        }

        // Blocked Domains
        DisclosureGroup("Blocked Domains (\(group.blocked.count))") {
            listEditor(
                items: $group.blocked,
                newItem: $newBlocked,
                placeholder: "domain.com"
            )
        }

        // Allow List URLs
        DisclosureGroup("Allow List URLs (\(group.allowListUrls.count))") {
            listEditor(
                items: $group.allowListUrls,
                newItem: $newAllowUrl,
                placeholder: "https://..."
            )
        }

        // Block List URLs
        DisclosureGroup("Block List URLs (\(group.blockListUrls.count))") {
            listEditor(
                items: $group.blockListUrls,
                newItem: $newBlockUrl,
                placeholder: "https://..."
            )
        }

        // Allowed Regex
        DisclosureGroup("Allowed Regex (\(group.allowedRegex.count))") {
            listEditor(
                items: $group.allowedRegex,
                newItem: $newAllowRegex,
                placeholder: "regex pattern"
            )
        }

        // Blocked Regex
        DisclosureGroup("Blocked Regex (\(group.blockedRegex.count))") {
            listEditor(
                items: $group.blockedRegex,
                newItem: $newBlockRegex,
                placeholder: "regex pattern"
            )
        }

        // Adblock List URLs
        DisclosureGroup("Adblock List URLs (\(group.adblockListUrls.count))") {
            listEditor(
                items: $group.adblockListUrls,
                newItem: $newAdblockUrl,
                placeholder: "https://..."
            )
        }
    }

    @ViewBuilder
    private func listEditor(items: Binding<[String]>, newItem: Binding<String>, placeholder: String, suggestions: [String]? = nil) -> some View {
        HStack {
            TextField(placeholder, text: newItem)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    addItem(to: items, from: newItem)
                }
            Button("Add") {
                addItem(to: items, from: newItem)
            }
            .disabled(newItem.wrappedValue.isEmpty)
        }

        if let suggestions = suggestions {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            if !items.wrappedValue.contains(suggestion) {
                                items.wrappedValue.append(suggestion)
                            }
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(items.wrappedValue.contains(suggestion) ? Color.techniluxPrimary.opacity(0.3) : Color.secondary.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .disabled(items.wrappedValue.contains(suggestion))
                    }
                }
            }
        }

        ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { index, item in
            HStack {
                Text(item)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                Spacer()
                Button {
                    items.wrappedValue.remove(at: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func addItem(to items: Binding<[String]>, from newItem: Binding<String>) {
        let trimmed = newItem.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !items.wrappedValue.contains(trimmed) else { return }
        items.wrappedValue.append(trimmed)
        newItem.wrappedValue = ""
    }
}

// MARK: - Preview

#Preview {
    AdvancedBlockingConfigView(
        viewModel: AdvancedBlockingViewModel(
            configJson: "{}",
            appName: "Advanced Blocking Plus",
            onSave: { _ in },
            onCancel: { }
        )
    )
}
