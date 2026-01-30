import Foundation

// MARK: - Authentication

struct LoginResponse: Decodable {
    let status: ResponseStatus
    let token: String?
    let username: String?
    let displayName: String?
    let errorMessage: String?
    let info: ServerInfo?
}

struct SessionResponse: Decodable {
    let username: String
    let displayName: String?
    let info: ServerInfo?
}

struct ServerInfo: Decodable {
    let version: String
    let uptimestamp: String?
    let dnsServerDomain: String?
    let dnssecValidation: Bool?
    let defaultRecordTtl: Int?
    let useSoaSerialDateScheme: Bool?
    let clusterInitialized: Bool?
}

struct UserSession: Codable {
    let username: String
    let displayName: String?
    let token: String
    let serverURL: String
}

// MARK: - Dashboard

enum StatsType: String, CaseIterable {
    case lastHour = "LastHour"
    case lastDay = "LastDay"
    case lastWeek = "LastWeek"
    case lastMonth = "LastMonth"
    case lastYear = "LastYear"
    case custom = "Custom"
}

enum TopStatsType: String {
    case topClients = "TopClients"
    case topDomains = "TopDomains"
    case topBlockedDomains = "TopBlockedDomains"
}

struct StatsResponse: Decodable {
    let stats: DashboardStats
    let mainChartData: ChartData?
    let queryResponseChartData: ChartData?
    let queryTypeChartData: ChartData?
    let protocolTypeChartData: ChartData?
    let topClients: [TopStat]?
    let topDomains: [TopStat]?
    let topBlockedDomains: [TopStat]?
}

struct DashboardStats: Decodable {
    let totalQueries: Int
    let totalNoError: Int
    let totalServerFailure: Int
    let totalNxDomain: Int
    let totalRefused: Int
    let totalAuthoritative: Int
    let totalRecursive: Int
    let totalCached: Int
    let totalBlocked: Int
    let totalDropped: Int
    let totalClients: Int
    let zones: Int
    let cachedEntries: Int
    let allowedZones: Int
    let blockedZones: Int
    let allowListZones: Int
    let blockListZones: Int
}

struct ChartData: Decodable {
    let labels: [String]
    let labelFormat: String?
    let datasets: [ChartDataset]
}

struct ChartDataset: Decodable {
    let label: String?
    let data: [Double]
    let backgroundColor: BackgroundColor
    let borderColor: String?
    let borderWidth: Int?
    let fill: Bool?

    enum BackgroundColor: Decodable {
        case single(String)
        case multiple([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let single = try? container.decode(String.self) {
                self = .single(single)
            } else if let multiple = try? container.decode([String].self) {
                self = .multiple(multiple)
            } else {
                self = .single("")
            }
        }
    }
}

struct TopStat: Decodable, Identifiable {
    let name: String
    let hits: Int
    let domain: String?
    let rateLimited: Bool?

    var id: String { name }
}

struct TopStatsResponse: Decodable {
    let topClients: [TopStat]?
    let topDomains: [TopStat]?
    let topBlockedDomains: [TopStat]?
}

// MARK: - Zones

enum ZoneType: String, Codable, CaseIterable {
    case primary = "Primary"
    case secondary = "Secondary"
    case stub = "Stub"
    case forwarder = "Forwarder"
    case secondaryForwarder = "SecondaryForwarder"
    case catalog = "Catalog"
    case secondaryCatalog = "SecondaryCatalog"
}

struct Zone: Decodable, Identifiable {
    let name: String
    let type: ZoneType
    let `internal`: Bool?
    let dnssecStatus: String?
    let soaSerial: Int?
    let expiry: String?
    let isExpired: Bool?
    let lastModified: String?
    let disabled: Bool?
    let catalog: String?
    let syncFailed: Bool?
    let notifyFailed: Bool?
    let notifyFailedFor: [String]?
    let validationFailed: Bool?

    var id: String { name }

