import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct AdminView: View {
    @State private var showBackupSheet = false
    @State private var showRestoreSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("User Management") {
                    NavigationLink {
                        UsersView()
                    } label: {
                        Label("Users", systemImage: "person")
                    }

                    NavigationLink {
                        GroupsView()
                    } label: {
                        Label("Groups", systemImage: "person.3")
                    }

                    NavigationLink {
                        SessionsView()
                    } label: {
                        Label("Sessions", systemImage: "clock")
                    }
                }

                Section("Cluster") {
                    NavigationLink {
                        ClusterView()
                    } label: {
                        Label("Cluster Management", systemImage: "server.rack")
                    }
                }

                Section("Backup & Restore") {
                    Button {
                        showBackupSheet = true
                    } label: {
                        Label("Create Backup", systemImage: "arrow.down.doc")
                    }

                    Button {
                        showRestoreSheet = true
                    } label: {
                        Label("Restore Backup", systemImage: "arrow.up.doc")
                    }
                }
            }
            .navigationTitle("Admin")
            .sheet(isPresented: $showBackupSheet) {
                BackupSheet()
            }
            .sheet(isPresented: $showRestoreSheet) {
                RestoreSheet()
            }
        }
    }
}

// MARK: - Users View

struct UsersView: View {
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading && users.isEmpty {
                ProgressView("Loading users...")
            } else if users.isEmpty {
                EmptyStateView(
                    icon: "person",
                    title: "No Users",
                    description: "No users found"
                )
            } else {
                List(users) { user in
                    UserRow(user: user)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Users")
        .task {
            await loadUsers()
        }
        .refreshable {
            await loadUsers()
        }
    }

    private func loadUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await TechnitiumClient.shared.listUsers()
            users = response.users
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct UserRow: View {
    let user: User

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.username)
                        .font(.headline)

                    if user.disabled {
                        StatusBadge(text: "Disabled", color: .orange)
                    }
                }

