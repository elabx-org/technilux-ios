import SwiftUI
import UIKit

@main
struct TechniLuxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
            .onChange(of: appDelegate.shortcutAction) { _, action in
                if let action = action {
                    handleShortcutAction(action)
                    appDelegate.shortcutAction = nil
                }
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

        // Check for pending blocking actions from interactive widgets
        if let blockingAction = WidgetService.shared.checkPendingBlockingAction() {
            switch blockingAction.action {
            case "toggle":
                pendingWidgetAction = .toggleBlocking
            case "enable":
                pendingWidgetAction = .enableBlocking
            case "disable":
                if let minutes = blockingAction.minutes, minutes > 0 {
                    pendingWidgetAction = .temporaryDisable(minutes: minutes)
                } else {
                    pendingWidgetAction = .disableBlocking
                }
            default:
                break
            }
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

    private func handleShortcutAction(_ action: ShortcutAction) {
        switch action {
        case .toggleBlocking:
            selectedTab = .blocking
            pendingWidgetAction = .toggleBlocking
        case .quickDisable:
            selectedTab = .blocking
            pendingWidgetAction = .temporaryDisable(minutes: 5)
        case .dashboard:
            selectedTab = .dashboard
        case .logs:
            selectedTab = .more
            // Will navigate to logs
        }
    }
}

// MARK: - Quick Action Types

enum ShortcutAction: String {
    case toggleBlocking = "com.technilux.toggleBlocking"
    case quickDisable = "com.technilux.quickDisable"
    case dashboard = "com.technilux.dashboard"
    case logs = "com.technilux.logs"
}

// MARK: - App Delegate for Quick Actions

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    @Published var shortcutAction: ShortcutAction?

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Handle shortcut item from cold launch
        if let shortcutItem = options.shortcutItem,
           let action = ShortcutAction(rawValue: shortcutItem.type) {
            shortcutAction = action
        }

        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        // Handle shortcut from warm launch
        if let action = ShortcutAction(rawValue: shortcutItem.type) {
            // Post notification for app to handle
            NotificationCenter.default.post(
                name: .shortcutActionReceived,
                object: nil,
                userInfo: ["action": action]
            )
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }
}

extension Notification.Name {
    static let shortcutActionReceived = Notification.Name("shortcutActionReceived")
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