    var isDisabled: Bool { disabled ?? false }
    var isInternal: Bool { `internal` ?? false }
    var dnssec: String { dnssecStatus ?? "Unsigned" }
}

struct ZonesResponse: Decodable {
    let zones: [Zone]
}

struct ZoneOptions: Decodable {
    let name: String
    let type: ZoneType
    let `internal`: Bool
    let dnssecStatus: String
    let disabled: Bool
    let catalog: String?
    let overrideCatalogQueryAccess: Bool?
    let overrideCatalogZoneTransfer: Bool?
    let overrideCatalogNotify: Bool?
    let queryAccess: String?
    let queryAccessNetworkACL: [String]?
    let zoneTransfer: String?
    let zoneTransferNetworkACL: [String]?
    let zoneTransferTsigKeyNames: [String]?
    let notify: String?
    let notifyNameServers: [String]?
    let notifySecondaryCatalog: Bool?
    let update: String?
    let updateNetworkACL: [String]?
    let primaryNameServerAddresses: [String]?
    let primaryZoneTransferProtocol: String?
    let primaryZoneTransferTsigKeyName: String?
    let validateZone: Bool?
}

// MARK: - Records

enum RecordType: String, Codable, CaseIterable {
    case a = "A"
    case aaaa = "AAAA"
    case aname = "ANAME"
    case caa = "CAA"
    case cname = "CNAME"
    case dname = "DNAME"
    case ds = "DS"
    case fwd = "FWD"
    case https = "HTTPS"
    case mx = "MX"
    case naptr = "NAPTR"
    case ns = "NS"
    case ptr = "PTR"
    case soa = "SOA"
    case srv = "SRV"
    case sshfp = "SSHFP"
    case svcb = "SVCB"
    case tlsa = "TLSA"
    case txt = "TXT"
    case uri = "URI"
    case app = "APP"
}

struct DnsRecord: Decodable, Identifiable {
    let name: String
    let type: RecordType
    let ttl: Int
    let disabled: Bool
    let rData: [String: AnyCodable]
    let dnssecStatus: String?
    let lastUsedOn: String?

    var id: String { "\(name)-\(type.rawValue)-\(rDataString)" }

    var rDataString: String {
        rData.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
    }
}

struct RecordsResponse: Decodable {
    let records: [DnsRecord]
}

// MARK: - DNSSEC

struct DnssecProperties: Decodable {
    let dnssecStatus: String
    let algorithm: String?
    let dnsKeyTtl: Int?
    let zskRolloverDays: Int?
    let nxProof: String?
    let iterations: Int?
    let saltLength: Int?
}

// MARK: - Blocking

struct DomainEntry: Decodable {
    let domain: String
}

struct DomainsResponse: Decodable {
    let domains: [DomainEntry]

    /// Get just the domain strings
    var domainStrings: [String] {
        domains.map { $0.domain }
    }
}

struct BlockedCheckResponse: Decodable {
    let isBlocked: Bool
    let blockedBy: String?
    let blockListUrl: String?
}

// MARK: - Cache

struct CacheEntry: Decodable, Identifiable {
    let zone: String
    let records: [CacheRecord]?

    var id: String { zone }
}

struct CacheRecord: Decodable {
    let name: String
    let type: String
    let ttl: Int
    let rData: [String: AnyCodable]?
}

struct CacheResponse: Decodable {
    let zones: [CacheEntry]
}

// MARK: - Logs

struct LogEntry: Decodable, Identifiable {
    let rowNumber: Int
    let timestamp: String
    let clientIpAddress: String
    let `protocol`: String
    let responseType: String
    let rcode: String
    let qname: String
    let qtype: String
    let qclass: String
    let answer: String?

    var id: Int { rowNumber }
}

struct LogsResponse: Decodable {
    let pageNumber: Int
    let totalPages: Int
    let totalEntries: Int
    let entries: [LogEntry]
}

struct LogFile: Decodable, Identifiable {
    let fileName: String
    let size: Int

