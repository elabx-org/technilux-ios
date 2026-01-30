import SwiftUI

struct LoginView: View {
    @Bindable var auth = AuthService.shared

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var rememberServer = true
    @State private var showPassword = false

    @AppStorage("lastServerURL") private var lastServerURL = ""

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 64))
                            .foregroundStyle(.techniluxPrimary)

                        Text("TechniLux")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("DNS Server Management")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Login Form
                    VStack(spacing: 20) {
                        // Server URL
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server URL")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(.secondary)

                                TextField("http://10.0.0.1:5380", text: $serverURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                            }
                            .padding()
                            .glassBackground()
                        }

                        // Username
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                Image(systemName: "person")
                                    .foregroundStyle(.secondary)

                                TextField("admin", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            .padding()
                            .glassBackground()
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                Image(systemName: "lock")
                                    .foregroundStyle(.secondary)

                                if showPassword {
                                    TextField("Password", text: $password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Password", text: $password)
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .glassBackground()
                        }

                        // Remember server toggle
                        Toggle(isOn: $rememberServer) {
                            Text("Remember server URL")
                                .font(.subheadline)
                        }
                        .tint(.techniluxPrimary)
                        .padding(.horizontal, 4)

                        // Error message
                        if let error = auth.error {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Login Button
                        Button {
                            Task {
                                await login()
                            }
                        } label: {
                            HStack {
                                if auth.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.glass)
                        .disabled(auth.isLoading || !isFormValid)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 60)

                    // Footer
                    VStack(spacing: 8) {
                        Text("TechniLux iOS")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text("For Technitium DNS Server")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                }
                .frame(minHeight: geometry.size.height)
                .padding()
            }
        }
        .onAppear {
            if !lastServerURL.isEmpty {
                serverURL = lastServerURL
            }
        }
    }

    private var isFormValid: Bool {
        !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
    }

    private func login() async {
        // Clean up server URL
        var cleanURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "http://" + cleanURL
        }
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }

        do {
            try await auth.login(
                serverURL: cleanURL,
                username: username.trimmingCharacters(in: .whitespaces),
                password: password
            )

            // Save server URL if requested
            if rememberServer {
                lastServerURL = cleanURL
            }

            // Load cluster state after login
            await ClusterService.shared.load()

        } catch {
            auth.error = error.localizedDescription
        }
    }
}

// MARK: - Previews

#Preview("Login View") {
    LoginView()
}
