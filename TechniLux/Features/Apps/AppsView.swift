import SwiftUI

// TechniLux App Store models
struct TechniluxAppStore: Decodable {
    let apps: [TechniluxApp]
}

struct TechniluxApp: Decodable {
    let name: String
    let description: String
    let version: String
    let downloadUrl: String
    let size: String
    let schemaUrl: String?  // URL to UI schema JSON for dynamic config
}

@MainActor
@Observable
final class AppsViewModel {
    var installedApps: [DnsApp] = []
    var storeApps: [AppStoreEntry] = []
    var isLoading = false
    var isLoadingStore = false
    var storeLoaded = false
    var error: String?
    var storeError: String?

    var selectedTab = 0

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    // TechniLux app store URL
    private let techniluxAppStoreURL = "https://raw.githubusercontent.com/elabx-org/technilux-apps/main/appstore.json"

    func loadApps() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.listApps(node: cluster.nodeParam)
            installedApps = response.appsList
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadStoreApps() async {
        guard !storeLoaded else { return }

        isLoadingStore = true
        storeError = nil
        defer { isLoadingStore = false }

        var allApps: [AppStoreEntry] = []

        // Load official Technitium apps
        do {
            let response = try await client.listStoreApps()
            allApps.append(contentsOf: response.storeApps)
        } catch {
            print("Failed to load official store apps: \(error)")
        }

        // Load TechniLux apps from GitHub
        do {
            let techniluxApps = try await loadTechniluxApps()
            allApps.append(contentsOf: techniluxApps)
        } catch {
            print("Failed to load TechniLux apps: \(error)")
        }

        if allApps.isEmpty {
            storeError = "Failed to load app store"
        } else {
            storeApps = allApps
        }

        storeLoaded = true
    }

    private func loadTechniluxApps() async throws -> [AppStoreEntry] {
        guard let url = URL(string: techniluxAppStoreURL) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TechniluxAppStore.self, from: data)