    var id: String { fileName }
}

struct LogFilesResponse: Decodable {
    let logFiles: [LogFile]
}

// MARK: - DHCP

struct DhcpScope: Decodable, Identifiable {
    let name: String
    let enabled: Bool
    let startingAddress: String
    let endingAddress: String
    let subnetMask: String
    let leaseTimeDays: Int?
    let leaseTimeHours: Int?
    let leaseTimeMinutes: Int?
    let offerDelayTime: Int?
    let pingCheckEnabled: Bool?
    let pingCheckTimeout: Int?
    let pingCheckRetries: Int?
    let domainName: String?
    let domainSearchList: [String]?
    let dnsUpdates: Bool?
    let dnsTtl: Int?
    let useThisDnsServer: Bool?
    let routerAddress: String?
    let dnsServers: [String]?
    let winsServers: [String]?
    let ntpServers: [String]?
    let ntpServerDomainNames: [String]?
    let serverAddress: String?
    let serverHostName: String?
    let bootFileName: String?
    let allowOnlyReservedLeases: Bool?
    let blockLocallyAdministeredMacAddresses: Bool?
    let ignoreClientIdentifierOption: Bool?

    var id: String { name }
}

struct DhcpScopesResponse: Decodable {
    let scopes: [DhcpScope]
}

struct DhcpLease: Decodable, Identifiable {
    let scope: String
    let type: String
    let hardwareAddress: String
    let clientIdentifier: String?
    let address: String
    let hostName: String?
    let leaseObtained: String
    let leaseExpires: String

    var id: String { "\(scope)-\(hardwareAddress)" }
}

struct DhcpLeasesResponse: Decodable {
    let leases: [DhcpLease]
}

// MARK: - Apps

struct DnsApp: Decodable, Identifiable {
    let name: String
    let description: String
    let version: String
    let updateVersion: String?
    let updateUrl: String?
    let dnsApps: [DnsAppProcessor]?

    var id: String { name }
}

struct DnsAppProcessor: Decodable {
    let classPath: String
    let description: String
    let isAppRecordRequestHandler: Bool?
    let isRequestController: Bool?
    let isAuthoritativeRequestHandler: Bool?
    let isRequestBlockingHandler: Bool?
    let isQueryLogger: Bool?
    let isPostProcessor: Bool?
}

struct AppsResponse: Decodable {
    let apps: [DnsApp]
}

struct AppStoreEntry: Decodable, Identifiable {
    let name: String
    let description: String
    let version: String
    let url: String
    let size: String
    let lastModified: String?

    var id: String { name }
}

struct AppStoreResponse: Decodable {
    let storeApps: [AppStoreEntry]
}

struct AppConfigResponse: Decodable {
    let config: String
}

// MARK: - Settings

struct DnsSettings: Decodable {
    let version: String
    let uptimestamp: String?
    let clusterInitialized: Bool?
    let dnsServerDomain: String
    let dnsServerLocalEndPoints: [String]?
    let defaultRecordTtl: Int
    let defaultNsRecordTtl: Int?
    let defaultSoaRecordTtl: Int?
    let useSoaSerialDateScheme: Bool?
    let preferIPv6: Bool?
    let udpPayloadSize: Int?
    let dnssecValidation: Bool?
    let eDnsClientSubnet: Bool?
    let qnameMinimization: Bool?
    let nsRevalidation: Bool?
    let resolverRetries: Int?
    let resolverTimeout: Int?
    let saveCache: Bool?
    let serveStale: Bool?
    let cacheMaximumEntries: Int?
    let cacheMinimumRecordTtl: Int?
    let cacheMaximumRecordTtl: Int?
    let enableBlocking: Bool?
    let allowTxtBlockingReport: Bool?
    let blockingType: String?
    let blockingAnswerTtl: Int?
    let blockListUrls: [String]?
    let blockListUpdateIntervalHours: Int?
    let blockListNextUpdatedOn: String?
    let forwarders: [String]?
    let forwarderProtocol: String?
    let concurrentForwarding: Bool?
    let enableLogging: Bool?
    let loggingType: String?
    let logQueries: Bool?
    let useLocalTime: Bool?
    let logFolder: String?
    let maxLogFileDays: Int?
    let enableInMemoryStats: Bool?
    let maxStatFileDays: Int?
    let recursion: String?
    let webServiceHttpPort: Int?
    let webServiceEnableTls: Bool?
    let webServiceTlsPort: Int?
    let enableDnsOverHttp: Bool?
    let enableDnsOverTls: Bool?
    let enableDnsOverHttps: Bool?
    let enableDnsOverQuic: Bool?
    let dnsOverHttpPort: Int?
    let dnsOverTlsPort: Int?
    let dnsOverHttpsPort: Int?
    let dnsOverQuicPort: Int?
    let tsigKeys: [TsigKey]?
}

struct TsigKey: Decodable, Identifiable {
    let keyName: String
    let sharedSecret: String
    let algorithmName: String

