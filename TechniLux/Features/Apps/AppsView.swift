import SwiftUI

@MainActor
@Observable
final class AppsViewModel {
    var installedApps: [DnsApp] = []
    var storeApps: [AppStoreEntry] = []
    var isLoading = false
    var error: String?

    var selectedTab = 0

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    func loadApps() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let installed = client.listApps(node: cluster.nodeParam)
            async let store = client.listStoreApps()

            let (installedResponse, storeResponse) = try await (installed, store)
            installedApps = installedResponse.apps
            storeApps = storeResponse.storeApps
        } catch {
            self.error = error.localizedDescription
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
                Task { await viewModel.loadApps() }
            }
        }
    }

    private var installedList: some View {
        Group {
            if viewModel.isLoading && viewModel.installedApps.isEmpty {
                ProgressView("Loading apps...")
                    .frame(maxHeight: .infinity)
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
            if viewModel.storeApps.isEmpty {
                ProgressView("Loading store...")
                    .frame(maxHeight: .infinity)
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

                Text(app.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text("v\(app.version)")
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

    @State private var config: String = ""
    @State private var isLoadingConfig = false
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        List {
            Section("Info") {
                InfoRow(label: "Version", value: app.version)
                if let updateVersion = app.updateVersion {
                    InfoRow(label: "Update Available", value: updateVersion)
                }
            }

            Section("Description") {
                Text(app.description)
                    .font(.subheadline)
            }

            if let processors = app.dnsApps, !processors.isEmpty {
                Section("Processors") {
                    ForEach(processors, id: \.classPath) { processor in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(processor.classPath.components(separatedBy: ".").last ?? processor.classPath)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(processor.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Configuration") {
                if isLoadingConfig {
                    ProgressView()
                } else {
                    TextEditor(text: $config)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 200)
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
            config = response.config
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveConfig() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await TechnitiumClient.shared.setAppConfig(
                name: app.name,
                config: config,
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
