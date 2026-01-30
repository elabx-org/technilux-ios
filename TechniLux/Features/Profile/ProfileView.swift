import SwiftUI

@MainActor
@Observable
final class ProfileViewModel {
    var displayName = ""
    var username = ""
    var sessionTimeout = 1800
    var groups: [String] = []
    var sessions: [Session] = []

    var isLoading = false
    var isSaving = false
    var error: String?

    // Password change
    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""

    // 2FA
    var is2FAEnabled = false
    var totpCode = ""
    var qrCode: String?
    var secretKey: String?

    private let client = TechnitiumClient.shared

    func loadProfile() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.getProfile()
            displayName = response.displayName ?? ""
            username = response.username
            sessionTimeout = response.sessionTimeoutSeconds ?? 1800
            groups = response.memberOfGroups ?? []
            sessions = response.sessions ?? []
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveProfile() async {
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            try await client.setProfile(
                displayName: displayName.isEmpty ? nil : displayName,
                sessionTimeoutSeconds: sessionTimeout
            )
            await loadProfile()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func changePassword() async -> Bool {
        guard newPassword == confirmPassword else {
            error = "Passwords do not match"
            return false
        }

        guard !currentPassword.isEmpty && !newPassword.isEmpty else {
            error = "Please fill in all password fields"
            return false
        }

        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            try await client.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func init2FA() async {
        do {
            let response = try await client.init2FA()
            qrCode = response.qrCode
            secretKey = response.secretKey
        } catch {
            self.error = error.localizedDescription
        }
    }

    func enable2FA() async -> Bool {
        guard !totpCode.isEmpty else {
            error = "Please enter the TOTP code"
            return false
        }

        do {
            try await client.enable2FA(totp: totpCode)
            is2FAEnabled = true
            totpCode = ""
            qrCode = nil
            secretKey = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func disable2FA() async {
        do {
            try await client.disable2FA()
            is2FAEnabled = false
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var showPasswordSheet = false
    @State private var show2FASheet = false

    var body: some View {
        NavigationStack {
            List {
                // Profile info
                Section("Profile") {
                    HStack {
                        Text("Username")
                        Spacer()
                        Text(viewModel.username)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Display Name")
                        Spacer()
                        TextField("Display Name", text: $viewModel.displayName)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Groups
                if !viewModel.groups.isEmpty {
                    Section("Groups") {
                        ForEach(viewModel.groups, id: \.self) { group in
                            Text(group)
                        }
                    }
                }

                // Security
                Section("Security") {
                    Button {
                        showPasswordSheet = true
                    } label: {
                        Label("Change Password", systemImage: "key")
                    }

                    Button {
                        show2FASheet = true
                    } label: {
                        HStack {
                            Label("Two-Factor Auth", systemImage: "lock.shield")
                            Spacer()
                            StatusBadge(
                                text: viewModel.is2FAEnabled ? "Enabled" : "Disabled",
                                color: viewModel.is2FAEnabled ? .green : .secondary
                            )
                        }
                    }
                }

                // Sessions
                if !viewModel.sessions.isEmpty {
                    Section("Active Sessions") {
                        ForEach(viewModel.sessions) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(session.type)
                                        .font(.subheadline)
                                    if session.isCurrentSession {
                                        StatusBadge(text: "Current", color: .green)
                                    }
                                }
                                Text(session.lastSeenRemoteAddress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Save button
                Section {
                    Button("Save Changes") {
                        Task { await viewModel.saveProfile() }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .navigationTitle("Profile")
            .refreshable {
                await viewModel.loadProfile()
            }
            .task {
                await viewModel.loadProfile()
            }
            .sheet(isPresented: $showPasswordSheet) {
                ChangePasswordSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $show2FASheet) {
                TwoFactorSheet(viewModel: viewModel)
            }
        }
    }
}

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel

    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $viewModel.currentPassword)
                    SecureField("New Password", text: $viewModel.newPassword)
                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                }

                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                if showSuccess {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Password changed successfully")
                        }
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.changePassword() {
                                showSuccess = true
                                try? await Task.sleep(for: .seconds(1))
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }
}

struct TwoFactorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.is2FAEnabled {
                    Section {
                        Text("Two-factor authentication is currently enabled.")
                    }

                    Section {
                        Button("Disable 2FA", role: .destructive) {
                            Task {
                                await viewModel.disable2FA()
                                dismiss()
                            }
                        }
                    }
                } else {
                    if let secretKey = viewModel.secretKey {
                        Section("Setup") {
                            Text("Scan the QR code with your authenticator app, or enter the secret key manually.")
                                .font(.subheadline)

                            Text(secretKey)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }

                        Section("Verify") {
                            TextField("TOTP Code", text: $viewModel.totpCode)
                                .keyboardType(.numberPad)

                            Button("Enable 2FA") {
                                Task {
                                    if await viewModel.enable2FA() {
                                        dismiss()
                                    }
                                }
                            }
                        }
                    } else {
                        Section {
                            Button("Setup Two-Factor Auth") {
                                Task { await viewModel.init2FA() }
                            }
                        }
                    }
                }

                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Two-Factor Auth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Profile View") {
    ProfileView()
}