    var id: String { keyName }
}

struct UpdateCheckResponse: Decodable {
    let updateAvailable: Bool
    let updateVersion: String?
    let currentVersion: String?
}

// MARK: - Admin

struct User: Decodable, Identifiable {
    let username: String
    let displayName: String?
    let disabled: Bool
    let previousSessionLoggedOn: String?
    let previousSessionRemoteAddress: String?
    let recentSessionLoggedOn: String?
    let recentSessionRemoteAddress: String?
    let sessionTimeoutSeconds: Int?
    let memberOfGroups: [String]?

    var id: String { username }
}

struct UsersResponse: Decodable {
    let users: [User]
}

struct UserGroup: Decodable, Identifiable {
    let name: String
    let description: String
    let members: [String]?

    var id: String { name }
}

struct GroupsResponse: Decodable {
    let groups: [UserGroup]
}

struct GroupDetails: Decodable {
    let name: String
    let description: String
    let members: [String]?
    let permissions: GroupPermissions?
}

struct GroupPermissions: Decodable {
    let dashboard: PermissionSection?
    let zones: ZonePermissionSection?
    let cache: PermissionSection?
    let allowed: PermissionSection?
    let blocked: PermissionSection?
    let apps: PermissionSection?
    let dhcp: PermissionSection?
    let administration: PermissionSection?
    let settings: PermissionSection?
    let logs: PermissionSection?
}

struct PermissionSection: Decodable {
    let canView: Bool
    let canModify: Bool
    let canDelete: Bool
}

struct ZonePermissionSection: Decodable {
    let canView: Bool
    let canModify: Bool
    let canDelete: Bool
    let canCreate: Bool
}

struct Session: Decodable, Identifiable {
    let username: String
    let isCurrentSession: Bool
    let partialToken: String
    let type: String
    let tokenName: String?
    let lastSeen: String
    let lastSeenRemoteAddress: String
    let lastSeenUserAgent: String?

    var id: String { partialToken }
}

struct SessionsResponse: Decodable {
    let sessions: [Session]
}

// MARK: - Cluster

struct ClusterNode: Decodable, Identifiable {
    let id: Int
    let name: String
    let url: String
    let ipAddresses: [String]?
    let type: String
    let state: String
    let upSince: String?
    let lastSeen: String?
    let configLastSynced: String?
}

struct ClusterStateResponse: Decodable {
    let clusterInitialized: Bool?
    let clusterDomain: String?
    let clusterNodes: [ClusterNode]?
}

// MARK: - DNS Client

struct DnsResolveResponse: Decodable {
    // Direct properties from the response (PascalCase in API)
    let Metadata: DnsMetadata?
    let Identifier: Int?
    let IsResponse: Bool?
    let OPCODE: String?
    let AuthoritativeAnswer: Bool?
    let Truncation: Bool?
    let RecursionDesired: Bool?
    let RecursionAvailable: Bool?
    let AuthenticData: Bool?
    let CheckingDisabled: Bool?
    let RCODE: String?
    let QDCOUNT: Int?
    let ANCOUNT: Int?
    let NSCOUNT: Int?
    let ARCOUNT: Int?
    let Question: [DnsQuestion]?
    let Answer: [DnsAnswer]?
    let Authority: [DnsAnswer]?
    let Additional: [DnsAnswer]?

