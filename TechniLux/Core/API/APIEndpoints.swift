import Foundation

/// API endpoint definitions
enum APIEndpoint {
    // Authentication
    case login
    case logout
    case sessionGet

    // User Profile
    case profileGet
    case profileSet
    case changePassword
    case createToken
    case twoFactorInit
    case twoFactorEnable
    case twoFactorDisable

    // Dashboard
    case dashboardStats
    case dashboardTopStats

    // Zones
    case zonesList
    case zonesCreate
    case zonesDelete
    case zonesEnable
    case zonesDisable
    case zonesClone
    case zonesConvert
    case zonesOptionsGet
    case zonesOptionsSet
    case zonesExport
    case zonesImport
    case zonesResync

    // DNSSEC
    case dnssecSign
    case dnssecUnsign
    case dnssecPropertiesGet
    case dnssecPropertiesSet
    case dnssecKeysGet
    case dnssecKeysRollover
    case dnssecKeysRetire

    // Records
    case recordsGet
    case recordsAdd
    case recordsUpdate
    case recordsDelete

    // Blocking
    case blockedList
    case blockedAdd
    case blockedDelete
    case blockedExport
    case blockedImport
    case blockedIsBlocked
    case allowedList
    case allowedAdd
    case allowedDelete
    case allowedExport
    case allowedImport

    // Cache
    case cacheList
    case cacheDelete
    case cacheFlush
    case cachePrefetch

    // Logs
    case logsQuery
    case logsList
    case logsDownload
    case logsDelete
    case logsDeleteAll

    // DHCP
    case dhcpScopesList
    case dhcpScopesGet
    case dhcpScopesSet
    case dhcpScopesDelete
    case dhcpScopesEnable
    case dhcpScopesDisable
    case dhcpLeasesList
    case dhcpLeasesRemove

    // Apps
    case appsList
    case appsListStore
    case appsDownload
    case appsUpdate
    case appsUninstall
    case appsConfigGet
    case appsConfigSet

    // Settings
    case settingsGet
    case settingsSet
    case settingsForceUpdateBlockLists
    case settingsTemporaryDisableBlocking
    case settingsBackup
    case settingsRestore
    case settingsCheckForUpdate

    // Admin - Users
    case usersList
    case usersCreate
    case usersDelete
    case usersGet
    case usersSet
    case usersEnable
    case usersDisable
    case usersSetPassword

    // Admin - Groups
    case groupsList
    case groupsCreate
    case groupsDelete
    case groupsGet
    case groupsSet

    // Admin - Sessions
    case sessionsList
    case sessionsDelete

    // Admin - Cluster
    case clusterState
    case clusterInit
    case clusterJoin
    case clusterDelete
    case clusterRemoveSecondary
    case clusterDeleteSecondary
    case clusterLeave
    case clusterPromote
    case clusterResync
    case clusterSetOptions
    case clusterUpdateIpAddress
    case clusterUpdatePrimary

    // DNS Client
    case dnsClientResolve
    case dnsClientFlushCache

    // Network Helper
    case networkDevices
    case networkDeviceGet
    case networkDeviceSave
    case networkDeviceDelete
    case networkDevicesBulk
    case networkStats
    case networkSettings
    case networkSettingsSave
    case networkCleanup
    case networkExport

    // Zone Permissions
    case zonePermissionsGet
    case zonePermissionsSet

