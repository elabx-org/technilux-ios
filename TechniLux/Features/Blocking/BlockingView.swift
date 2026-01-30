import SwiftUI

@MainActor
@Observable
final class BlockingViewModel {
    var allowedDomains: [String] = []
    var blockedDomains: [String] = []
    var isLoading = false
    var error: String?

    var selectedTab = 0

    // Temporary disable
    var blockingEnabled = true
    var disableMinutes: Int?
    var disableEndTime: Date?

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    func loadDomains() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Use export endpoints like the web UI - they return plain text lists
            async let allowed = client.exportAllowedDomains(node: cluster.nodeParam)
            async let blocked = client.exportBlockedDomains(node: cluster.nodeParam)

            let (allowedList, blockedList) = try await (allowed, blocked)
            allowedDomains = allowedList
            blockedDomains = blockedList
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addAllowed(_ domain: String) async {
        do {
            try await client.addAllowedDomain(domain: domain, node: cluster.nodeParam)
            await loadDomains()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteAllowed(_ domain: String) async {
        do {
            try await client.deleteAllowedDomain(domain: domain, node: cluster.nodeParam)
            await loadDomains()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addBlocked(_ domain: String) async {
        do {
            try await client.addBlockedDomain(domain: domain, node: cluster.nodeParam)
            await loadDomains()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteBlocked(_ domain: String) async {
        do {
            try await client.deleteBlockedDomain(domain: domain, node: cluster.nodeParam)
            await loadDomains()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func temporaryDisable(minutes: Int) async {
        do {
            try await client.temporaryDisableBlocking(minutes: minutes)
            disableMinutes = minutes
            disableEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
            blockingEnabled = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reEnableBlocking() async {
        do {
            try await client.temporaryDisableBlocking(minutes: 0)
            disableMinutes = nil
            disableEndTime = nil
            blockingEnabled = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct BlockingView: View {
    @State private var viewModel = BlockingViewModel()
    @State private var showAddSheet = false
    @State private var showDisableSheet = false
    @State private var checkDomain = ""
    @State private var checkResult: BlockedCheckResponse?
    @Bindable var cluster = ClusterService.shared
    @Binding var pendingAction: WidgetAction?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick actions
                quickActionsSection

                // Domain check
                domainCheckSection

                // Tabs
                Picker("List", selection: $viewModel.selectedTab) {
                    Text("Allowed").tag(0)
                    Text("Blocked").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Error display
                if let error = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.subheadline)
                        Spacer()
                        Button("Retry") {
                            Task { await viewModel.loadDomains() }
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }

                // Loading indicator
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                // Domain lists
                if viewModel.selectedTab == 0 {
                    domainList(
                        domains: viewModel.allowedDomains,
                        emptyTitle: "No Allowed Domains",
                        emptyDescription: "Domains added here will bypass blocking",
                        onDelete: { domain in
                            Task { await viewModel.deleteAllowed(domain) }
                        }
                    )
                } else {
                    domainList(
                        domains: viewModel.blockedDomains,
                        emptyTitle: "No Blocked Domains",
                        emptyDescription: "Domains added here will be blocked",
                        onDelete: { domain in
                            Task { await viewModel.deleteBlocked(domain) }
                        }
                    )
                }
            }
            .navigationTitle("Blocking")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        ClusterNodePicker()

                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadDomains()
            }
            .task {
                await viewModel.loadDomains()
            }
            .onChange(of: cluster.selectedNode) { _, _ in
                Task {
                    await viewModel.loadDomains()
                }
            }
            .onChange(of: pendingAction) { _, action in
                if let action = action {
                    handleWidgetAction(action)
                    pendingAction = nil
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddDomainSheet(
                    isAllowed: viewModel.selectedTab == 0,
                    onAdd: { domain in
                        Task {
                            if viewModel.selectedTab == 0 {
                                await viewModel.addAllowed(domain)
                            } else {
                                await viewModel.addBlocked(domain)
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showDisableSheet) {
                DisableBlockingSheet(viewModel: viewModel, startLiveActivity: startLiveActivity)
            }
        }
    }

    private func handleWidgetAction(_ action: WidgetAction) {
        Task {
            switch action {
            case .toggleBlocking:
                if viewModel.blockingEnabled {
                    showDisableSheet = true
                } else {
                    await viewModel.reEnableBlocking()
                    endLiveActivity()
                }

            case .enableBlocking:
                await viewModel.reEnableBlocking()
                endLiveActivity()

            case .disableBlocking:
                showDisableSheet = true

            case .temporaryDisable(let minutes):
                await viewModel.temporaryDisable(minutes: minutes)
                startLiveActivity(minutes: minutes)

            case .showBlocking, .showDashboard, .showLogs:
                break
            }
        }
    }

    private func startLiveActivity(minutes: Int) {
        guard let endTime = viewModel.disableEndTime else { return }

        if #available(iOS 16.2, *) {
            let serverName = cluster.selectedNode ?? "Technitium"
            WidgetService.shared.startBlockingActivity(
                serverName: serverName,
                disableEndTime: endTime
            )
        }
    }

    private func endLiveActivity() {
        if #available(iOS 16.2, *) {
            WidgetService.shared.endBlockingActivities()
        }
    }

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            // Blocking status
            GlassCard {
                HStack {
                    Image(systemName: viewModel.blockingEnabled ? "checkmark.shield.fill" : "shield.slash.fill")
                        .foregroundStyle(viewModel.blockingEnabled ? .green : .orange)

                    VStack(alignment: .leading) {
                        Text(viewModel.blockingEnabled ? "Blocking Active" : "Blocking Disabled")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if let endTime = viewModel.disableEndTime {
                            Text("Until \(endTime, style: .time)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        if viewModel.blockingEnabled {
                            showDisableSheet = true
                        } else {
                            Task { await viewModel.reEnableBlocking() }
                        }
                    } label: {
                        Text(viewModel.blockingEnabled ? "Disable" : "Enable")
                            .font(.subheadline)
                    }
                    .buttonStyle(.glassPrimary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var domainCheckSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Check Domain")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    TextField("example.com", text: $checkDomain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        Task {
                            checkResult = try? await TechnitiumClient.shared.isBlocked(
                                domain: checkDomain,
                                node: ClusterService.shared.nodeParam
                            )
                        }
                    } label: {
                        Text("Check")
                    }
                    .buttonStyle(.glassPrimary)
                    .disabled(checkDomain.isEmpty)
                }

                if let result = checkResult {
                    HStack {
                        Image(systemName: result.isBlocked ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(result.isBlocked ? .red : .green)

                        Text(result.isBlocked ? "Blocked" : "Allowed")
                            .fontWeight(.medium)

                        if let blockedBy = result.blockedBy {
                            Text("by \(blockedBy)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func domainList(
        domains: [String],
        emptyTitle: String,
        emptyDescription: String,
        onDelete: @escaping (String) -> Void
    ) -> some View {
        if domains.isEmpty {
            EmptyStateView(
                icon: "list.bullet",
                title: emptyTitle,
                description: emptyDescription
            )
        } else {
            List {
                ForEach(domains, id: \.self) { domain in
                    Text(domain)
                        .font(.subheadline)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        onDelete(domains[index])
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

struct AddDomainSheet: View {
    @Environment(\.dismiss) private var dismiss

    let isAllowed: Bool
    let onAdd: (String) -> Void

    @State private var domain = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Domain", text: $domain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text(isAllowed
                        ? "This domain will bypass blocking"
                        : "This domain will be blocked"
                    )
                }
            }
            .navigationTitle(isAllowed ? "Add to Allowed" : "Add to Blocked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(domain)
                        dismiss()
                    }
                    .disabled(domain.isEmpty)
                }
            }
        }
    }
}

struct DisableBlockingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BlockingViewModel
    var startLiveActivity: (Int) -> Void

    let durations = [5, 15, 30, 60, 120]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(durations, id: \.self) { minutes in
                        Button {
                            Task {
                                await viewModel.temporaryDisable(minutes: minutes)
                                startLiveActivity(minutes)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text(formatDuration(minutes))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } header: {
                    Text("Temporarily disable blocking for:")
                }
            }
            .navigationTitle("Disable Blocking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60) hour\(minutes >= 120 ? "s" : "")"
        }
        return "\(minutes) minutes"
    }
}

#Preview("Blocking View") {
    BlockingView(pendingAction: .constant(nil))
}
