import SwiftUI

/// Picker for selecting a cluster node
struct ClusterNodePicker: View {
    @Bindable var cluster = ClusterService.shared

    var body: some View {
        if cluster.hasMultipleNodes {
            Menu {
                ForEach(cluster.nodes) { node in
                    Button {
                        cluster.selectNode(node.state == "Self" ? nil : node.name)
                    } label: {
                        HStack {
                            Text(node.name)
                            Spacer()
                            if isSelected(node) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                        .font(.subheadline)

                    Text(currentNodeName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
    }

    private var currentNodeName: String {
        cluster.currentNode?.name ?? "Local"
    }

    private func isSelected(_ node: ClusterNode) -> Bool {
        if cluster.selectedNode == nil {
            return node.state == "Self"
        }
        return node.name == cluster.selectedNode
    }
}

/// Compact cluster indicator for navigation bar
struct ClusterIndicator: View {
    @Bindable var cluster = ClusterService.shared

    var body: some View {
        if cluster.initialized {
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)

                Text("\(cluster.nodes.count) nodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Full cluster status view
struct ClusterStatusView: View {
    @Bindable var cluster = ClusterService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if cluster.initialized {
                HStack {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.techniluxPrimary)

                    Text("Cluster: \(cluster.clusterDomain ?? "Unknown")")
                        .font(.headline)
                }

                ForEach(cluster.nodes) { node in
                    NodeStatusRow(node: node, isSelected: isSelected(node))
                        .onTapGesture {
                            cluster.selectNode(node.state == "Self" ? nil : node.name)
                        }
                }
            } else {
                HStack {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.secondary)

                    Text("Cluster not configured")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .glassCard()
    }

    private func isSelected(_ node: ClusterNode) -> Bool {
        if cluster.selectedNode == nil {
            return node.state == "Self"
        }
        return node.name == cluster.selectedNode
    }
}

/// Row showing a cluster node's status
struct NodeStatusRow: View {
    let node: ClusterNode
    let isSelected: Bool

    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(node.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)

                    if node.type == "Primary" {
                        StatusBadge(text: "Primary", color: .techniluxPrimary)
                    }

                    if node.state == "Self" {
                        StatusBadge(text: "Self", color: .techniluxInfo)
                    }
                }

                Text(node.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.techniluxPrimary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.techniluxPrimary.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch node.state {
        case "Self", "Connected":
            return .green
        case "Unreachable":
            return .red
        default:
            return .orange
        }
    }
}

// MARK: - Previews

#Preview("Cluster Node Picker") {
    ClusterNodePicker()
        .padding()
}
