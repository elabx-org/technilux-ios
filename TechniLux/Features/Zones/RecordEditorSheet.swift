import SwiftUI

/// Supported record types for editing
enum EditableRecordType: String, CaseIterable, Identifiable {
    case a = "A"
    case aaaa = "AAAA"
    case cname = "CNAME"
    case aname = "ANAME"
    case ptr = "PTR"
    case mx = "MX"
    case txt = "TXT"
    case ns = "NS"
    case srv = "SRV"
    case caa = "CAA"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a: return "A - IPv4 Address"
        case .aaaa: return "AAAA - IPv6 Address"
        case .cname: return "CNAME - Canonical Name"
        case .aname: return "ANAME - Alias"
        case .ptr: return "PTR - Pointer"
        case .mx: return "MX - Mail Exchange"
        case .txt: return "TXT - Text"
        case .ns: return "NS - Name Server"
        case .srv: return "SRV - Service"
        case .caa: return "CAA - Certification Authority"
        }
    }

    var toRecordType: RecordType {
        RecordType(rawValue: rawValue) ?? .a
    }
}

// MARK: - Add Record Sheet

struct AddRecordSheet: View {
    @Environment(\.dismiss) private var dismiss

    let zoneName: String
    let onAdd: (String, RecordType, Int, [String: Any]) async throws -> Void

    @State private var subdomain = ""
    @State private var recordType: EditableRecordType = .a
    @State private var ttl = "3600"

    // Record-specific fields
    @State private var ipAddress = ""
    @State private var targetDomain = ""
    @State private var text = ""
    @State private var preference = "10"
    @State private var exchange = ""
    @State private var priority = "0"
    @State private var weight = "0"
    @State private var port = "0"
    @State private var target = ""
    @State private var nameServer = ""
    @State private var caaFlags = "0"
    @State private var caaTag = "issue"
    @State private var caaValue = ""

    // Common fields
    @State private var overwrite = false
    @State private var comments = ""

    @State private var isLoading = false
    @State private var error: String?

    private var isReverseZone: Bool {
        zoneName.hasSuffix(".in-addr.arpa") || zoneName.hasSuffix(".ip6.arpa")
    }

    private var fullDomain: String {
        subdomain.isEmpty ? zoneName : "\(subdomain).\(zoneName)"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section("Record Info") {
                    HStack {
                        TextField("subdomain", text: $subdomain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))

                        Text(".\(zoneName)")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                    }

                    Picker("Type", selection: $recordType) {
                        ForEach(EditableRecordType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    HStack {
                        Text("TTL")
                        Spacer()
                        TextField("3600", text: $ttl)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("seconds")
                            .foregroundStyle(.secondary)
                    }
                }

                // Type-specific fields
                Section("Record Data") {
                    recordDataFields
                }

                // Options
                Section("Options") {
                    Toggle("Overwrite existing", isOn: $overwrite)

                    TextField("Comments (optional)", text: $comments, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addRecord()
                        }
                    }
                    .disabled(isLoading || !isValid)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .onAppear {
                if isReverseZone {
                    recordType = .ptr
                }
            }
        }
    }

