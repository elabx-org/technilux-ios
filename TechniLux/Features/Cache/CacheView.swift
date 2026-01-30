import SwiftUI

@MainActor
@Observable
final class CacheViewModel {
    var zones: [CacheEntry] = []
    var currentPath: String = ""
    var isLoading = false
    var error: String?

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    func loadCache() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.listCachedZones(domain: currentPath, node: cluster.nodeParam)
            zones = response.zonesList
        } catch {
            self.error = error.localizedDescription
        }
    }

    func navigateTo(_ zone: String) async {
        currentPath = zone
        await loadCache()
    }

    func navigateUp() async {
        if currentPath.isEmpty { return }
        let components = currentPath.split(separator: ".")
        if components.count > 1 {
            currentPath = components.dropFirst().joined(separator: ".")
        } else {
            currentPath = ""
        }
        await loadCache()
    }

    func deleteZone(_ zone: String) async {
        do {
            try await client.deleteCachedZone(domain: zone, node: cluster.nodeParam)
            await loadCache()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func flushCache() async {
        do {
            try await client.flushCache(node: cluster.nodeParam)
            await loadCache()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func prefetch(domain: String, type: String = "A") async {
        do {
            try await client.prefetchCache(domain: domain, type: type, node: cluster.nodeParam)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CacheView: View {
    @State private var viewModel = CacheViewModel()
    @State private var showPrefetchSheet = false
    @State private var showFlushConfirm = false
    @Bindable var cluster = ClusterService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Path breadcrumb
                if !viewModel.currentPath.isEmpty {
                    pathBreadcrumb
                }

                // Error display
                if let error = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.subheadline)
                        Spacer()
                        Button("Retry") {
                            Task { await viewModel.loadCache() }
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }

                // Cache list
                if viewModel.isLoading && viewModel.zones.isEmpty {
                    ProgressView("Loading cache...")
                        .frame(maxHeight: .infinity)
                } else if viewModel.zones.isEmpty && viewModel.error == nil {
                    EmptyStateView(
                        icon: "memorychip",
                        title: "Cache Empty",
                        description: "No cached entries found"
                    )
                    .frame(maxHeight: .infinity)
                } else if !viewModel.zones.isEmpty {
                    List(viewModel.zones) { zone in
                        Button {
                            Task { await viewModel.navigateTo(zone.zone) }
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.techniluxPrimary)

                                VStack(alignment: .leading) {
                                    Text(zone.zone)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    if let records = zone.records, !records.isEmpty {
                                        Text("\(records.count) records")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteZone(zone.zone) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Cache")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        ClusterNodePicker()

                        Menu {
                            Button {
                                showPrefetchSheet = true
                            } label: {
                                Label("Prefetch", systemImage: "arrow.down.circle")
                            }

                            Button(role: .destructive) {
                                showFlushConfirm = true
                            } label: {
                                Label("Flush Cache", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadCache()
            }
            .task {
                await viewModel.loadCache()
            }
            .onChange(of: cluster.selectedNode) { _, _ in
                Task { await viewModel.loadCache() }
            }
            .sheet(isPresented: $showPrefetchSheet) {
                PrefetchSheet(viewModel: viewModel)
            }
            .confirmationDialog(
                "Flush Cache",
                isPresented: $showFlushConfirm,
                titleVisibility: .visible
            ) {
                Button("Flush All", role: .destructive) {
                    Task { await viewModel.flushCache() }
                }
            } message: {
                Text("This will delete all cached DNS entries. This action cannot be undone.")
            }
        }
    }

    private var pathBreadcrumb: some View {
        HStack {
            Button {
                Task { await viewModel.navigateUp() }
            } label: {
                Image(systemName: "chevron.left")
            }

            Text(viewModel.currentPath)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Button("Root") {
                viewModel.currentPath = ""
                Task { await viewModel.loadCache() }
            }
            .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct PrefetchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: CacheViewModel

    @State private var domain = ""
    @State private var recordType = "A"

    let recordTypes = ["A", "AAAA", "CNAME", "MX", "TXT", "NS", "SOA"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Domain", text: $domain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Record Type", selection: $recordType) {
                        ForEach(recordTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                } footer: {
                    Text("Prefetch will resolve the domain and cache the result")
                }
            }
            .navigationTitle("Prefetch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Prefetch") {
                        Task {
                            await viewModel.prefetch(domain: domain, type: recordType)
                            dismiss()
                        }
                    }
                    .disabled(domain.isEmpty)
                }
            }
        }
    }
}

#Preview("Cache View") {
    CacheView()
}