        return response.apps.map { app in
            AppStoreEntry(
                name: app.name,
                description: app.description,
                version: app.version,
                url: app.downloadUrl,
                size: app.size,
                lastModified: nil,
                schemaUrl: app.schemaUrl
            )
        }
    }

    func installApp(_ app: AppStoreEntry) async {
        do {
            try await client.downloadApp(name: app.name, url: app.url, node: cluster.nodeParam)
            await loadApps()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateApp(_ app: DnsApp) async {
        guard let updateUrl = app.updateUrl else { return }
        do {
            try await client.updateApp(name: app.name, url: updateUrl, node: cluster.nodeParam)
            await loadApps()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func uninstallApp(_ app: DnsApp) async {
        do {
            try await client.uninstallApp(name: app.name, node: cluster.nodeParam)
            await loadApps()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func isInstalled(_ app: AppStoreEntry) -> Bool {
        installedApps.contains { $0.name == app.name }
    }

    func hasUpdate(_ app: DnsApp) -> Bool {
        app.updateVersion != nil
    }
}

struct AppsView: View {
    @State private var viewModel = AppsViewModel()
    @Bindable var cluster = ClusterService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $viewModel.selectedTab) {
                    Text("Installed").tag(0)
                    Text("App Store").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if viewModel.selectedTab == 0 {
                    installedList
                } else {
                    storeList
                }
            }
            .navigationTitle("Apps")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ClusterNodePicker()
                }
            }
            .refreshable {
                await viewModel.loadApps()
            }
            .task {
                await viewModel.loadApps()
            }
            .onChange(of: cluster.selectedNode) { _, _ in
                viewModel.storeLoaded = false
                viewModel.storeApps = []
                Task { await viewModel.loadApps() }
            }
        }
    }

    private var installedList: some View {
        Group {
            if viewModel.isLoading && viewModel.installedApps.isEmpty {
                ProgressView("Loading apps...")
                    .frame(maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.installedApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.red)
                    Text("Failed to Load Apps")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.loadApps() }
                    }
                    .buttonStyle(.glassPrimary)
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else if viewModel.installedApps.isEmpty {
                EmptyStateView(
                    icon: "square.stack.3d.up",
                    title: "No Apps Installed",
                    description: "Browse the App Store to install DNS apps"
                )
            } else {
                List(viewModel.installedApps) { app in
                    NavigationLink {
                        AppDetailView(app: app, viewModel: viewModel)
                    } label: {
                        InstalledAppRow(app: app, hasUpdate: viewModel.hasUpdate(app))
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await viewModel.uninstallApp(app) }
                        } label: {
                            Label("Uninstall", systemImage: "trash")
                        }

                        if viewModel.hasUpdate(app) {
                            Button {
                                Task { await viewModel.updateApp(app) }
                            } label: {
                                Label("Update", systemImage: "arrow.down.circle")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var storeList: some View {
        Group {
            if viewModel.isLoadingStore && viewModel.storeApps.isEmpty {
                ProgressView("Loading store...")
                    .frame(maxHeight: .infinity)
            } else if let error = viewModel.storeError, viewModel.storeApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Failed to Load Store")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        viewModel.storeLoaded = false
                        Task { await viewModel.loadStoreApps() }
                    }
                    .buttonStyle(.glassPrimary)
                }
                .frame(maxHeight: .infinity)
            } else if viewModel.storeApps.isEmpty && viewModel.storeLoaded {
                EmptyStateView(
                    icon: "square.stack.3d.up",
                    title: "No Apps Available",
                    description: "App store is empty"
                )
            } else {
                List(viewModel.storeApps) { app in
                    StoreAppRow(
                        app: app,
                        isInstalled: viewModel.isInstalled(app),
                        onInstall: {
                            Task { await viewModel.installApp(app) }
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewModel.loadStoreApps()
        }
    }
}

struct InstalledAppRow: View {
    let app: DnsApp
    let hasUpdate: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(app.name)
                        .font(.headline)

                    if hasUpdate {
                        StatusBadge(text: "Update", color: .blue)
                    }
                }

                Text(app.displayDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text("v\(app.displayVersion)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct StoreAppRow: View {
    let app: AppStoreEntry
    let isInstalled: Bool
    let onInstall: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)

                Text(app.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Text("v\(app.version)")
                    Text("•")
                    Text(app.size)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            if isInstalled {
                StatusBadge(text: "Installed", color: .green)
            } else {
                Button("Install", action: onInstall)
                    .buttonStyle(.glassPrimary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AppDetailView: View {
    let app: DnsApp
    @Bindable var viewModel: AppsViewModel

    @State private var configText: String = ""
    @State private var configDict: [String: Any] = [:]
    @State private var schema: UISchema?
    @State private var isLoadingConfig = false
    @State private var isLoadingSchema = false
    @State private var isSaving = false
    @State private var error: String?
    @State private var showJsonEditor = false

    // Check if we have a schema URL for this app
    private var schemaUrl: String? {
        viewModel.storeApps.first { $0.name == app.name }?.schemaUrl
    }

    var body: some View {
        List {
            Section("Info") {
                InfoRow(label: "Version", value: app.displayVersion)
                if let updateVersion = app.updateVersion {
                    InfoRow(label: "Update Available", value: updateVersion)
                }
            }

            Section("Description") {
                Text(app.displayDescription)
                    .font(.subheadline)
            }

            if let processors = app.dnsApps, !processors.isEmpty {
                Section("Processors") {
                    ForEach(processors, id: \.classPath) { processor in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(processor.classPath.components(separatedBy: ".").last ?? processor.classPath)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(processor.displayDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // Configuration section
            if isLoadingConfig || isLoadingSchema {
                Section("Configuration") {
                    ProgressView("Loading configuration...")
                }
            } else if let schema = schema, !showJsonEditor {
                // Dynamic UI based on schema
                Section {
                    DynamicAppConfigView(
                        schema: schema,
                        config: $configDict,
                        onConfigChange: {
                            // Convert config dict to JSON string
                            if let data = try? JSONSerialization.data(withJSONObject: configDict, options: [.prettyPrinted, .sortedKeys]),
                               let jsonString = String(data: data, encoding: .utf8) {
                                configText = jsonString
                            }
                        }
                    )
                } header: {
                    HStack {
                        Text("Configuration")
                        Spacer()
                        Button {
                            showJsonEditor = true
                        } label: {
                            Label("Edit JSON", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.caption)
                        }
                    }
                }
            } else {
                // Fallback to JSON editor
                Section {
                    TextEditor(text: $configText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 200)
                } header: {
                    HStack {
                        Text("Configuration (JSON)")
                        Spacer()
                        if schema != nil {
                            Button {
                                // Update configDict from text before switching
                                if let data = configText.data(using: .utf8),
                                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    configDict = dict
                                }
                                showJsonEditor = false
                            } label: {
                                Label("Visual Editor", systemImage: "slider.horizontal.3")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            if let error = error {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Save Configuration") {
                    Task { await saveConfig() }
                }
                .disabled(isSaving)

                Button("Uninstall App", role: .destructive) {
                    Task { await viewModel.uninstallApp(app) }
                }
            }
        }
        .navigationTitle(app.name)
        .task {
            await loadConfig()
            await loadSchema()
        }
    }

    private func loadConfig() async {
        isLoadingConfig = true
        defer { isLoadingConfig = false }

        do {
            let response = try await TechnitiumClient.shared.getAppConfig(
                name: app.name,
                node: ClusterService.shared.nodeParam
            )
            configText = response.config

            // Parse JSON to dictionary for dynamic UI
            if let data = response.config.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                configDict = dict
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadSchema() async {
        guard let schemaUrl = schemaUrl, let url = URL(string: schemaUrl) else {
            return
        }

        isLoadingSchema = true
        defer { isLoadingSchema = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            schema = try JSONDecoder().decode(UISchema.self, from: data)
        } catch {
            // Schema failed to load - fall back to JSON editor
            print("Failed to load schema: \(error)")
        }
    }

    private func saveConfig() async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        // If using dynamic UI, convert config dict to JSON
        var configToSave = configText
        if schema != nil && !showJsonEditor {
            if let data = try? JSONSerialization.data(withJSONObject: configDict, options: []),
               let jsonString = String(data: data, encoding: .utf8) {
                configToSave = jsonString
            }
        }

        do {
            try await TechnitiumClient.shared.setAppConfig(
                name: app.name,
                config: configToSave,
                node: ClusterService.shared.nodeParam
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview("Apps View") {
    AppsView()
}