    @ViewBuilder
    private var recordDataFields: some View {
        switch recordType {
        case .a:
            TextField("IPv4 Address", text: $ipAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .monospaced))

        case .aaaa:
            TextField("IPv6 Address", text: $ipAddress)
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))

        case .cname, .aname:
            TextField("Target Domain", text: $targetDomain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        case .ptr:
            TextField("Domain Name", text: $targetDomain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        case .mx:
            HStack {
                Text("Priority")
                Spacer()
                TextField("10", text: $preference)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            TextField("Mail Server", text: $exchange)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        case .txt:
            TextField("Text Value", text: $text, axis: .vertical)
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))
                .lineLimit(3...6)

        case .ns:
            TextField("Name Server", text: $nameServer)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        case .srv:
            HStack {
                Text("Priority")
                Spacer()
                TextField("0", text: $priority)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Weight")
                Spacer()
                TextField("0", text: $weight)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Port")
                Spacer()
                TextField("0", text: $port)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            TextField("Target", text: $target)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        case .caa:
            HStack {
                Text("Flags")
                Spacer()
                TextField("0", text: $caaFlags)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            Picker("Tag", selection: $caaTag) {
                Text("issue").tag("issue")
                Text("issuewild").tag("issuewild")
                Text("iodef").tag("iodef")
            }

            TextField("Value", text: $caaValue)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
        }
    }

    private var isValid: Bool {
        switch recordType {
        case .a:
            return !ipAddress.isEmpty
        case .aaaa:
            return !ipAddress.isEmpty
        case .cname, .aname, .ptr:
            return !targetDomain.isEmpty
        case .mx:
            return !exchange.isEmpty
        case .txt:
            return !text.isEmpty
        case .ns:
            return !nameServer.isEmpty
        case .srv:
            return !target.isEmpty
        case .caa:
            return !caaValue.isEmpty
        }
    }

    private func buildRecordData() -> [String: Any] {
        var data: [String: Any] = [
            "overwrite": overwrite,
            "comments": comments
        ]

        switch recordType {
        case .a, .aaaa:
            data["ipAddress"] = ipAddress
        case .cname, .aname:
            data["cname"] = targetDomain
        case .ptr:
            data["ptrName"] = targetDomain
        case .mx:
            data["preference"] = Int(preference) ?? 10
            data["exchange"] = exchange
        case .txt:
            data["text"] = text
        case .ns:
            data["nameServer"] = nameServer
        case .srv:
            data["priority"] = Int(priority) ?? 0
            data["weight"] = Int(weight) ?? 0
            data["port"] = Int(port) ?? 0
            data["target"] = target
        case .caa:
            data["flags"] = Int(caaFlags) ?? 0
            data["tag"] = caaTag
            data["value"] = caaValue
        }

        return data
    }

    private func addRecord() async {
        isLoading = true
        error = nil

        do {
            try await onAdd(
                fullDomain,
                recordType.toRecordType,
                Int(ttl) ?? 3600,
                buildRecordData()
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Edit Record Sheet

struct EditRecordSheet: View {
    @Environment(\.dismiss) private var dismiss

    let zoneName: String
    let record: DnsRecord
    let onUpdate: (DnsRecord, String, Int, [String: Any], Bool) async throws -> Void

    @State private var subdomain: String
    @State private var ttl: String
    @State private var disabled: Bool

    // Record-specific fields
    @State private var ipAddress: String
    @State private var targetDomain: String
    @State private var text: String
    @State private var preference: String
    @State private var exchange: String
    @State private var priority: String
    @State private var weight: String
    @State private var port: String
    @State private var target: String
    @State private var nameServer: String
    @State private var caaFlags: String
    @State private var caaTag: String
    @State private var caaValue: String

    @State private var isLoading = false
    @State private var error: String?

    init(zoneName: String, record: DnsRecord, onUpdate: @escaping (DnsRecord, String, Int, [String: Any], Bool) async throws -> Void) {
        self.zoneName = zoneName
        self.record = record
        self.onUpdate = onUpdate

        // Extract subdomain from full name
        let name = record.name
        if name == zoneName || name == "@" {
            _subdomain = State(initialValue: "")
        } else if name.hasSuffix(".\(zoneName)") {
            _subdomain = State(initialValue: String(name.dropLast(zoneName.count + 1)))
        } else {
            _subdomain = State(initialValue: name)
        }

        _ttl = State(initialValue: String(record.ttl))
        _disabled = State(initialValue: record.disabled)

        // Initialize type-specific fields from rData
        let rData = record.rData
        _ipAddress = State(initialValue: rData["ipAddress"]?.description ?? rData["address"]?.description ?? "")
        _targetDomain = State(initialValue: rData["cname"]?.description ?? rData["ptrName"]?.description ?? "")
        _text = State(initialValue: rData["text"]?.description ?? "")
        _preference = State(initialValue: rData["preference"]?.description ?? "10")
        _exchange = State(initialValue: rData["exchange"]?.description ?? "")
        _priority = State(initialValue: rData["priority"]?.description ?? "0")
        _weight = State(initialValue: rData["weight"]?.description ?? "0")
        _port = State(initialValue: rData["port"]?.description ?? "0")
        _target = State(initialValue: rData["target"]?.description ?? "")
        _nameServer = State(initialValue: rData["nameServer"]?.description ?? rData["nsDomainName"]?.description ?? "")
        _caaFlags = State(initialValue: rData["flags"]?.description ?? "0")
        _caaTag = State(initialValue: rData["tag"]?.description ?? "issue")
        _caaValue = State(initialValue: rData["value"]?.description ?? "")
    }

    private var fullDomain: String {
        subdomain.isEmpty ? zoneName : "\(subdomain).\(zoneName)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Record Info") {
                    HStack {
                        TextField("subdomain", text: $subdomain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))

                        Text(".\(zoneName)")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                    }

                    HStack {
                        Text("Type")
                        Spacer()
                        Text(record.type.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("TTL")
                        Spacer()
                        TextField("3600", text: $ttl)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("seconds")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Record Data") {
                    editRecordDataFields
                }

                Section {
                    Toggle("Disabled", isOn: $disabled)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await updateRecord()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder
    private var editRecordDataFields: some View {
        switch record.type {
        case .a:
            TextField("IPv4 Address", text: $ipAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .monospaced))

        case .aaaa:
            TextField("IPv6 Address", text: $ipAddress)
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))

        case .cname, .aname:
            TextField("Target Domain", text: $targetDomain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        case .ptr:
            TextField("Domain Name", text: $targetDomain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        case .mx:
            HStack {
                Text("Priority")
                Spacer()
                TextField("10", text: $preference)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            TextField("Mail Server", text: $exchange)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        case .txt:
            TextField("Text Value", text: $text, axis: .vertical)
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))
                .lineLimit(3...6)

        case .ns:
            TextField("Name Server", text: $nameServer)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        case .srv:
            HStack {
                Text("Priority")
                Spacer()
                TextField("0", text: $priority)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Weight")
                Spacer()
                TextField("0", text: $weight)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Port")
                Spacer()
                TextField("0", text: $port)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            TextField("Target", text: $target)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        case .caa:
            HStack {
                Text("Flags")
                Spacer()
                TextField("0", text: $caaFlags)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            Picker("Tag", selection: $caaTag) {
                Text("issue").tag("issue")
                Text("issuewild").tag("issuewild")
                Text("iodef").tag("iodef")
            }

            TextField("Value", text: $caaValue)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

        default:
            Text("This record type cannot be edited")
                .foregroundStyle(.secondary)
        }
    }

    private func buildRecordData() -> [String: Any] {
        var data: [String: Any] = [:]

        switch record.type {
        case .a, .aaaa:
            data["ipAddress"] = ipAddress
        case .cname, .aname:
            data["cname"] = targetDomain
        case .ptr:
            data["ptrName"] = targetDomain
        case .mx:
            data["preference"] = Int(preference) ?? 10
            data["exchange"] = exchange
        case .txt:
            data["text"] = text
        case .ns:
            data["nameServer"] = nameServer
        case .srv:
            data["priority"] = Int(priority) ?? 0
            data["weight"] = Int(weight) ?? 0
            data["port"] = Int(port) ?? 0
            data["target"] = target
        case .caa:
            data["flags"] = Int(caaFlags) ?? 0
            data["tag"] = caaTag
            data["value"] = caaValue
        default:
            break
        }

        return data
    }

    private func updateRecord() async {
        isLoading = true
        error = nil

        do {
            try await onUpdate(
                record,
                fullDomain,
                Int(ttl) ?? 3600,
                buildRecordData(),
                disabled
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Delete Confirmation

struct DeleteRecordAlert: View {
    let record: DnsRecord
    let onDelete: () async -> Void
    @Binding var isPresented: Bool

    @State private var isDeleting = false

    var body: some View {
        EmptyView()
            .alert("Delete Record", isPresented: $isPresented) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        isDeleting = true
                        await onDelete()
                        isDeleting = false
                        isPresented = false
                    }
                }
                .disabled(isDeleting)
            } message: {
                Text("Are you sure you want to delete this \(record.type.rawValue) record for \(record.name)?")
            }
    }
}
