import SwiftUI

@main
struct TechniLuxApp: App {
    @State private var auth = AuthService.shared
    @State private var isInitializing = true
    @State private var pendingWidgetAction: WidgetAction?
    @State private var selectedTab: AppTab = .dashboard

    var body: some Scene {
        WindowGroup {
            Group {
                if isInitializing {
                    // Splash screen while checking session
                    SplashView()
                } else if auth.isAuthenticated {
                    // Main app
                    AdaptiveNavigationView(selectedTab: $selectedTab, pendingAction: $pendingWidgetAction)
                } else {
                    // Login
                    LoginView()
                }
            }
            .task {
                await initializeApp()
            }
            .onOpenURL { url in
                handleWidgetURL(url)
            }
            .onAppear {
                checkPendingWidgetRequests()
            }
        }
    }

    private func initializeApp() async {
        // Restore session from keychain
        await auth.restoreSession()

        // If authenticated, load cluster state and update widgets
        if auth.isAuthenticated {
            await ClusterService.shared.load()
            await updateWidgetData()
        }

        // Done initializing
        isInitializing = false
    }

    private func handleWidgetURL(_ url: URL) {
        guard let action = WidgetService.shared.handleWidgetURL(url) else { return }

        // Handle the action
        switch action {
        case .showDashboard:
            selectedTab = .dashboard
        case .showBlocking, .toggleBlocking, .enableBlocking, .disableBlocking:
            selectedTab = .blocking
            pendingWidgetAction = action
        case .temporaryDisable(let minutes):
            selectedTab = .blocking
            pendingWidgetAction = .temporaryDisable(minutes: minutes)
        case .showLogs:
            selectedTab = .more
            // Navigate to logs
        }
    }

    private func checkPendingWidgetRequests() {
        // Check for pending disable requests from widgets
        if let request = WidgetService.shared.checkPendingRequests() {
            pendingWidgetAction = .temporaryDisable(minutes: request.minutes)
            selectedTab = .blocking
        }
    }

    private func updateWidgetData() async {
        do {
            let stats = try await TechnitiumClient.shared.getStats()
            let settings = try? await TechnitiumClient.shared.getSettings()
            WidgetService.shared.updateFromStats(stats, settings: settings)
        } catch {
            print("Failed to update widget data: \(error)")
        }
    }
}

/// App tabs for navigation
enum AppTab: Hashable {
    case dashboard
    case zones
    case blocking
    case more
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

#Preview("Splash") {
    SplashView()
}
