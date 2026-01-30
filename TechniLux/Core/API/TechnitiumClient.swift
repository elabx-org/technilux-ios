import Foundation

/// Main API client for Technitium DNS Server
@MainActor
final class TechnitiumClient: ObservableObject {
    static let shared = TechnitiumClient()

    @Published var serverURL: URL?
    @Published var token: String?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Configuration

    func configure(serverURL: URL, token: String? = nil) {
        self.serverURL = serverURL
        self.token = token
    }

    func clearSession() {
        self.token = nil
    }

    // MARK: - Request Methods

    /// Perform GET request with URL parameters
    private func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        params: [String: Any] = [:],
        node: String? = nil
    ) async throws -> ApiResponse<T> {
        guard let serverURL else {
            throw APIError.invalidURL
        }

        var urlComponents = URLComponents(url: serverURL.appendingPathComponent("/api\(endpoint.path)"), resolvingAgainstBaseURL: false)

        var queryItems: [URLQueryItem] = []

        // Add token if available
        if let token {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }

        // Add node parameter if specified
        if let node {
            queryItems.append(URLQueryItem(name: "node", value: node))
        }

        // Add other parameters
        for (key, value) in params {
            let stringValue = stringifyValue(value)
            queryItems.append(URLQueryItem(name: key, value: stringValue))
        }

        urlComponents?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        return try await performRequest(request)
    }

    /// Perform POST request with form-encoded body
    private func requestPost<T: Decodable>(
        _ endpoint: APIEndpoint,
        params: [String: Any] = [:],
        node: String? = nil
    ) async throws -> ApiResponse<T> {
        guard let serverURL else {
            throw APIError.invalidURL
        }

        var urlComponents = URLComponents(url: serverURL.appendingPathComponent("/api\(endpoint.path)"), resolvingAgainstBaseURL: false)

        // Add token to URL
        var queryItems: [URLQueryItem] = []
        if let token {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        urlComponents?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Build form data
        var bodyParams = params
        if let node {
            bodyParams["node"] = node
        }

        let formData = bodyParams.map { key, value in
            let stringValue = stringifyValue(value)
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stringValue
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")

        request.httpBody = formData.data(using: .utf8)

        return try await performRequest(request)
    }

    /// Perform POST request with JSON body (for settings/set)
    private func requestPostJson<T: Decodable>(
        _ endpoint: APIEndpoint,
        params: [String: Any] = [:],
        node: String? = nil
    ) async throws -> ApiResponse<T> {
        guard let serverURL else {
            throw APIError.invalidURL
        }

        var urlComponents = URLComponents(url: serverURL.appendingPathComponent("/api\(endpoint.path)"), resolvingAgainstBaseURL: false)

        // Add token to URL
        var queryItems: [URLQueryItem] = []
        if let token {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        urlComponents?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build JSON body
        var bodyParams = params
        if let node {
            bodyParams["node"] = node
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: bodyParams)

        return try await performRequest(request)
    }

    /// Perform the actual network request
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> ApiResponse<T> {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError("HTTP \(httpResponse.statusCode)")
            }

            let apiResponse = try decoder.decode(ApiResponse<T>.self, from: data)

            switch apiResponse.status {
            case .ok:
                return apiResponse
            case .invalidToken:
                throw APIError.invalidToken
            case .error:
                throw APIError.serverError(apiResponse.errorMessage ?? "Unknown error")
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    /// Fetch raw data (for exports)
    private func fetchRaw(_ endpoint: APIEndpoint, params: [String: Any] = [:]) async throws -> Data {
        guard let serverURL else {
            throw APIError.invalidURL
        }

        var urlComponents = URLComponents(url: serverURL.appendingPathComponent("/api\(endpoint.path)"), resolvingAgainstBaseURL: false)

        var queryItems: [URLQueryItem] = []
        if let token {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: stringifyValue(value)))
        }
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return data
    }

    /// Convert value to string for URL parameters
    /// CRITICAL: Simple arrays must be comma-separated strings, not JSON
    private func stringifyValue(_ value: Any) -> String {
        switch value {
        case let array as [Any]:
            // Check if array contains objects
            if let first = array.first, first is [String: Any] {
                // Object array - serialize as JSON
                if let data = try? JSONSerialization.data(withJSONObject: array),
                   let json = String(data: data, encoding: .utf8) {
                    return json
                }
            }
            // Simple array - comma-separated
            return array.map { stringifyValue($0) }.joined(separator: ",")
        case let dict as [String: Any]:
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let json = String(data: data, encoding: .utf8) {
                return json
            }
            return ""
        case let bool as Bool:
            return bool ? "true" : "false"
        default:
            return String(describing: value)
        }
    }

    // MARK: - Authentication

    func login(username: String, password: String) async throws -> LoginResponse {
        guard let serverURL else {
            throw APIError.invalidURL
        }

        var urlComponents = URLComponents(url: serverURL.appendingPathComponent("/api/user/login"), resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "user", value: username),
            URLQueryItem(name: "pass", value: password),
            URLQueryItem(name: "includeInfo", value: "true")
        ]

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let loginResponse = try decoder.decode(LoginResponse.self, from: data)

        guard loginResponse.status == .ok, let token = loginResponse.token else {
            throw APIError.serverError(loginResponse.errorMessage ?? "Login failed")
        }

        self.token = token
        return loginResponse
    }

    func logout() {
        token = nil
    }

    func checkSession() async throws -> SessionResponse {
        let response: ApiResponse<SessionResponse> = try await request(.sessionGet)
        guard let session = response.response else {
            throw APIError.invalidResponse
        }
        return session
    }

    // MARK: - Dashboard

    func getStats(type: StatsType = .lastHour, utc: Bool = false, node: String? = nil) async throws -> StatsResponse {
        let response: ApiResponse<StatsResponse> = try await request(
            .dashboardStats,
            params: ["type": type.rawValue, "utc": utc],
            node: node
        )
        guard let stats = response.response else {
            throw APIError.invalidResponse
        }
        return stats
    }

    func getTopStats(type: TopStatsType, statsType: StatsType = .lastHour, limit: Int = 10, node: String? = nil) async throws -> TopStatsResponse {
        let response: ApiResponse<TopStatsResponse> = try await request(
            .dashboardTopStats,
            params: ["type": type.rawValue, "statsType": statsType.rawValue, "limit": limit],
            node: node
        )
        guard let stats = response.response else {
            throw APIError.invalidResponse
        }
        return stats
    }

    // MARK: - Zones

    func listZones(node: String? = nil) async throws -> ZonesResponse {
        let response: ApiResponse<ZonesResponse> = try await request(.zonesList, node: node)
        guard let zones = response.response else {
            throw APIError.invalidResponse
        }
        return zones
    }

    func createZone(name: String, type: ZoneType, options: [String: Any] = [:], node: String? = nil) async throws {
        var params = options
        params["zone"] = name
        params["type"] = type.rawValue
        let _: ApiResponse<EmptyResponse> = try await request(.zonesCreate, params: params, node: node)
    }

    func deleteZone(name: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.zonesDelete, params: ["zone": name], node: node)
    }

    func enableZone(name: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.zonesEnable, params: ["zone": name], node: node)
    }

    func disableZone(name: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.zonesDisable, params: ["zone": name], node: node)
    }

    func getZoneOptions(zone: String, node: String? = nil) async throws -> ZoneOptions {
        let response: ApiResponse<ZoneOptions> = try await request(.zonesOptionsGet, params: ["zone": zone], node: node)
        guard let options = response.response else {
            throw APIError.invalidResponse
        }
        return options
    }

    func setZoneOptions(zone: String, options: [String: Any], node: String? = nil) async throws {
        var params = options
        params["zone"] = zone
        let _: ApiResponse<EmptyResponse> = try await request(.zonesOptionsSet, params: params, node: node)
    }

    func exportZone(zone: String) async throws -> String {
        let data = try await fetchRaw(.zonesExport, params: ["zone": zone])
        guard let text = String(data: data, encoding: .utf8) else {
            throw APIError.invalidResponse
        }
        return text
    }

    func importZone(zone: String, zoneFile: String, overwrite: Bool = false) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(
            .zonesImport,
            params: ["zone": zone, "zoneFile": zoneFile, "overwrite": overwrite]
        )
    }

    func resyncZone(zone: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.zonesResync, params: ["zone": zone], node: node)
    }

    // MARK: - Records

    func getRecords(zone: String, domain: String? = nil, listZone: Bool = true, node: String? = nil) async throws -> RecordsResponse {
        var params: [String: Any] = ["zone": zone, "domain": domain ?? zone]
        if listZone {
            params["listZone"] = true
        }
        let response: ApiResponse<RecordsResponse> = try await request(.recordsGet, params: params, node: node)
        guard let records = response.response else {
            throw APIError.invalidResponse
        }
        return records
    }

    func addRecord(zone: String, domain: String, type: RecordType, ttl: Int, recordData: [String: Any], node: String? = nil) async throws {
        var params = recordData
        params["zone"] = zone
        params["domain"] = domain
        params["type"] = type.rawValue
        params["ttl"] = ttl
        let _: ApiResponse<EmptyResponse> = try await request(.recordsAdd, params: params, node: node)
    }

    func updateRecord(
        zone: String,
        domain: String,
        type: RecordType,
        ttl: Int,
        newDomain: String,
        recordData: [String: Any],
        disable: Bool = false,
        node: String? = nil
    ) async throws {
        var params = recordData
        params["zone"] = zone
        params["domain"] = domain
        params["type"] = type.rawValue
        params["ttl"] = ttl
        params["newDomain"] = newDomain
        params["disable"] = disable
        let _: ApiResponse<EmptyResponse> = try await request(.recordsUpdate, params: params, node: node)
    }

    func deleteRecord(zone: String, domain: String, type: RecordType, recordData: [String: Any], node: String? = nil) async throws {
        var params = recordData
        params["zone"] = zone
        params["domain"] = domain
        params["type"] = type.rawValue
        let _: ApiResponse<EmptyResponse> = try await request(.recordsDelete, params: params, node: node)
    }

    // MARK: - DNSSEC

    func dnssecSign(
        zone: String,
        algorithm: String = "ECDSA_P256_SHA256",
        dnsKeyTtl: Int = 86400,
        zskRolloverDays: Int = 30,
        nxProof: String = "NSEC3",
        iterations: Int = 0,
        saltLength: Int = 0
    ) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.dnssecSign, params: [
            "zone": zone,
            "algorithm": algorithm,
            "dnsKeyTtl": dnsKeyTtl,
            "zskRolloverDays": zskRolloverDays,
            "nxProof": nxProof,
            "iterations": iterations,
            "saltLength": saltLength
        ])
    }

    func dnssecUnsign(zone: String) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.dnssecUnsign, params: ["zone": zone])
    }

    func getDnssecProperties(zone: String) async throws -> DnssecProperties {
        let response: ApiResponse<DnssecProperties> = try await request(.dnssecPropertiesGet, params: ["zone": zone])
        guard let props = response.response else {
            throw APIError.invalidResponse
        }
        return props
    }

    // MARK: - Blocking

    func listBlockedDomains(domain: String? = nil, node: String? = nil) async throws -> DomainsResponse {
        var params: [String: Any] = [:]
        if let domain { params["domain"] = domain }
        let response: ApiResponse<DomainsResponse> = try await request(.blockedList, params: params, node: node)
        guard let domains = response.response else {
            throw APIError.invalidResponse
        }
        return domains
    }

    func addBlockedDomain(domain: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.blockedAdd, params: ["domain": domain], node: node)
    }

    func deleteBlockedDomain(domain: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.blockedDelete, params: ["domain": domain], node: node)
    }

    func listAllowedDomains(domain: String? = nil, node: String? = nil) async throws -> DomainsResponse {
        var params: [String: Any] = [:]
        if let domain { params["domain"] = domain }
        let response: ApiResponse<DomainsResponse> = try await request(.allowedList, params: params, node: node)
        guard let domains = response.response else {
            throw APIError.invalidResponse
        }
        return domains
    }

    func addAllowedDomain(domain: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.allowedAdd, params: ["domain": domain], node: node)
    }

    func deleteAllowedDomain(domain: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.allowedDelete, params: ["domain": domain], node: node)
    }

    func isBlocked(domain: String, node: String? = nil) async throws -> BlockedCheckResponse {
        let response: ApiResponse<BlockedCheckResponse> = try await request(.blockedIsBlocked, params: ["domain": domain], node: node)
        guard let result = response.response else {
            throw APIError.invalidResponse
        }
        return result
    }

    // MARK: - Cache

    func listCachedZones(domain: String = "", node: String? = nil) async throws -> CacheResponse {
        let response: ApiResponse<CacheResponse> = try await request(.cacheList, params: ["domain": domain], node: node)
        guard let cache = response.response else {
            throw APIError.invalidResponse
        }
        return cache
    }

    func deleteCachedZone(domain: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.cacheDelete, params: ["domain": domain], node: node)
    }

    func flushCache(node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.cacheFlush, node: node)
    }

    func prefetchCache(domain: String, type: String = "A", dnssec: Bool = false, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(
            .cachePrefetch,
            params: ["domain": domain, "type": type, "dnssec": dnssec],
            node: node
        )
    }

    // MARK: - Logs

    func queryLogs(
        appName: String,
        classPath: String,
        pageNumber: Int = 1,
        entriesPerPage: Int = 100,
        descendingOrder: Bool = true,
        filters: [String: Any] = [:],
        node: String? = nil
    ) async throws -> LogsResponse {
        var params = filters
        params["name"] = appName
        params["classPath"] = classPath
        params["pageNumber"] = pageNumber
        params["entriesPerPage"] = entriesPerPage
        params["descendingOrder"] = descendingOrder
        let response: ApiResponse<LogsResponse> = try await request(.logsQuery, params: params, node: node)
        guard let logs = response.response else {
            throw APIError.invalidResponse
        }
        return logs
    }

    func listLogFiles(node: String? = nil) async throws -> LogFilesResponse {
        let response: ApiResponse<LogFilesResponse> = try await request(.logsList, node: node)
        guard let files = response.response else {
            throw APIError.invalidResponse
        }
        return files
    }

    func deleteLogFile(fileName: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.logsDelete, params: ["fileName": fileName], node: node)
    }

    func deleteAllLogs(node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.logsDeleteAll, node: node)
    }

    // MARK: - DHCP

    func listDhcpScopes(node: String? = nil) async throws -> DhcpScopesResponse {
        let response: ApiResponse<DhcpScopesResponse> = try await request(.dhcpScopesList, node: node)
        guard let scopes = response.response else {
            throw APIError.invalidResponse
        }
        return scopes
    }

    func getDhcpScope(name: String, node: String? = nil) async throws -> DhcpScope {
        let response: ApiResponse<DhcpScope> = try await request(.dhcpScopesGet, params: ["name": name], node: node)
        guard let scope = response.response else {
            throw APIError.invalidResponse
        }
        return scope
    }

    func setDhcpScope(scope: [String: Any], node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.dhcpScopesSet, params: scope, node: node)
    }

    func deleteDhcpScope(name: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.dhcpScopesDelete, params: ["name": name], node: node)
    }

    func enableDhcpScope(name: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.dhcpScopesEnable, params: ["name": name], node: node)
    }

    func disableDhcpScope(name: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.dhcpScopesDisable, params: ["name": name], node: node)
    }

    func listDhcpLeases(scope: String, node: String? = nil) async throws -> DhcpLeasesResponse {
        let response: ApiResponse<DhcpLeasesResponse> = try await request(.dhcpLeasesList, params: ["name": scope], node: node)
        guard let leases = response.response else {
            throw APIError.invalidResponse
        }
        return leases
    }

    func removeDhcpLease(scope: String, hardwareAddress: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(
            .dhcpLeasesRemove,
            params: ["name": scope, "hardwareAddress": hardwareAddress],
            node: node
        )
    }

    // MARK: - Apps

    func listApps(node: String? = nil) async throws -> AppsResponse {
        let response: ApiResponse<AppsResponse> = try await request(.appsList, node: node)
        guard let apps = response.response else {
            throw APIError.invalidResponse
        }
        return apps
    }

    func listStoreApps() async throws -> AppStoreResponse {
        let response: ApiResponse<AppStoreResponse> = try await request(.appsListStore)
        guard let apps = response.response else {
            throw APIError.invalidResponse
        }
        return apps
    }

    func downloadApp(name: String, url: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.appsDownload, params: ["name": name, "url": url], node: node)
    }

    func updateApp(name: String, url: String? = nil, node: String? = nil) async throws {
        var params: [String: Any] = ["name": name]
        if let url { params["url"] = url }
        let _: ApiResponse<EmptyResponse> = try await request(.appsUpdate, params: params, node: node)
    }

    func uninstallApp(name: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.appsUninstall, params: ["name": name], node: node)
    }

    func getAppConfig(name: String, node: String? = nil) async throws -> AppConfigResponse {
        let response: ApiResponse<AppConfigResponse> = try await request(.appsConfigGet, params: ["name": name], node: node)
        guard let config = response.response else {
            throw APIError.invalidResponse
        }
        return config
    }

    func setAppConfig(name: String, config: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await requestPost(.appsConfigSet, params: ["name": name, "config": config], node: node)
    }

    // MARK: - Settings

    func getSettings(node: String? = nil) async throws -> DnsSettings {
        let response: ApiResponse<DnsSettings> = try await request(.settingsGet, node: node)
        guard let settings = response.response else {
            throw APIError.invalidResponse
        }
        return settings
    }

    func setSettings(settings: [String: Any], node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await requestPostJson(.settingsSet, params: settings, node: node)
    }

    func forceUpdateBlockLists(node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.settingsForceUpdateBlockLists, node: node)
    }

    func temporaryDisableBlocking(minutes: Int) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.settingsTemporaryDisableBlocking, params: ["minutes": minutes])
    }

    func checkForUpdate() async throws -> UpdateCheckResponse {
        let response: ApiResponse<UpdateCheckResponse> = try await request(.settingsCheckForUpdate)
        guard let update = response.response else {
            throw APIError.invalidResponse
        }
        return update
    }

    // MARK: - Admin Users

    func listUsers() async throws -> UsersResponse {
        let response: ApiResponse<UsersResponse> = try await request(.usersList)
        guard let users = response.response else {
            throw APIError.invalidResponse
        }
        return users
    }

    func createUser(user: [String: Any]) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.usersCreate, params: user)
    }

    func deleteUser(username: String) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.usersDelete, params: ["user": username])
    }

    func getUser(username: String) async throws -> User {
        let response: ApiResponse<User> = try await request(.usersGet, params: ["user": username])
        guard let user = response.response else {
            throw APIError.invalidResponse
        }
        return user
    }

    func setUser(user: [String: Any]) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.usersSet, params: user)
    }

    func enableUser(username: String) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.usersEnable, params: ["user": username])
    }

    func disableUser(username: String) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.usersDisable, params: ["user": username])
    }

    func setUserPassword(username: String, newPassword: String) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.usersSetPassword, params: ["user": username, "newPassword": newPassword])
    }

    // MARK: - Admin Groups

    func listGroups() async throws -> GroupsResponse {
        let response: ApiResponse<GroupsResponse> = try await request(.groupsList)
        guard let groups = response.response else {
            throw APIError.invalidResponse
        }
        return groups
    }

    func createGroup(name: String, description: String) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.groupsCreate, params: ["group": name, "description": description])
    }

    func deleteGroup(name: String) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.groupsDelete, params: ["group": name])
    }

    func getGroup(name: String) async throws -> GroupDetails {
        let response: ApiResponse<GroupDetails> = try await request(.groupsGet, params: ["group": name])
        guard let group = response.response else {
            throw APIError.invalidResponse
        }
        return group
    }

    func setGroup(group: [String: Any]) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.groupsSet, params: group)
    }

    // MARK: - Admin Sessions

    func listSessions() async throws -> SessionsResponse {
        let response: ApiResponse<SessionsResponse> = try await request(.sessionsList)
        guard let sessions = response.response else {
            throw APIError.invalidResponse
        }
        return sessions
    }

    func deleteSession(partialToken: String) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.sessionsDelete, params: ["partialToken": partialToken])
    }

    // MARK: - Cluster

    func getClusterState(node: String? = nil, includeServerIpAddresses: Bool = false) async throws -> ClusterStateResponse {
        var params: [String: Any] = [:]
        if includeServerIpAddresses {
            params["includeServerIpAddresses"] = true
        }
        let response: ApiResponse<ClusterStateResponse> = try await request(.clusterState, params: params, node: node)
        guard let state = response.response else {
            throw APIError.invalidResponse
        }
        return state
    }

    func initCluster(clusterDomain: String, primaryNodeIpAddresses: String) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(
            .clusterInit,
            params: ["clusterDomain": clusterDomain, "primaryNodeIpAddresses": primaryNodeIpAddresses]
        )
    }

    func joinCluster(params: [String: Any]) async throws {
        let _: ApiResponse<EmptyResponse> = try await requestPost(.clusterJoin, params: params)
    }

    func deleteCluster(forceDelete: Bool = false, node: String? = nil) async throws {
        var params: [String: Any] = [:]
        if forceDelete { params["forceDelete"] = true }
        let _: ApiResponse<EmptyResponse> = try await request(.clusterDelete, params: params, node: node)
    }

    func removeSecondaryNode(secondaryNodeId: String, forceRemove: Bool = false, node: String? = nil) async throws {
        let endpoint: APIEndpoint = forceRemove ? .clusterDeleteSecondary : .clusterRemoveSecondary
        let _: ApiResponse<EmptyResponse> = try await request(endpoint, params: ["secondaryNodeId": secondaryNodeId], node: node)
    }

    func leaveCluster(forceLeave: Bool = false, node: String? = nil) async throws {
        var params: [String: Any] = [:]
        if forceLeave { params["forceLeave"] = true }
        let _: ApiResponse<EmptyResponse> = try await request(.clusterLeave, params: params, node: node)
    }

    func promoteToPrimary(forceDeletePrimary: Bool = false, node: String? = nil) async throws {
        var params: [String: Any] = [:]
        if forceDeletePrimary { params["forceDeletePrimary"] = true }
        let _: ApiResponse<EmptyResponse> = try await request(.clusterPromote, params: params, node: node)
    }

    func resyncCluster(node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.clusterResync, node: node)
    }

    // MARK: - DNS Client

    func resolveDns(
        server: String,
        domain: String,
        type: String,
        queryProtocol: String = "Udp",
        dnssec: Bool = false,
        eDnsClientSubnet: String? = nil,
        importRecords: Bool = false,
        node: String? = nil
    ) async throws -> DnsResolveResponse {
        var params: [String: Any] = [
            "server": server,
            "domain": domain,
            "type": type,
            "protocol": queryProtocol,
            "dnssec": dnssec
        ]
        if let eDnsClientSubnet { params["eDnsClientSubnet"] = eDnsClientSubnet }
        if importRecords { params["import"] = true }

        let response: ApiResponse<DnsResolveResponse> = try await request(.dnsClientResolve, params: params, node: node)
        guard let result = response.response else {
            throw APIError.invalidResponse
        }
        return result
    }

    func flushDnsClientCache() async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.dnsClientFlushCache)
    }

    // MARK: - User Profile

    func getProfile() async throws -> ProfileResponse {
        let response: ApiResponse<ProfileResponse> = try await request(.profileGet)
        guard let profile = response.response else {
            throw APIError.invalidResponse
        }
        return profile
    }

    func setProfile(displayName: String? = nil, sessionTimeoutSeconds: Int? = nil) async throws {
        var params: [String: Any] = [:]
        if let displayName { params["displayName"] = displayName }
        if let sessionTimeoutSeconds { params["sessionTimeoutSeconds"] = sessionTimeoutSeconds }
        let _: ApiResponse<EmptyResponse> = try await request(.profileSet, params: params)
    }

    func changePassword(currentPassword: String, newPassword: String, totp: String? = nil) async throws {
        var params: [String: Any] = ["pass": currentPassword, "newPass": newPassword]
        if let totp { params["totp"] = totp }
        let _: ApiResponse<EmptyResponse> = try await request(.changePassword, params: params)
    }

    func createApiToken(username: String, password: String, tokenName: String, totp: String? = nil) async throws -> TokenResponse {
        var params: [String: Any] = ["user": username, "pass": password, "tokenName": tokenName]
        if let totp { params["totp"] = totp }
        let response: ApiResponse<TokenResponse> = try await request(.createToken, params: params)
        guard let token = response.response else {
            throw APIError.invalidResponse
        }
        return token
    }

    // MARK: - 2FA

    func init2FA() async throws -> TwoFactorInitResponse {
        let response: ApiResponse<TwoFactorInitResponse> = try await request(.twoFactorInit)
        guard let result = response.response else {
            throw APIError.invalidResponse
        }
        return result
    }

    func enable2FA(totp: String) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.twoFactorEnable, params: ["totp": totp])
    }

    func disable2FA() async throws {
        let _: ApiResponse<EmptyResponse> = try await request(.twoFactorDisable)
    }

    // MARK: - Network Helper

    func getNetworkDevices() async throws -> NetworkDevicesResponse {
        let response: ApiResponse<NetworkDevicesResponse> = try await request(.networkDevices)
        guard let devices = response.response else {
            throw APIError.invalidResponse
        }
        return devices
    }

    func getNetworkDevice(ip: String) async throws -> NetworkDevice {
        let response: ApiResponse<NetworkDeviceResponse> = try await request(.networkDeviceGet, params: ["ip": ip])
        guard let device = response.response?.device else {
            throw APIError.invalidResponse
        }
        return device
    }

    // MARK: - Backup & Restore

    func downloadBackup(
        blockLists: Bool = true,
        logs: Bool = true,
        scopes: Bool = true,
        apps: Bool = true,
        stats: Bool = true,
        zones: Bool = true,
        allowedZones: Bool = true,
        blockedZones: Bool = true,
        dnsSettings: Bool = true,
        authConfig: Bool = true,
        logSettings: Bool = true,
        node: String? = nil
    ) async throws -> Data {
        var params: [String: Any] = [
            "blockLists": blockLists,
            "logs": logs,
            "scopes": scopes,
            "apps": apps,
            "stats": stats,
            "zones": zones,
            "allowedZones": allowedZones,
            "blockedZones": blockedZones,
            "dnsSettings": dnsSettings,
            "authConfig": authConfig,
            "logSettings": logSettings
        ]
        if let node { params["node"] = node }

        return try await fetchRaw(.settingsBackup, params: params)
    }

    func restoreBackup(data: Data, deleteExistingFiles: Bool = false, node: String? = nil) async throws {
        guard let serverURL else {
            throw APIError.invalidURL
        }

        var urlComponents = URLComponents(url: serverURL.appendingPathComponent("/api/settings/restore"), resolvingAgainstBaseURL: false)

        var queryItems: [URLQueryItem] = []
        if let token {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        if let node {
            queryItems.append(URLQueryItem(name: "node", value: node))
        }
        queryItems.append(URLQueryItem(name: "deleteExistingFiles", value: deleteExistingFiles ? "true" : "false"))
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"backup.zip\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/zip\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let apiResponse = try decoder.decode(ApiResponse<EmptyResponse>.self, from: responseData)
        if apiResponse.status == .error {
            throw APIError.serverError(apiResponse.errorMessage ?? "Restore failed")
        }
    }

    // MARK: - Zone Clone/Convert

    func cloneZone(zone: String, sourceZone: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(
            .zonesClone,
            params: ["zone": zone, "sourceZone": sourceZone],
            node: node
        )
    }

    func convertZone(zone: String, type: ZoneType, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(
            .zonesConvert,
            params: ["zone": zone, "type": type.rawValue],
            node: node
        )
    }

    // MARK: - Zone Permissions

    func getZonePermissions(zone: String, node: String? = nil) async throws -> ZonePermissionsResponse {
        let response: ApiResponse<ZonePermissionsResponse> = try await request(
            .zonePermissionsGet,
            params: ["zone": zone],
            node: node
        )
        guard let permissions = response.response else {
            throw APIError.invalidResponse
        }
        return permissions
    }

    func setZonePermissions(zone: String, userPermissions: String, groupPermissions: String, node: String? = nil) async throws {
        let _: ApiResponse<EmptyResponse> = try await request(
            .zonePermissionsSet,
            params: [
                "zone": zone,
                "userPermissions": userPermissions,
                "groupPermissions": groupPermissions
            ],
            node: node
        )
    }
}
