import SwiftUI

struct AdminView: View {
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
            }
            .navigationTitle("Admin")
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
    @State private var groups: [Group] = []
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
    let group: Group

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

#Preview("Admin View") {
    AdminView()
}
