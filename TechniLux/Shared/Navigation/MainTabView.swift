import SwiftUI

/// Main tab view for iPhone navigation
struct MainTabView: View {
    @State private var selectedTab = Tab.dashboard

    enum Tab: String, CaseIterable {
        case dashboard
        case zones
        case blocking
        case more

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .zones: return "Zones"
            case .blocking: return "Blocking"
            case .more: return "More"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .zones: return "globe"
            case .blocking: return "hand.raised.fill"
            case .more: return "ellipsis.circle.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(Tab.dashboard.title, systemImage: Tab.dashboard.icon)
                }
                .tag(Tab.dashboard)

            ZonesView()
                .tabItem {
                    Label(Tab.zones.title, systemImage: Tab.zones.icon)
                }
                .tag(Tab.zones)

            BlockingView()
                .tabItem {
                    Label(Tab.blocking.title, systemImage: Tab.blocking.icon)
                }
                .tag(Tab.blocking)

            MoreView()
                .tabItem {
                    Label(Tab.more.title, systemImage: Tab.more.icon)
                }
                .tag(Tab.more)
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
    MainTabView()
}
