import SwiftUI

@main
struct TechniLuxApp: App {
    @State private var auth = AuthService.shared
    @State private var isInitializing = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isInitializing {
                    // Splash screen while checking session
                    SplashView()
                } else if auth.isAuthenticated {
                    // Main app
                    AdaptiveNavigationView()
                } else {
                    // Login
                    LoginView()
                }
            }
            .task {
                await initializeApp()
            }
        }
    }

    private func initializeApp() async {
        // Restore session from keychain
        await auth.restoreSession()

        // If authenticated, load cluster state
        if auth.isAuthenticated {
            await ClusterService.shared.load()
        }

        // Done initializing
        isInitializing = false
    }
}

/// Splash screen shown during app initialization
struct SplashView: View {
    @State private var opacity = 0.0

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "server.rack")
                .font(.system(size: 80))
                .foregroundStyle(.techniluxPrimary)

            Text("TechniLux")
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView()
                .scaleEffect(1.2)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1.0
            }
        }
    }
}

#Preview("App") {
    TechniLuxApp()
}
