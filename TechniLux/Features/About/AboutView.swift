import SwiftUI

struct AboutView: View {
    @State private var serverInfo: ServerInfo?
    @State private var isLoading = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            List {
                // App info
                Section {
                    VStack(spacing: 16) {
                        Image("TechniLuxLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 20))

                        Text("TechniLux")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("DNS Server Management")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }

                // Version info
                Section("Version") {
                    InfoRow(label: "TechniLux iOS", value: "v\(appVersion) (\(buildNumber))")

                    if let serverInfo {
                        InfoRow(label: "Technitium Server", value: serverInfo.version)

                        if let uptime = serverInfo.uptimestamp {
                            InfoRow(label: "Server Uptime", value: formatUptime(uptime))
                        }
                    } else if isLoading {
                        HStack {
                            Text("Server Version")
                            Spacer()
                            ProgressView()
                        }
                    }
                }

                // Server info
                if let serverInfo {
                    Section("Server") {
                        if let domain = serverInfo.dnsServerDomain {
                            InfoRow(label: "DNS Domain", value: domain)
                        }

                        InfoRow(
                            label: "DNSSEC Validation",
                            value: serverInfo.dnssecValidation ?? false ? "Enabled" : "Disabled"
                        )

                        InfoRow(
                            label: "Cluster",
                            value: serverInfo.clusterInitialized ?? false ? "Initialized" : "Not Configured"
                        )
                    }
                }

                // Links
                Section("Links") {
                    Link(destination: URL(string: "https://github.com/elabx-org/technilux")!) {
                        Label("TechniLux Web UI", systemImage: "globe")
                    }

                    Link(destination: URL(string: "https://github.com/elabx-org/technilux-ios")!) {
                        Label("TechniLux iOS", systemImage: "iphone")
                    }

                    Link(destination: URL(string: "https://technitium.com/dns/")!) {
                        Label("Technitium DNS Server", systemImage: "server.rack")
                    }

                    Link(destination: URL(string: "https://github.com/TechnitiumSoftware/DnsServer")!) {
                        Label("Server Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }

                // Credits
                Section("Credits") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TechniLux iOS")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("A modern iOS client for Technitium DNS Server. Built with SwiftUI.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Technitium DNS Server")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Copyright \u{00A9} Technitium Software. Licensed under GNU GPL v3.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("About")
            .task {
                await loadServerInfo()
            }
        }
    }

    private func loadServerInfo() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await TechnitiumClient.shared.checkSession()
            serverInfo = session.info
        } catch {
            // Ignore errors - server info is optional
        }
    }

    private func formatUptime(_ timestamp: String) -> String {
        // Timestamp is in ISO 8601 format
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: timestamp) else {
            return timestamp
        }

        let interval = Date().timeIntervalSince(date)
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview("About View") {
    AboutView()
}
