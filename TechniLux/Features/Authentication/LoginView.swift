import SwiftUI

struct LoginView: View {
    @Bindable var auth = AuthService.shared

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var rememberCredentials = true
    @State private var showPassword = false

    @AppStorage("lastServerURL") private var lastServerURL = ""
    @AppStorage("lastUsername") private var lastUsername = ""

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)

                    // Logo and Title
                    VStack(spacing: 16) {
                        Image("TechniLuxLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                        Text("TechniLux")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("DNS Server Management")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Biometric Login Button (if available)
                    if auth.biometricEnabled && auth.hasSavedCredentials {
                        biometricLoginSection
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

                        // Remember credentials toggle
                        if auth.canUseBiometrics {
                            Toggle(isOn: $rememberCredentials) {
                                HStack {
                                    Image(systemName: auth.biometricType.iconName)
                                    Text("Enable \(auth.biometricType.name)")
                                }
                                .font(.subheadline)
                            }
                            .tint(.techniluxPrimary)
                            .padding(.horizontal, 4)
                        }

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
                        .buttonStyle(.glassPrimary)
                        .disabled(auth.isLoading || !isFormValid)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)

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
            if !lastUsername.isEmpty {
                username = lastUsername
            }
        }
        .task {
            // Auto-login with biometrics if available
            if auth.biometricEnabled && auth.hasSavedCredentials {
                try? await auth.loginWithBiometrics()
            }
        }
    }

    private var biometricLoginSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    try? await auth.loginWithBiometrics()
                }
            } label: {
                HStack {
                    Image(systemName: auth.biometricType.iconName)
                        .font(.title2)
                    Text("Sign in with \(auth.biometricType.name)")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.outlined)
            .padding(.horizontal)

            Text("or sign in with credentials")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                password: password,
                saveCredentials: rememberCredentials && auth.canUseBiometrics
            )

            // Save server URL and username for next time
            lastServerURL = cleanURL
            lastUsername = username

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
