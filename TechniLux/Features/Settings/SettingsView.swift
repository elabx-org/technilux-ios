import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    var settings: DnsSettings?
    var isLoading = false
    var isSaving = false
    var error: String?

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    func loadSettings() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            settings = try await client.getSettings(node: cluster.nodeParam)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveSettings(_ updates: [String: Any]) async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            try await client.setSettings(settings: updates, node: cluster.nodeParam)
            await loadSettings()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func forceUpdateBlockLists() async {
        do {
            try await client.forceUpdateBlockLists(node: cluster.nodeParam)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func checkForUpdate() async -> UpdateCheckResponse? {
        do {
            return try await client.checkForUpdate()
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Bindable var cluster = ClusterService.shared

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.settings == nil {
                    ProgressView("Loading settings...")
                } else if let settings = viewModel.settings {
                    settingsList(settings)
                } else {
                    EmptyStateView(
                        icon: "gearshape",
                        title: "Error",
                        description: viewModel.error ?? "Failed to load settings"
                    )
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ClusterNodePicker()
                }
            }
            .refreshable {
                await viewModel.loadSettings()
            }
            .task {
                await viewModel.loadSettings()
            }
            .onChange(of: cluster.selectedNode) { _, _ in
                Task { await viewModel.loadSettings() }
            }
        }
    }

    private func settingsList(_ settings: DnsSettings) -> some View {
        List {
            // General
            Section("General") {
                NavigationLink {
                    GeneralSettingsView(settings: settings, viewModel: viewModel)
                } label: {
                    Label("DNS Server", systemImage: "server.rack")
                }

                InfoRow(label: "Version", value: settings.version)
                InfoRow(label: "Domain", value: settings.dnsServerDomain)
            }

            // Protocols
            Section("Protocols") {
                NavigationLink {
                    ProtocolSettingsView(settings: settings, viewModel: viewModel)
                } label: {
                    Label("DNS Protocols", systemImage: "network")
                }
            }

            // Cache
            Section("Cache") {
                NavigationLink {
                    CacheSettingsView(settings: settings, viewModel: viewModel)
                } label: {
                    Label("Cache Settings", systemImage: "memorychip")
                }
            }

            // Blocking
            Section("Blocking") {
                NavigationLink {
                    BlockingSettingsView(settings: settings, viewModel: viewModel)
                } label: {
                    Label("Blocking Settings", systemImage: "hand.raised")
                }

                Button {
                    Task { await viewModel.forceUpdateBlockLists() }
                } label: {
                    Label("Force Update Block Lists", systemImage: "arrow.clockwise")
                }
            }

            // Forwarders
            Section("Forwarders") {
                NavigationLink {
                    ForwarderSettingsView(settings: settings, viewModel: viewModel)
                } label: {
                    Label("Forwarder Settings", systemImage: "arrow.right.arrow.left")
                }
            }

            // Logging
            Section("Logging") {
                NavigationLink {
                    LoggingSettingsView(settings: settings, viewModel: viewModel)
                } label: {
                    Label("Logging Settings", systemImage: "doc.text")
                }
            }

            // TSIG
            if let tsigKeys = settings.tsigKeys, !tsigKeys.isEmpty {
                Section("TSIG Keys") {
                    ForEach(tsigKeys) { key in
                        VStack(alignment: .leading) {
                            Text(key.keyName)
                                .font(.subheadline)
                            Text(key.algorithmName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sub-settings Views

struct GeneralSettingsView: View {
    let settings: DnsSettings
    @Bindable var viewModel: SettingsViewModel

    @State private var dnsServerDomain: String = ""
    @State private var defaultRecordTtl: String = ""
    @State private var preferIPv6 = false
    @State private var dnssecValidation = false

    var body: some View {
        Form {
            Section("Server") {
                TextField("DNS Server Domain", text: $dnsServerDomain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Defaults") {
                TextField("Default Record TTL", text: $defaultRecordTtl)
                    .keyboardType(.numberPad)
            }

            Section("Options") {
                Toggle("Prefer IPv6", isOn: $preferIPv6)
                Toggle("DNSSEC Validation", isOn: $dnssecValidation)
            }

            Section {
                Button("Save Changes") {
                    Task {
                        var updates: [String: Any] = [:]
                        updates["dnsServerDomain"] = dnsServerDomain
                        if let ttl = Int(defaultRecordTtl) {
                            updates["defaultRecordTtl"] = ttl
                        }
                        updates["preferIPv6"] = preferIPv6
                        updates["dnssecValidation"] = dnssecValidation
                        await viewModel.saveSettings(updates)
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .navigationTitle("General")
        .onAppear {
            dnsServerDomain = settings.dnsServerDomain
            defaultRecordTtl = "\(settings.defaultRecordTtl)"
            preferIPv6 = settings.preferIPv6 ?? false
            dnssecValidation = settings.dnssecValidation ?? false
        }
    }
}

struct ProtocolSettingsView: View {
    let settings: DnsSettings
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section("DNS over HTTPS") {
                InfoRow(label: "Enabled", value: settings.enableDnsOverHttps ?? false ? "Yes" : "No")
                if let port = settings.dnsOverHttpsPort {
                    InfoRow(label: "Port", value: "\(port)")
                }
            }

            Section("DNS over TLS") {
                InfoRow(label: "Enabled", value: settings.enableDnsOverTls ?? false ? "Yes" : "No")
                if let port = settings.dnsOverTlsPort {
                    InfoRow(label: "Port", value: "\(port)")
                }
            }

            Section("DNS over QUIC") {
                InfoRow(label: "Enabled", value: settings.enableDnsOverQuic ?? false ? "Yes" : "No")
                if let port = settings.dnsOverQuicPort {
                    InfoRow(label: "Port", value: "\(port)")
                }
            }
        }
        .navigationTitle("Protocols")
    }
}

struct CacheSettingsView: View {
    let settings: DnsSettings
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section("Cache Size") {
                if let max = settings.cacheMaximumEntries {
                    InfoRow(label: "Maximum Entries", value: "\(max)")
                }
            }

            Section("TTL") {
                if let min = settings.cacheMinimumRecordTtl {
                    InfoRow(label: "Minimum TTL", value: "\(min)s")
                }
                if let max = settings.cacheMaximumRecordTtl {
                    InfoRow(label: "Maximum TTL", value: "\(max)s")
                }
            }

            Section("Options") {
                InfoRow(label: "Save Cache", value: settings.saveCache ?? false ? "Yes" : "No")
                InfoRow(label: "Serve Stale", value: settings.serveStale ?? false ? "Yes" : "No")
            }
        }
        .navigationTitle("Cache")
    }
}

struct BlockingSettingsView: View {
    let settings: DnsSettings
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section("Status") {
                InfoRow(label: "Blocking Enabled", value: settings.enableBlocking ?? false ? "Yes" : "No")
                if let type = settings.blockingType {
                    InfoRow(label: "Blocking Type", value: type)
                }
            }

            Section("Block Lists") {
                if let urls = settings.blockListUrls, !urls.isEmpty {
                    ForEach(urls, id: \.self) { url in
                        Text(url)
                            .font(.caption)
                            .lineLimit(2)
                    }
                } else {
                    Text("No block lists configured")
                        .foregroundStyle(.secondary)
                }
            }

            if let interval = settings.blockListUpdateIntervalHours {
                Section("Updates") {
                    InfoRow(label: "Update Interval", value: "\(interval) hours")
                    if let nextUpdate = settings.blockListNextUpdatedOn {
                        InfoRow(label: "Next Update", value: nextUpdate)
                    }
                }
            }
        }
        .navigationTitle("Blocking")
    }
}

struct ForwarderSettingsView: View {
    let settings: DnsSettings
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        List {
            if let forwarders = settings.forwarders, !forwarders.isEmpty {
                Section("Forwarders") {
                    ForEach(forwarders, id: \.self) { forwarder in
                        Text(forwarder)
                            .font(.subheadline)
                    }
                }
            } else {
                Section {
                    Text("No forwarders configured")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Options") {
                if let protocol = settings.forwarderProtocol {
                    InfoRow(label: "Protocol", value: `protocol`)
                }
                InfoRow(label: "Concurrent", value: settings.concurrentForwarding ?? false ? "Yes" : "No")
            }
        }
        .navigationTitle("Forwarders")
    }
}

struct LoggingSettingsView: View {
    let settings: DnsSettings
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section("Status") {
                InfoRow(label: "Logging Enabled", value: settings.enableLogging ?? false ? "Yes" : "No")
                InfoRow(label: "Query Logging", value: settings.logQueries ?? false ? "Yes" : "No")
            }

            Section("Options") {
                InfoRow(label: "Use Local Time", value: settings.useLocalTime ?? false ? "Yes" : "No")
                if let days = settings.maxLogFileDays {
                    InfoRow(label: "Max Log Days", value: "\(days)")
                }
            }

            if let folder = settings.logFolder {
                Section("Storage") {
                    InfoRow(label: "Log Folder", value: folder)
                }
            }
        }
        .navigationTitle("Logging")
    }
}

#Preview("Settings View") {
    SettingsView()
}
