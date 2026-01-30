import SwiftUI

// MARK: - PTR Utilities

struct PTRInfo {
    let ptrName: String
    let reverseZone: String
    let ipAddress: String
}

/// Compute PTR info for an A/AAAA record
func computePtrInfo(for record: DnsRecord) -> PTRInfo? {
    let rData = record.rData
    guard let ipAddress = rData["ipAddress"]?.description ?? rData["address"]?.description else {
        return nil
    }

    if record.type == .a {
        // IPv4: 1.2.3.4 -> 4.3.2.1.in-addr.arpa
        let octets = ipAddress.split(separator: ".").map(String.init)
        guard octets.count == 4 else { return nil }

        let reversed = octets.reversed()
        let ptrName = reversed.joined(separator: ".")
        let reverseZone = "\(octets[2]).\(octets[1]).\(octets[0]).in-addr.arpa"

        return PTRInfo(ptrName: ptrName + ".in-addr.arpa", reverseZone: reverseZone, ipAddress: ipAddress)
    } else if record.type == .aaaa {
        // IPv6: expand and reverse nibbles
        // This is simplified - full IPv6 expansion would be more complex
        let reverseZone = "ip6.arpa"
        return PTRInfo(ptrName: "", reverseZone: reverseZone, ipAddress: ipAddress)
    }

    return nil
}

// MARK: - PTR Check Result

struct PTRCheckResult: Identifiable {
    let id = UUID()
    let record: DnsRecord
    let ipAddress: String
    let ptrName: String
    let reverseZone: String
    let exists: Bool
    let zoneExists: Bool
    let mismatch: Bool
    let existingTarget: String?
}

// MARK: - PTR Management Sheet

struct PTRManagementSheet: View {
    @Environment(\.dismiss) private var dismiss

    let zoneName: String
    let records: [DnsRecord]
    let onComplete: () -> Void

    @State private var isChecking = true
    @State private var isCreating = false
    @State private var checkResults: [PTRCheckResult] = []
    @State private var selectedIds: Set<UUID> = []
    @State private var existingZones: [Zone] = []
    @State private var creationResults: [(record: DnsRecord, status: String, message: String)] = []
    @State private var error: String?

    private var addressRecords: [DnsRecord] {
        records.filter { $0.type == .a || $0.type == .aaaa }
    }

    private var missingCount: Int {
        checkResults.filter { !$0.exists && !$0.mismatch }.count
    }

    private var mismatchCount: Int {
        checkResults.filter { $0.mismatch }.count
    }

    private var existingCount: Int {
        checkResults.filter { $0.exists && !$0.mismatch }.count
    }

