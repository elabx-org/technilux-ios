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
                    .buttonStyle(.glass)
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
                    if let result = viewModel.result?.result {
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
    private func resultsView(_ result: DnsResolveResult) -> some View {
        VStack(spacing: 16) {
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
                                color: rcode == "NOERROR" ? .green : .red
                            )
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        if let auth = result.authoritative {
                            InfoRow(label: "Authoritative", value: auth ? "Yes" : "No")
                        }
                        if let recursive = result.recursionAvailable {
                            InfoRow(label: "Recursive", value: recursive ? "Yes" : "No")
                        }
                        if let authentic = result.authenticData {
                            InfoRow(label: "Authentic", value: authentic ? "Yes" : "No")
                        }
                    }
                }
            }

            // Answer section
            if let answers = result.answer, !answers.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Answer (\(answers.count))")
                            .font(.headline)

                        ForEach(Array(answers.enumerated()), id: \.offset) { _, answer in
                            AnswerRow(answer: answer)
                            if answer != answers.last {
                                Divider()
                            }
                        }
                    }
                }
            }

            // Authority section
            if let authority = result.authority, !authority.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Authority (\(authority.count))")
                            .font(.headline)

                        ForEach(Array(authority.enumerated()), id: \.offset) { _, auth in
                            AnswerRow(answer: auth)
                            if auth != authority.last {
                                Divider()
                            }
                        }
                    }
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

                StatusBadge(text: answer.type, color: .techniluxPrimary)
            }

            if let rData = answer.rData {
                Text(formatRData(rData))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("TTL: \(answer.ttl)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func formatRData(_ rData: [String: AnyCodable]) -> String {
        rData.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

extension DnsAnswer: Equatable {
    static func == (lhs: DnsAnswer, rhs: DnsAnswer) -> Bool {
        lhs.name == rhs.name && lhs.type == rhs.type && lhs.ttl == rhs.ttl
    }
}

#Preview("DNS Client View") {
    DNSClientView()
}
