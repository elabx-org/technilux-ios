import SwiftUI

struct ZonePermissionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let zoneName: String
    let onSaved: () -> Void

    @State private var userPermissions: [ZonePermission] = []
    @State private var groupPermissions: [ZonePermission] = []
    @State private var newUserName = ""
    @State private var newGroupName = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading permissions...")
                } else {
                    permissionsForm
                }
            }
            .navigationTitle("Zone Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await savePermissions() }
                    }
                    .disabled(isLoading || isSaving)
                }
            }
            .task {
                await loadPermissions()
            }
        }
    }

    private var permissionsForm: some View {
        Form {
            // User Permissions Section
            Section {
                HStack {
                    TextField("Username", text: $newUserName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        addUserPermission()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newUserName.isEmpty)
                }

                if userPermissions.isEmpty {
                    Text("No user permissions configured")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach($userPermissions) { $permission in
                        PermissionRow(permission: $permission, onDelete: {
                            userPermissions.removeAll { $0.name == permission.name }
                        })
                    }
                }
            } header: {
                Text("User Permissions")
            }

            // Group Permissions Section
            Section {
                HStack {
                    TextField("Group name", text: $newGroupName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        addGroupPermission()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newGroupName.isEmpty)
                }

                if groupPermissions.isEmpty {
                    Text("No group permissions configured")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach($groupPermissions) { $permission in
                        PermissionRow(permission: $permission, onDelete: {
                            groupPermissions.removeAll { $0.name == permission.name }
                        })
                    }
                }
            } header: {
                Text("Group Permissions")
            }

            // Legend
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    legendItem(icon: "eye", label: "View", description: "Can view zone records")
                    legendItem(icon: "pencil", label: "Modify", description: "Can add and edit records")
                    legendItem(icon: "trash", label: "Delete", description: "Can delete records and zone")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("Permission Legend")
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private func legendItem(icon: String, label: String, description: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
            Text("\(label):")
                .fontWeight(.medium)
            Text(description)
        }
    }

    private func addUserPermission() {
        guard !newUserName.isEmpty else { return }
        guard !userPermissions.contains(where: { $0.name == newUserName }) else {
            error = "User already has permissions configured"
            return
        }

        userPermissions.append(ZonePermission(
            name: newUserName,
            canView: true,
            canModify: false,
            canDelete: false
        ))
        newUserName = ""
        error = nil
    }

    private func addGroupPermission() {
        guard !newGroupName.isEmpty else { return }
        guard !groupPermissions.contains(where: { $0.name == newGroupName }) else {
            error = "Group already has permissions configured"
            return
        }

        groupPermissions.append(ZonePermission(
            name: newGroupName,
            canView: true,
            canModify: false,
            canDelete: false
        ))
        newGroupName = ""
        error = nil
    }

    private func loadPermissions() async {
        isLoading = true
        error = nil

        do {
            let response = try await TechnitiumClient.shared.getZonePermissions(
                zone: zoneName,
                node: ClusterService.shared.nodeParam
            )

            userPermissions = ZonePermission.parse(response.userPermissions)
            groupPermissions = ZonePermission.parse(response.groupPermissions)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func savePermissions() async {
        isSaving = true
        error = nil

        do {
            try await TechnitiumClient.shared.setZonePermissions(
                zone: zoneName,
                userPermissions: ZonePermission.format(userPermissions),
                groupPermissions: ZonePermission.format(groupPermissions),
                node: ClusterService.shared.nodeParam
            )
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    @Binding var permission: ZonePermission
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(permission.name)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 16) {
                PermissionToggle(
                    icon: "eye",
                    label: "View",
                    isOn: $permission.canView
                )

                PermissionToggle(
                    icon: "pencil",
                    label: "Modify",
                    isOn: $permission.canModify
                )

                PermissionToggle(
                    icon: "trash",
                    label: "Delete",
                    isOn: $permission.canDelete
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Permission Toggle

struct PermissionToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isOn ? Color.accentColor : Color.secondary.opacity(0.2))
            .foregroundStyle(isOn ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
