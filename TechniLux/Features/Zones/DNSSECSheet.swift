import SwiftUI

struct DNSSECSheet: View {
    @Environment(\.dismiss) private var dismiss

    let zoneName: String
    let dnssecStatus: String
    let onSign: () async throws -> Void
    let onUnsign: () async throws -> Void

    @State private var isLoading = false
    @State private var error: String?
    @State private var properties: DnssecProperties?

    @State private var algorithm = "ECDSA_P256_SHA256"
    @State private var dnsKeyTtl = "86400"
    @State private var zskRolloverDays = "30"
    @State private var nxProof = "NSEC3"
    @State private var iterations = "0"
    @State private var saltLength = "0"

    private var isSigned: Bool {
        dnssecStatus == "SignedWithNSEC" || dnssecStatus == "SignedWithNSEC3"
    }

    var body: some View {
        NavigationStack {
            Form {
                if isSigned {
                    signedContent
                } else {
                    unsignedContent
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("DNSSEC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSigned {
                        Button("Remove DNSSEC", role: .destructive) {
                            Task { await unsignZone() }
                        }
                        .disabled(isLoading)
                    } else {
                        Button("Sign Zone") {
                            Task { await signZone() }
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .task {
                if isSigned {
                    await loadProperties()
                }
            }
        }
    }

    @ViewBuilder
    private var signedContent: some View {
        Section {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("Zone is signed")
                        .font(.headline)
                    Text("Status: \(dnssecStatus)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }

        if let props = properties {
            Section("DNSSEC Properties") {
                LabeledContent("Algorithm", value: props.algorithm ?? "-")
                LabeledContent("DNSKEY TTL", value: "\(props.dnsKeyTtl ?? 0) seconds")
                LabeledContent("ZSK Rollover", value: "\(props.zskRolloverDays ?? 0) days")
                LabeledContent("NX Proof", value: props.nxProof ?? "-")

                if props.nxProof == "NSEC3" {
                    LabeledContent("Iterations", value: "\(props.iterations ?? 0)")
                    LabeledContent("Salt Length", value: "\(props.saltLength ?? 0)")
                }
            }
        }

        Section {
            Text("Removing DNSSEC will make your zone unsigned. This may cause validation failures for clients that have cached your DS records.")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var unsignedContent: some View {
        Section {
            HStack {
                Image(systemName: "shield.slash")
                    .foregroundStyle(.secondary)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("Zone is not signed")
                        .font(.headline)
                    Text("Enable DNSSEC to secure your zone with cryptographic signatures.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }

        Section("Signing Options") {
            Picker("Algorithm", selection: $algorithm) {
                Text("ECDSA P-256 SHA-256").tag("ECDSA_P256_SHA256")
                Text("ECDSA P-384 SHA-384").tag("ECDSA_P384_SHA384")
                Text("RSA SHA-256").tag("RSA_SHA256")
                Text("RSA SHA-512").tag("RSA_SHA512")
            }

            HStack {
                Text("DNSKEY TTL")
                Spacer()
                TextField("86400", text: $dnsKeyTtl)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("sec")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("ZSK Rollover")
                Spacer()
                TextField("30", text: $zskRolloverDays)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("days")
                    .foregroundStyle(.secondary)
            }

            Picker("NX Proof", selection: $nxProof) {
                Text("NSEC").tag("NSEC")
                Text("NSEC3").tag("NSEC3")
            }

            if nxProof == "NSEC3" {
                HStack {
                    Text("Iterations")
                    Spacer()
                    TextField("0", text: $iterations)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                HStack {
                    Text("Salt Length")
                    Spacer()
                    TextField("0", text: $saltLength)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
        }

        Section("Benefits") {
            Label("Authenticates DNS responses cryptographically", systemImage: "checkmark")
            Label("Protects against cache poisoning attacks", systemImage: "checkmark")
            Label("Provides origin authentication for DNS data", systemImage: "checkmark")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func loadProperties() async {
        isLoading = true
        defer { isLoading = false }

        do {
            properties = try await TechnitiumClient.shared.getDnssecProperties(zone: zoneName)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func signZone() async {
        isLoading = true
        error = nil

        do {
            try await TechnitiumClient.shared.dnssecSign(
                zone: zoneName,
                algorithm: algorithm,
                dnsKeyTtl: Int(dnsKeyTtl) ?? 86400,
                zskRolloverDays: Int(zskRolloverDays) ?? 30,
                nxProof: nxProof,
                iterations: Int(iterations) ?? 0,
                saltLength: Int(saltLength) ?? 0
            )
            try await onSign()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func unsignZone() async {
        isLoading = true
        error = nil

        do {
            try await TechnitiumClient.shared.dnssecUnsign(zone: zoneName)
            try await onUnsign()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
