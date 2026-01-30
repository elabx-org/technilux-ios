import SwiftUI

@MainActor
@Observable
final class DNSClientViewModel {
    var server = "this-server"
    var domain = ""
    var recordType = "A"
    var queryProtocol = "Udp"
    var dnssec = false

    var result: DnsResolveResponse?
    var isLoading = false
    var error: String?

    let recordTypes = ["A", "AAAA", "CNAME", "MX", "NS", "PTR", "SOA", "SRV", "TXT", "CAA", "ANY"]
    let protocols = ["Udp", "Tcp", "Tls", "Https", "Quic"]

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    func resolve() async {
        guard !domain.isEmpty else { return }

        isLoading = true
        error = nil
        result = nil
        defer { isLoading = false }

        do {
            result = try await client.resolveDns(
                server: server,
                domain: domain,
                type: recordType,
                queryProtocol: queryProtocol,
                dnssec: dnssec,
                node: cluster.nodeParam
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func flushCache() async {
        do {
            try await client.flushDnsClientCache()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct DNSClientView: View {
    @State private var viewModel = DNSClientViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Query form
                    queryForm

                    // Resolve button
                    Button {
                        Task { await viewModel.resolve() }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Resolve")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.glassPrimary)
                    .disabled(viewModel.domain.isEmpty || viewModel.isLoading)

                    // Error
                    if let error = viewModel.error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Results
                    if let result = viewModel.result {
                        resultsView(result)
                    }
                }
                .padding()
            }
            .navigationTitle("DNS Client")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await viewModel.flushCache() }
                        } label: {
                            Label("Flush Cache", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var queryForm: some View {
        GlassCard {
            VStack(spacing: 16) {
                // Server
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("this-server", text: $viewModel.server)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .glassBackground()
                }

                // Domain
                VStack(alignment: .leading, spacing: 8) {
                    Text("Domain")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("example.com", text: $viewModel.domain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .glassBackground()
                }

                // Record Type
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Type", selection: $viewModel.recordType) {
                            ForEach(viewModel.recordTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Protocol")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Protocol", selection: $viewModel.queryProtocol) {
                            ForEach(viewModel.protocols, id: \.self) { proto in
                                Text(proto).tag(proto)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // DNSSEC toggle
                Toggle("DNSSEC Validation", isOn: $viewModel.dnssec)
            }
        }
    }

    @ViewBuilder
    private func resultsView(_ result: DnsResolveResponse) -> some View {
        VStack(spacing: 16) {
            // Metadata section
            if let metadata = result.Metadata {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Query Info")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            InfoRow(label: "Name Server", value: metadata.nameServer ?? "Unknown")
                            InfoRow(label: "Protocol", value: metadata.queryProtocol ?? "Unknown")
                            InfoRow(label: "Response Size", value: "\(metadata.datagramSize ?? 0) bytes")
                            InfoRow(label: "Round Trip", value: metadata.roundTripTime ?? "N/A")
                        }
                    }
                }
            }

            // Response header
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Response")
                            .font(.headline)

                        Spacer()

                        if let rcode = result.rcode {
                            StatusBadge(
                                text: rcode,
                                color: rcode == "NoError" ? .green : .red
                            )
                        }
                    }

                    HStack(spacing: 8) {
                        if result.authoritative {
                            StatusBadge(text: "Authoritative", color: .blue)
                        }
                        if result.recursionAvailable {
                            StatusBadge(text: "Recursive", color: .blue)
                        }
                        if result.authenticData {
                            StatusBadge(text: "Authenticated", color: .green)
                        }
                    }
                }
            }

            // Answer section
            if !result.answer.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Answer (\(result.answer.count))")
                            .font(.headline)

                        ForEach(Array(result.answer.enumerated()), id: \.offset) { index, answer in
                            AnswerRow(answer: answer)
                            if index < result.answer.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }

            // Authority section
            if !result.authority.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Authority (\(result.authority.count))")
                            .font(.headline)

                        ForEach(Array(result.authority.enumerated()), id: \.offset) { index, auth in
                            AnswerRow(answer: auth)
                            if index < result.authority.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }

            // No results message
            if result.answer.isEmpty && result.authority.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(.orange)
                        Text("No Records Found")
                            .font(.headline)
                        Text("The query returned no answer or authority records")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }
}

struct AnswerRow: View {
    let answer: DnsAnswer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(answer.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                StatusBadge(text: answer.recordType, color: .techniluxPrimary)
            }

            if let rData = answer.rData {
                Text(formatRData(rData))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("TTL: \(answer.ttl)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if let status = answer.dnssecStatus {
                    Text("• DNSSEC: \(status)")
                        .font(.caption2)
                        .foregroundStyle(status == "Secure" ? Color.green : Color.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatRData(_ rData: [String: AnyCodable]) -> String {
        // Format common rData fields nicely
        if let ipAddress = rData["IPAddress"] {
            return "\(ipAddress)"
        }
        if let ptrName = rData["PTRDomainName"] {
            return "\(ptrName)"
        }
        if let cname = rData["CNAMEDomainName"] {
            return "\(cname)"
        }
        if let exchange = rData["Exchange"], let preference = rData["Preference"] {
            return "\(preference) \(exchange)"
        }
        if let nsDomain = rData["NSDomainName"] {
            return "\(nsDomain)"
        }
        if let text = rData["Text"] {
            return "\"\(text)\""
        }

        // Fallback: show all key-value pairs
        return rData.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

#Preview("DNS Client View") {
    DNSClientView()
}