    private var actionableCount: Int {
        checkResults.filter { !$0.exists || $0.mismatch }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if isChecking {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Checking existing PTR records...")
                            .foregroundStyle(.secondary)
                    }
                } else if !creationResults.isEmpty {
                    resultsView
                } else {
                    checkResultsView
                }
            }
            .navigationTitle("PTR Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(creationResults.isEmpty ? "Cancel" : "Close") {
                        if !creationResults.isEmpty {
                            onComplete()
                        }
                        dismiss()
                    }
                }

                if creationResults.isEmpty && !isChecking {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create \(selectedIds.count)") {
                            Task { await createPTRRecords() }
                        }
                        .disabled(selectedIds.isEmpty || isCreating)
                    }
                }
            }
            .task {
                await checkPTRRecords()
            }
        }
    }

    private var checkResultsView: some View {
        List {
            // Summary section
            Section {
                HStack {
                    Label("OK", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(existingCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Missing", systemImage: "minus.circle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(missingCount)")
                        .foregroundStyle(.secondary)
                }

                if mismatchCount > 0 {
                    HStack {
                        Label("Mismatch", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        Text("\(mismatchCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Summary")
            }

            if actionableCount > 0 {
                Section {
                    Button("Select All Missing") {
                        for result in checkResults where !result.exists || result.mismatch {
                            selectedIds.insert(result.id)
                        }
                    }

                    Button("Deselect All") {
                        selectedIds.removeAll()
                    }
                }
            }

            // Records
            Section {
                ForEach(checkResults) { result in
                    PTRCheckRow(
                        result: result,
                        isSelected: selectedIds.contains(result.id),
                        onToggle: {
                            if selectedIds.contains(result.id) {
                                selectedIds.remove(result.id)
                            } else {
                                selectedIds.insert(result.id)
                            }
                        }
                    )
                }
            } header: {
                Text("A/AAAA Records")
            }
        }
    }

    private var resultsView: some View {
        List {
            Section {
                let created = creationResults.filter { $0.status == "created" }.count
                let skipped = creationResults.filter { $0.status == "skipped" }.count
                let errors = creationResults.filter { $0.status == "error" }.count

                HStack {
                    Label("Created", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(created)")
                }

                HStack {
                    Label("Skipped", systemImage: "minus.circle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(skipped)")
                }

                if errors > 0 {
                    HStack {
                        Label("Errors", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        Text("\(errors)")
                    }
                }
            } header: {
                Text("Results")
            }

            Section {
                ForEach(Array(creationResults.enumerated()), id: \.offset) { _, result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(result.record.name)
                                .font(.system(.subheadline, design: .monospaced))

                            Spacer()

                            statusIcon(for: result.status)
                        }

                        if !result.message.isEmpty {
                            Text(result.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Details")
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for status: String) -> some View {
        switch status {
        case "created":
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case "skipped":
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.orange)
        default:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func checkPTRRecords() async {
        isChecking = true
        checkResults = []
        error = nil

        do {
            // Get existing zones
            let zonesResponse = try await TechnitiumClient.shared.listZones(node: ClusterService.shared.nodeParam)
            existingZones = zonesResponse.zones

            var results: [PTRCheckResult] = []

            for record in addressRecords {
                guard let ptrInfo = computePtrInfo(for: record) else { continue }

                // Check if reverse zone exists
                let zoneExists = existingZones.contains { $0.name == ptrInfo.reverseZone }

                var exists = false
                var mismatch = false
                var existingTarget: String?

                if zoneExists {
                    // Check if PTR record exists
                    do {
                        let recordsResponse = try await TechnitiumClient.shared.getRecords(
                            zone: ptrInfo.reverseZone,
                            node: ClusterService.shared.nodeParam
                        )

                        // Find matching PTR
                        for ptrRecord in recordsResponse.records where ptrRecord.type == .ptr {
                            let ptrRecordName = ptrRecord.name.lowercased()
                            let expectedName = ptrInfo.ptrName.lowercased()

                            if ptrRecordName == expectedName || ptrRecordName.hasPrefix(ptrInfo.ipAddress.split(separator: ".").last ?? "") {
                                exists = true
                                existingTarget = ptrRecord.rData["ptrName"]?.description

                                // Check if it points to the right target
                                if let target = existingTarget, !target.lowercased().contains(record.name.lowercased()) {
                                    mismatch = true
                                }
                                break
                            }
                        }
                    } catch {
                        // Zone might not be accessible
                    }
                }

                results.append(PTRCheckResult(
                    record: record,
                    ipAddress: ptrInfo.ipAddress,
                    ptrName: ptrInfo.ptrName,
                    reverseZone: ptrInfo.reverseZone,
                    exists: exists,
                    zoneExists: zoneExists,
                    mismatch: mismatch,
                    existingTarget: existingTarget
                ))
            }

            checkResults = results

            // Pre-select all missing/mismatch
            for result in results where !result.exists || result.mismatch {
                selectedIds.insert(result.id)
            }

        } catch {
            self.error = error.localizedDescription
        }

        isChecking = false
    }

    private func createPTRRecords() async {
        isCreating = true
        creationResults = []

        let selectedResults = checkResults.filter { selectedIds.contains($0.id) }
        let client = TechnitiumClient.shared
        let node = ClusterService.shared.nodeParam

        for result in selectedResults {
            do {
                // Create reverse zone if needed
                if !result.zoneExists {
                    try await client.createZone(name: result.reverseZone, type: .primary, node: node)
                }

                // Extract the PTR hostname part
                let octets = result.ipAddress.split(separator: ".").map(String.init)
                guard octets.count == 4 else {
                    creationResults.append((result.record, "error", "Invalid IP format"))
                    continue
                }

                let ptrHostPart = octets[3]
                let ptrDomain = "\(ptrHostPart).\(result.reverseZone)"

                // Create PTR record
                try await client.addRecord(
                    zone: result.reverseZone,
                    domain: ptrDomain,
                    type: .ptr,
                    ttl: result.record.ttl,
                    recordData: [
                        "ptrName": result.record.name,
                        "overwrite": true
                    ],
                    node: node
                )

                creationResults.append((result.record, "created", "Created in \(result.reverseZone)"))
            } catch {
                creationResults.append((result.record, "error", error.localizedDescription))
            }
        }

        isCreating = false
    }
}

// MARK: - PTR Check Row

struct PTRCheckRow: View {
    let result: PTRCheckResult
    let isSelected: Bool
    let onToggle: () -> Void

    private var isActionable: Bool {
        !result.exists || result.mismatch
    }

    var body: some View {
        HStack {
            if isActionable {
                Button {
                    onToggle()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.record.name)
                        .font(.system(.subheadline, design: .monospaced))
                        .lineLimit(1)

                    Spacer()

                    statusBadge
                }

                Text(result.ipAddress)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                if result.mismatch, let existing = result.existingTarget {
                    Text("Points to: \(existing)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isActionable {
                onToggle()
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if result.mismatch {
            Label("Mismatch", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        } else if result.exists {
            Label("OK", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        } else if !result.zoneExists {
            Label("New Zone", systemImage: "plus.circle.fill")
                .font(.caption2)
                .foregroundStyle(.blue)
        } else {
            Label("Missing", systemImage: "minus.circle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}