    // Convenience accessors with cleaner names
    var rcode: String? { RCODE }
    var authoritative: Bool { AuthoritativeAnswer ?? false }
    var recursionAvailable: Bool { RecursionAvailable ?? false }
    var authenticData: Bool { AuthenticData ?? false }
    var answer: [DnsAnswer] { Answer ?? [] }
    var authority: [DnsAnswer] { Authority ?? [] }
    var additional: [DnsAnswer] { Additional ?? [] }
}

struct DnsMetadata: Decodable {
    let nameServer: String?
    let queryProtocol: String?
    let datagramSize: Int?
    let roundTripTime: String?

    enum CodingKeys: String, CodingKey {
        case nameServer = "NameServer"
        case queryProtocol = "Protocol"
        case datagramSize = "DatagramSize"
        case roundTripTime = "RoundTripTime"
    }
}

struct DnsQuestion: Decodable {
    let name: String
    let recordType: String
    let recordClass: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case recordType = "Type"
        case recordClass = "Class"
    }
}

struct DnsAnswer: Decodable {
    let name: String
    let recordType: String
    let recordClass: String
    let ttl: Int
    let rData: [String: AnyCodable]?
    let dnssecStatus: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case recordType = "Type"
        case recordClass = "Class"
        case ttl = "TTL"
        case rData = "RData"
        case dnssecStatus = "DnssecStatus"
    }
}

// MARK: - Profile

struct ProfileResponse: Decodable {
    let displayName: String?
    let username: String
    let sessionTimeoutSeconds: Int?
    let memberOfGroups: [String]?
    let sessions: [Session]?
}

struct TokenResponse: Decodable {
    let token: String
    let username: String
    let tokenName: String
}

struct TwoFactorInitResponse: Decodable {
    let qrCode: String
    let issuer: String
    let secretKey: String
}

// MARK: - Network Helper

struct NetworkDevice: Decodable, Identifiable {
    let ip: String
    let hostname: String?
    let customName: String?
    let mac: String?
    let vendor: String?
    let hostnameSource: String?
    let notes: String?
    let tags: [String]?
    let group: String?
    let icon: String?
    let firstSeen: String
    let lastSeen: String
    let lastUpdated: String
    let queryCount: Int?
    let favorite: Bool?

    var id: String { ip }
}

struct NetworkDevicesResponse: Decodable {
    let devices: [NetworkDevice]
}

struct NetworkDeviceResponse: Decodable {
    let device: NetworkDevice
}

// MARK: - Helpers

/// Type-erased Codable value for handling dynamic JSON
struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }
}

extension AnyCodable: CustomStringConvertible {
    var description: String {
        switch value {
        case let string as String:
            return string
        case let int as Int:
            return String(int)
        case let double as Double:
            return String(double)
        case let bool as Bool:
            return bool ? "true" : "false"
        case let array as [Any]:
            return array.map { "\($0)" }.joined(separator: ", ")
        case let dict as [String: Any]:
            return dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        case is NSNull:
            return "null"
        default:
            return String(describing: value)
        }
    }
}

// MARK: - Zone Permissions

struct ZonePermissionsResponse: Decodable {
    let userPermissions: String?
    let groupPermissions: String?
}

struct ZonePermission: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var canView: Bool
    var canModify: Bool
    var canDelete: Bool

    static func parse(_ permString: String?) -> [ZonePermission] {
        guard let permString, !permString.isEmpty else { return [] }
        let parts = permString.split(separator: "|").map(String.init)
        var permissions: [ZonePermission] = []

        var i = 0
        while i + 3 < parts.count {
            permissions.append(ZonePermission(
                name: parts[i],
                canView: parts[i + 1] == "true",
                canModify: parts[i + 2] == "true",
                canDelete: parts[i + 3] == "true"
            ))
            i += 4
        }

        return permissions
    }

    static func format(_ permissions: [ZonePermission]) -> String {
        permissions.map { "\($0.name)|\($0.canView)|\($0.canModify)|\($0.canDelete)" }.joined(separator: "|")
    }
}
