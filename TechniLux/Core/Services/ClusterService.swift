import Foundation

/// Service for managing cluster state and node selection
@MainActor
@Observable
final class ClusterService {
    static let shared = ClusterService()

    var initialized = false
    var clusterDomain: String?
    var nodes: [ClusterNode] = []
    var selectedNode: String?
    var isLoading = false
    var error: String?

    private let client = TechnitiumClient.shared

    private init() {}

    /// The node parameter to pass to API calls
    var nodeParam: String? {
        selectedNode
    }

    /// Whether the cluster has multiple nodes
    var hasMultipleNodes: Bool {
        nodes.count > 1
    }

    /// The self/local node
    var selfNode: ClusterNode? {
        nodes.first { $0.state == "Self" }
    }

    /// The currently selected node object
    var currentNode: ClusterNode? {
        if let selectedNode {
            return nodes.first { $0.name == selectedNode }
        }
        return selfNode
    }

    /// Load cluster state from API
    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.getClusterState(includeServerIpAddresses: true)

            if let isInitialized = response.clusterInitialized, isInitialized,
               let domain = response.clusterDomain,
               let clusterNodes = response.clusterNodes {
                initialized = true
                clusterDomain = domain
                nodes = clusterNodes
                selectedNode = nil // Default to self
            } else {
                // Cluster not initialized
                initialized = false
                clusterDomain = nil
                nodes = []
                selectedNode = nil
            }
        } catch {
            // Error fetching cluster state - likely not initialized
            initialized = false
            clusterDomain = nil
            nodes = []
            selectedNode = nil
            self.error = error.localizedDescription
        }
    }

    /// Select a cluster node
    func selectNode(_ nodeName: String?) {
        selectedNode = nodeName
    }

    /// Reset cluster state (e.g., on logout)
    func reset() {
        initialized = false
        clusterDomain = nil
        nodes = []
        selectedNode = nil
        error = nil
    }
}
