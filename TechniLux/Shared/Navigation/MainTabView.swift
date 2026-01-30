import SwiftUI

/// Main tab view for iPhone navigation
struct MainTabView: View {
    @Binding var selectedTab: AppTab
    @Binding var pendingAction: WidgetAction?

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(AppTab.dashboard)

            ZonesView()
                .tabItem {
                    Label("Zones", systemImage: "globe")
                }
                .tag(AppTab.zones)

            BlockingView(pendingAction: $pendingAction)
                .tabItem {
                    Label("Blocking", systemImage: "hand.raised.fill")
                }
                .tag(AppTab.blocking)

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(AppTab.more)
        }
        .tint(.techniluxPrimary)
    }
}

/// "More" menu with additional navigation options
struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                // DNS Management
                Section("DNS Management") {
                    NavigationLink {
                        CacheView()
                    } label: {
                        Label("Cache", systemImage: "memorychip")
                    }

                    NavigationLink {
                        LogsView()
                    } label: {
                        Label("Logs", systemImage: "doc.text")
                    }

                    NavigationLink {
                        DNSClientView()
                    } label: {
                        Label("DNS Client", systemImage: "magnifyingglass")
                    }
                }

                // Services
                Section("Services") {
                    NavigationLink {
                        DHCPView()
                    } label: {
                        Label("DHCP", systemImage: "network")
                    }

                    NavigationLink {
                        AppsView()
                    } label: {
                        Label("Apps", systemImage: "square.stack.3d.up")
                    }

                    NavigationLink {
                        NetworkView()
                    } label: {
                        Label("Network", systemImage: "wifi")
                    }
                }

                // Administration
                Section("Administration") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }

                    NavigationLink {
                        AdminView()
                    } label: {
                        Label("Admin", systemImage: "person.2")
                    }
                }

                // Account
                Section("Account") {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Profile", systemImage: "person.circle")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        AuthService.shared.logout()
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

// MARK: - Previews

#Preview("Main Tab View") {
    MainTabView(selectedTab: .constant(.dashboard), pendingAction: .constant(nil))
}
