import SwiftUI

@MainActor
@Observable
final class NetworkViewModel {
    var devices: [NetworkDevice] = []
    var filteredDevices: [NetworkDevice] = []
    var isLoading = false
    var error: String?
    var searchText = ""

    private let client = TechnitiumClient.shared

    func loadDevices() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.getNetworkDevices()
            devices = response.devices
            applyFilter()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyFilter() {
        if searchText.isEmpty {
            filteredDevices = devices
        } else {
            filteredDevices = devices.filter { device in
                device.ip.localizedCaseInsensitiveContains(searchText) ||
                device.hostname?.localizedCaseInsensitiveContains(searchText) == true ||
                device.customName?.localizedCaseInsensitiveContains(searchText) == true ||
                device.mac?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
}

struct NetworkView: View {
    @State private var viewModel = NetworkViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.devices.isEmpty {
                    ProgressView("Loading devices...")
                } else if viewModel.error != nil {
                    VStack(spacing: 16) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(.secondary)

                        Text("Network Helper Unavailable")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Network device discovery requires the TechniLux web proxy. Connect to your server via the TechniLux web UI port (e.g., 5381) instead of the direct Technitium API port.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                    .padding()
                } else if viewModel.devices.isEmpty {
                    EmptyStateView(
                        icon: "wifi",
                        title: "No Devices",
                        description: "No network devices discovered yet"
                    )
                } else {
                    devicesList
                }
            }
            .navigationTitle("Network")
            .searchable(text: $viewModel.searchText, prompt: "Search devices")
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.applyFilter()
            }
            .refreshable {
                await viewModel.loadDevices()
            }
            .task {
                await viewModel.loadDevices()
            }
        }
    }

    private var devicesList: some View {
        List(viewModel.filteredDevices) { device in
            NavigationLink {
                NetworkDeviceDetailView(device: device)
            } label: {
                DeviceRow(device: device)
            }
        }
        .listStyle(.plain)
    }
}

struct DeviceRow: View {
    let device: NetworkDevice

    var body: some View {
        HStack {
            // Icon
            Image(systemName: deviceIcon)
                .font(.title2)
                .foregroundStyle(.techniluxPrimary)
                .frame(width: 40)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)

                Text(device.ip)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let mac = device.mac {
                    Text(mac)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Favorite indicator
            if device.favorite == true {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        device.customName ?? device.hostname ?? device.ip
    }

    private var deviceIcon: String {
        if let icon = device.icon, !icon.isEmpty {
            return icon
        }

        // Guess based on hostname or vendor
        let name = (device.hostname ?? device.vendor ?? "").lowercased()

        if name.contains("iphone") || name.contains("ipad") {
            return "iphone"
        } else if name.contains("mac") || name.contains("apple") {
            return "desktopcomputer"
        } else if name.contains("router") || name.contains("gateway") {
            return "wifi.router"
        } else if name.contains("printer") {
            return "printer"
        } else if name.contains("tv") || name.contains("roku") || name.contains("chromecast") {
            return "tv"
        }

        return "laptopcomputer"
    }
}

struct NetworkDeviceDetailView: View {
    let device: NetworkDevice

    var body: some View {
        List {
            Section("Identity") {
                InfoRow(label: "IP Address", value: device.ip)

                if let hostname = device.hostname {
                    InfoRow(label: "Hostname", value: hostname)
                }

                if let customName = device.customName {
                    InfoRow(label: "Custom Name", value: customName)
                }
            }

            if let mac = device.mac {
                Section("Hardware") {
                    InfoRow(label: "MAC Address", value: mac)

                    if let vendor = device.vendor {
                        InfoRow(label: "Vendor", value: vendor)
                    }
                }
            }

            Section("Activity") {
                InfoRow(label: "First Seen", value: device.firstSeen)
                InfoRow(label: "Last Seen", value: device.lastSeen)

                if let queryCount = device.queryCount {
                    InfoRow(label: "Query Count", value: "\(queryCount)")
                }
            }

            if let notes = device.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.subheadline)
                }
            }

            if let tags = device.tags, !tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            StatusBadge(text: tag, color: .techniluxPrimary)
                        }
                    }
                }
            }
        }
        .navigationTitle(device.customName ?? device.hostname ?? device.ip)
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

#Preview("Network View") {
    NetworkView()
}