                if let displayName = user.displayName {
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let groups = user.memberOfGroups, !groups.isEmpty {
                    Text(groups.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Groups View

struct GroupsView: View {
    @State private var groups: [UserGroup] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading && groups.isEmpty {
                ProgressView("Loading groups...")
            } else if groups.isEmpty {
                EmptyStateView(
                    icon: "person.3",
                    title: "No Groups",
                    description: "No groups found"
                )
            } else {
                List(groups) { group in
                    GroupRow(group: group)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Groups")
        .task {
            await loadGroups()
        }
        .refreshable {
            await loadGroups()
        }
    }

    private func loadGroups() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await TechnitiumClient.shared.listGroups()
            groups = response.groups
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct GroupRow: View {
    let group: UserGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.name)
                .font(.headline)

            Text(group.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let members = group.members, !members.isEmpty {
                Text("\(members.count) member\(members.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sessions View

struct SessionsView: View {
    @State private var sessions: [Session] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading && sessions.isEmpty {
                ProgressView("Loading sessions...")
            } else if sessions.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "No Sessions",
                    description: "No active sessions found"
                )
            } else {
                List(sessions) { session in
                    SessionRow(session: session, onDelete: {
                        Task { await deleteSession(session) }
                    })
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Sessions")
        .task {
            await loadSessions()
        }
        .refreshable {
            await loadSessions()
        }
    }

    private func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await TechnitiumClient.shared.listSessions()
            sessions = response.sessions
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteSession(_ session: Session) async {
        do {
            try await TechnitiumClient.shared.deleteSession(partialToken: session.partialToken)
            await loadSessions()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SessionRow: View {
    let session: Session
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.username)
                    .font(.headline)

                if session.isCurrentSession {
                    StatusBadge(text: "Current", color: .green)
                }

                Spacer()

                StatusBadge(text: session.type, color: .techniluxPrimary)
            }

            if let tokenName = session.tokenName {
                Text(tokenName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(session.lastSeen)
                Text("•")
                Text(session.lastSeenRemoteAddress)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .swipeActions {
            if !session.isCurrentSession {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Cluster View

struct ClusterView: View {
    @Bindable var cluster = ClusterService.shared
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading cluster state...")
            } else if cluster.initialized {
                clusterDetailView
            } else {
                EmptyStateView(
                    icon: "server.rack",
                    title: "Cluster Not Configured",
                    description: "This server is not part of a cluster"
                )
            }
        }
        .navigationTitle("Cluster")
        .task {
            isLoading = true
            await cluster.load()
            isLoading = false
        }
        .refreshable {
            await cluster.load()
        }
    }

    private var clusterDetailView: some View {
        List {
            Section("Cluster Info") {
                if let domain = cluster.clusterDomain {
                    InfoRow(label: "Domain", value: domain)
                }
                InfoRow(label: "Nodes", value: "\(cluster.nodes.count)")
            }

            Section("Nodes") {
                ForEach(cluster.nodes) { node in
                    NodeStatusRow(
                        node: node,
                        isSelected: node.name == cluster.selectedNode || (cluster.selectedNode == nil && node.state == "Self")
                    )
                }
            }
        }
    }
}

// MARK: - Backup Sheet

struct BackupSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var includeBlockLists = true
    @State private var includeLogs = true
    @State private var includeScopes = true
    @State private var includeApps = true
    @State private var includeStats = true
    @State private var includeZones = true
    @State private var includeAllowedZones = true
    @State private var includeBlockedZones = true
    @State private var includeDnsSettings = true
    @State private var includeAuthConfig = true
    @State private var includeLogSettings = true

    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Include in Backup") {
                    Toggle("Zones", isOn: $includeZones)
                    Toggle("DNS Settings", isOn: $includeDnsSettings)
                    Toggle("Block Lists", isOn: $includeBlockLists)
                    Toggle("Allowed Zones", isOn: $includeAllowedZones)
                    Toggle("Blocked Zones", isOn: $includeBlockedZones)
                    Toggle("DHCP Scopes", isOn: $includeScopes)
                    Toggle("Apps", isOn: $includeApps)
                    Toggle("Logs", isOn: $includeLogs)
                    Toggle("Stats", isOn: $includeStats)
                    Toggle("Auth Config", isOn: $includeAuthConfig)
                    Toggle("Log Settings", isOn: $includeLogSettings)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") {
                        Task { await downloadBackup() }
                    }
                    .disabled(isLoading)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView("Creating backup...")
                }
            }
        }
    }

    private func downloadBackup() async {
        isLoading = true
        error = nil

        do {
            let data = try await TechnitiumClient.shared.downloadBackup(
                blockLists: includeBlockLists,
                logs: includeLogs,
                scopes: includeScopes,
                apps: includeApps,
                stats: includeStats,
                zones: includeZones,
                allowedZones: includeAllowedZones,
                blockedZones: includeBlockedZones,
                dnsSettings: includeDnsSettings,
                authConfig: includeAuthConfig,
                logSettings: includeLogSettings,
                node: ClusterService.shared.nodeParam
            )

            // Save to temp file and share
            let fileName = "technitium-backup-\(formattedDate()).zip"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)

            // Present share sheet
            await MainActor.run {
                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            }

            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Restore Sheet

struct RestoreSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFileURL: URL?
    @State private var deleteExistingFiles = false
    @State private var showFilePicker = false
    @State private var isLoading = false
    @State private var error: String?
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showFilePicker = true
                    } label: {
                        HStack {
                            Label("Select Backup File", systemImage: "doc.zipper")
                            Spacer()
                            if let url = selectedFileURL {
                                Text(url.lastPathComponent)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Delete existing files", isOn: $deleteExistingFiles)
                } footer: {
                    Text("When enabled, existing configuration files will be deleted before restoring. This ensures a clean restore but removes any changes made since the backup.")
                }

                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Restoring a backup will overwrite current server configuration. The server may restart after restore.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Restore Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore") {
                        showConfirmation = true
                    }
                    .disabled(isLoading || selectedFileURL == nil)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView("Restoring backup...")
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.zip, .archive],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    selectedFileURL = urls.first
                case .failure(let error):
                    self.error = error.localizedDescription
                }
            }
            .alert("Confirm Restore", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Restore", role: .destructive) {
                    Task { await restoreBackup() }
                }
            } message: {
                Text("Are you sure you want to restore from this backup? This will overwrite the current server configuration.")
            }
        }
    }

    private func restoreBackup() async {
        guard let url = selectedFileURL else { return }

        isLoading = true
        error = nil

        do {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "RestoreError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access the selected file"])
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)

            try await TechnitiumClient.shared.restoreBackup(
                data: data,
                deleteExistingFiles: deleteExistingFiles,
                node: ClusterService.shared.nodeParam
            )

            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview("Admin View") {
    AdminView()
}
