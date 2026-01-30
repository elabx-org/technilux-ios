import SwiftUI

/// Sidebar navigation for iPad
struct SidebarView: View {
    @State private var selectedSection: SidebarSection? = .dashboard
    @Bindable var cluster = ClusterService.shared

    enum SidebarSection: String, CaseIterable, Identifiable {
        case dashboard
        case zones
        case blocking
        case cache
        case dhcp
        case apps
        case logs
        case settings
        case admin
        case network
        case dnsClient
        case profile
        case about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .zones: return "Zones"
            case .blocking: return "Blocking"
            case .cache: return "Cache"
            case .dhcp: return "DHCP"
            case .apps: return "Apps"
            case .logs: return "Logs"
            case .settings: return "Settings"
            case .admin: return "Admin"
            case .network: return "Network"
            case .dnsClient: return "DNS Client"
            case .profile: return "Profile"
            case .about: return "About"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .zones: return "globe"
            case .blocking: return "hand.raised.fill"
            case .cache: return "memorychip"
            case .dhcp: return "network"
            case .apps: return "square.stack.3d.up"
            case .logs: return "doc.text"
            case .settings: return "gearshape"
            case .admin: return "person.2"
            case .network: return "wifi"
            case .dnsClient: return "magnifyingglass"
            case .profile: return "person.circle"
            case .about: return "info.circle"
            }
        }

        @ViewBuilder
        var destination: some View {
            switch self {
            case .dashboard: DashboardView()
            case .zones: ZonesView()
            case .blocking: BlockingView()
            case .cache: CacheView()
            case .dhcp: DHCPView()
            case .apps: AppsView()
            case .logs: LogsView()
            case .settings: SettingsView()
            case .admin: AdminView()
            case .network: NetworkView()
            case .dnsClient: DNSClientView()
            case .profile: ProfileView()
            case .about: AboutView()
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                // Header with cluster picker
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "server.rack")
                                .font(.title2)
                                .foregroundStyle(.techniluxPrimary)
                            Text("TechniLux")
                                .font(.headline)
                        }

                        if cluster.hasMultipleNodes {
                            ClusterNodePicker()
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Main Navigation
                Section("DNS Management") {
                    ForEach([SidebarSection.dashboard, .zones, .blocking, .cache]) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                }

                Section("Services") {
                    ForEach([SidebarSection.dhcp, .apps, .network]) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                }

                Section("Tools") {
                    ForEach([SidebarSection.logs, .dnsClient]) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                }

                Section("Administration") {
                    ForEach([SidebarSection.settings, .admin, .profile]) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                }

                Section {
                    Label(SidebarSection.about.title, systemImage: SidebarSection.about.icon)
                        .tag(SidebarSection.about)

                    Button(role: .destructive) {
                        AuthService.shared.logout()
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("TechniLux")
            .listStyle(.sidebar)
        } detail: {
            if let section = selectedSection {
                NavigationStack {
                    section.destination
                }
            } else {
                ContentUnavailableView(
                    "Select a Section",
                    systemImage: "sidebar.left",
                    description: Text("Choose a section from the sidebar to view")
                )
            }
        }
        .tint(.techniluxPrimary)
    }
}

// MARK: - Adaptive Navigation

/// Root view that switches between tab and sidebar based on device
struct AdaptiveNavigationView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            SidebarView()
        } else {
            MainTabView()
        }
    }
}

// MARK: - Previews

#Preview("Sidebar View") {
    SidebarView()
}

#Preview("Adaptive Navigation") {
    AdaptiveNavigationView()
}