    var path: String {
        switch self {
        // Authentication
        case .login: return "/user/login"
        case .logout: return "/user/logout"
        case .sessionGet: return "/user/session/get"

        // User Profile
        case .profileGet: return "/user/profile/get"
        case .profileSet: return "/user/profile/set"
        case .changePassword: return "/user/changePassword"
        case .createToken: return "/user/createToken"
        case .twoFactorInit: return "/user/2fa/init"
        case .twoFactorEnable: return "/user/2fa/enable"
        case .twoFactorDisable: return "/user/2fa/disable"

        // Dashboard
        case .dashboardStats: return "/dashboard/stats/get"
        case .dashboardTopStats: return "/dashboard/stats/getTop"

        // Zones
        case .zonesList: return "/zones/list"
        case .zonesCreate: return "/zones/create"
        case .zonesDelete: return "/zones/delete"
        case .zonesEnable: return "/zones/enable"
        case .zonesDisable: return "/zones/disable"
        case .zonesClone: return "/zones/clone"
        case .zonesConvert: return "/zones/convert"
        case .zonesOptionsGet: return "/zones/options/get"
        case .zonesOptionsSet: return "/zones/options/set"
        case .zonesExport: return "/zones/export"
        case .zonesImport: return "/zones/import"
        case .zonesResync: return "/zones/resync"

        // DNSSEC
        case .dnssecSign: return "/zones/dnssec/sign"
        case .dnssecUnsign: return "/zones/dnssec/unsign"
        case .dnssecPropertiesGet: return "/zones/dnssec/properties/get"
        case .dnssecPropertiesSet: return "/zones/dnssec/properties/set"
        case .dnssecKeysGet: return "/zones/dnssec/keys/get"
        case .dnssecKeysRollover: return "/zones/dnssec/keys/rollover"
        case .dnssecKeysRetire: return "/zones/dnssec/keys/retire"

        // Records
        case .recordsGet: return "/zones/records/get"
        case .recordsAdd: return "/zones/records/add"
        case .recordsUpdate: return "/zones/records/update"
        case .recordsDelete: return "/zones/records/delete"

        // Blocking
        case .blockedList: return "/blocked/list"
        case .blockedAdd: return "/blocked/add"
        case .blockedDelete: return "/blocked/delete"
        case .blockedExport: return "/blocked/export"
        case .blockedImport: return "/blocked/import"
        case .blockedIsBlocked: return "/blocked/isBlocked"
        case .allowedList: return "/allowed/list"
        case .allowedAdd: return "/allowed/add"
        case .allowedDelete: return "/allowed/delete"
        case .allowedExport: return "/allowed/export"
        case .allowedImport: return "/allowed/import"

        // Cache
        case .cacheList: return "/cache/list"
        case .cacheDelete: return "/cache/delete"
        case .cacheFlush: return "/cache/flush"
        case .cachePrefetch: return "/cache/prefetch"

        // Logs
        case .logsQuery: return "/logs/query"
        case .logsList: return "/logs/list"
        case .logsDownload: return "/logs/download"
        case .logsDelete: return "/logs/delete"
        case .logsDeleteAll: return "/logs/deleteAll"

        // DHCP
        case .dhcpScopesList: return "/dhcp/scopes/list"
        case .dhcpScopesGet: return "/dhcp/scopes/get"
        case .dhcpScopesSet: return "/dhcp/scopes/set"
        case .dhcpScopesDelete: return "/dhcp/scopes/delete"
        case .dhcpScopesEnable: return "/dhcp/scopes/enable"
        case .dhcpScopesDisable: return "/dhcp/scopes/disable"
        case .dhcpLeasesList: return "/dhcp/leases/list"
        case .dhcpLeasesRemove: return "/dhcp/leases/remove"

        // Apps
        case .appsList: return "/apps/list"
        case .appsListStore: return "/apps/listStoreApps"
        case .appsDownload: return "/apps/downloadAndInstall"
        case .appsUpdate: return "/apps/downloadAndUpdate"
        case .appsUninstall: return "/apps/uninstall"
        case .appsConfigGet: return "/apps/config/get"
        case .appsConfigSet: return "/apps/config/set"

        // Settings
        case .settingsGet: return "/settings/get"
        case .settingsSet: return "/settings/set"
        case .settingsForceUpdateBlockLists: return "/settings/forceUpdateBlockLists"
        case .settingsTemporaryDisableBlocking: return "/settings/temporaryDisableBlocking"
        case .settingsBackup: return "/settings/backup"
        case .settingsRestore: return "/settings/restore"
        case .settingsCheckForUpdate: return "/settings/checkForUpdate"

        // Admin - Users
        case .usersList: return "/admin/users/list"
        case .usersCreate: return "/admin/users/create"
        case .usersDelete: return "/admin/users/delete"
        case .usersGet: return "/admin/users/get"
        case .usersSet: return "/admin/users/set"
        case .usersEnable: return "/admin/users/enable"
        case .usersDisable: return "/admin/users/disable"
        case .usersSetPassword: return "/admin/users/setPassword"

        // Admin - Groups
        case .groupsList: return "/admin/groups/list"
        case .groupsCreate: return "/admin/groups/create"
        case .groupsDelete: return "/admin/groups/delete"
        case .groupsGet: return "/admin/groups/get"
        case .groupsSet: return "/admin/groups/set"

        // Admin - Sessions
        case .sessionsList: return "/admin/sessions/list"
        case .sessionsDelete: return "/admin/sessions/delete"

        // Admin - Cluster
        case .clusterState: return "/admin/cluster/state"
        case .clusterInit: return "/admin/cluster/init"
        case .clusterJoin: return "/admin/cluster/initJoin"
        case .clusterDelete: return "/admin/cluster/primary/delete"
        case .clusterRemoveSecondary: return "/admin/cluster/primary/removeSecondary"
        case .clusterDeleteSecondary: return "/admin/cluster/primary/deleteSecondary"
        case .clusterLeave: return "/admin/cluster/secondary/leave"
        case .clusterPromote: return "/admin/cluster/secondary/promote"
        case .clusterResync: return "/admin/cluster/secondary/resync"
        case .clusterSetOptions: return "/admin/cluster/primary/setOptions"
        case .clusterUpdateIpAddress: return "/admin/cluster/updateIpAddress"
        case .clusterUpdatePrimary: return "/admin/cluster/secondary/updatePrimary"

        // DNS Client
        case .dnsClientResolve: return "/dnsClient/resolve"
        case .dnsClientFlushCache: return "/dnsClient/flushCache"

        // Network Helper
        case .networkDevices: return "/network/devices"
        case .networkDeviceGet: return "/network/devices/get"
        case .networkDeviceSave: return "/network/devices"
        case .networkDeviceDelete: return "/network/devices"
        case .networkDevicesBulk: return "/network/devices/bulk"
        case .networkStats: return "/network/stats"
        case .networkSettings: return "/network/settings"
        case .networkSettingsSave: return "/network/settings"
        case .networkCleanup: return "/network/cleanup"
        case .networkExport: return "/network/export"

        // Zone Permissions
        case .zonePermissionsGet: return "/zones/permissions/get"
        case .zonePermissionsSet: return "/zones/permissions/set"
        }
    }
}
