# CLAUDE.md - TechniLux iOS

This file provides guidance to Claude Code when working with the TechniLux iOS app.

## Project Overview

**TechniLux iOS** - Native iOS app for managing Technitium DNS Server. Built with SwiftUI targeting iOS 18+, using iOS 26 glass UI design language.

## Repository

- **This repo:** `github.com/elabx-org/technilux-ios`
- **Reference repo:** `github.com/elabx-org/technilux` (web UI) - source of truth for API contract

## Build Commands

```bash
# Build unsigned IPA (GitHub Actions)
xcodebuild \
  -project TechniLux.xcodeproj \
  -scheme TechniLux \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

# Run tests
xcodebuild test \
  -project TechniLux.xcodeproj \
  -scheme TechniLux \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

```
TechniLux/
├── App/                    # App entry point
├── Core/
│   ├── API/                # TechnitiumClient, endpoints, response types
│   ├── Models/             # Codable data models
│   └── Services/           # Auth, Keychain, Cluster services
├── Features/               # 14 MVVM feature modules
│   ├── Dashboard/          # Stats, charts, top lists
│   ├── Zones/              # Zone list, records, DNSSEC
│   ├── Blocking/           # Allowed/blocked lists
│   ├── Cache/              # Tree browser, flush, prefetch
│   ├── DHCP/               # Scopes, leases, config
│   ├── Apps/               # App store, installed apps
│   ├── Logs/               # Query logs with filters
│   ├── Settings/           # 9 settings tabs
│   ├── Admin/              # Users, groups, sessions, cluster
│   ├── Network/            # Device discovery
│   ├── DNSClient/          # Query tool
│   ├── Profile/            # Password, 2FA, tokens
│   ├── About/              # Version info
│   └── Authentication/     # Login flow
├── Shared/
│   ├── Components/         # GlassCard, GlassButton, ClusterNodePicker
│   ├── Styles/             # GlassStyle, ColorPalette
│   └── Navigation/         # MainTabView (iPhone), SidebarView (iPad)
└── Resources/              # Assets, Info.plist
```

## API Client Critical Notes

From the web UI's CLAUDE.md - must handle these quirks:

1. **Simple arrays = strings**: Send `["53", "5380"]` not `[53, 5380]`
2. **Object arrays = native JSON**: `tsigKeys` keeps numbers
3. **Field rename**: `proxyBypassList` → send as `proxyBypass`
4. **Settings POST**: Use JSON body with `Content-Type: application/json`
5. **Response wrapper**: `{ status: 'ok'|'error'|'invalid-token', response?: T }`

## Design System

### Colors (from web UI's app.css)
- **Primary teal**: HSB(173, 58%, 39%) light / HSB(173, 58%, 50%) dark
- **Background**: HSB(210, 20%, 98%) light / HSB(222, 47%, 8%) dark
- **Card**: White light / HSB(222, 40%, 11%) dark
- **Success**: HSB(142, 71%, 45%)
- **Warning**: HSB(38, 92%, 50%)
- **Destructive**: HSB(0, 72%, 51%)

### Glass UI Components
- Use `.ultraThinMaterial` for cards
- Use `.regularMaterial` for buttons
- 20pt corner radius
- Subtle shadows and border strokes

### Navigation
- **iPhone**: TabView (Dashboard, Zones, Blocking, More)
- **iPad**: NavigationSplitView with full sidebar

## Feature Implementation Pattern

Each feature follows MVVM:

```swift
// Model (in Core/Models/)
struct Zone: Codable, Identifiable {
    let name: String
    let type: ZoneType
    // ...
}

// ViewModel (in Features/Zones/)
@Observable
final class ZonesViewModel {
    var zones: [Zone] = []
    var isLoading = false
    var error: String?

    @MainActor
    func loadZones() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await TechnitiumClient.shared.listZones()
            zones = response.response?.zones ?? []
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// View (in Features/Zones/)
struct ZonesView: View {
    @State private var viewModel = ZonesViewModel()

    var body: some View {
        List(viewModel.zones) { zone in
            // ...
        }
        .task { await viewModel.loadZones() }
    }
}
```

## Cluster Support

Track selected node globally and pass to API calls:

```swift
// In ClusterService
@Observable
final class ClusterService {
    static let shared = ClusterService()
    var selectedNode: String?

    var nodeParam: String? {
        selectedNode
    }
}

// In API calls
func listZones(node: String? = nil) async throws -> ApiResponse<ZonesResponse> {
    var params: [String: String] = [:]
    if let node = node ?? ClusterService.shared.nodeParam {
        params["node"] = node
    }
    return try await request("/zones/list", params: params)
}
```

## Distribution

1. GitHub Actions builds unsigned IPA on push to main
2. Users download from GitHub Releases
3. Sign with Feather (on-device signing with Apple ID)
4. Install on device

## Testing

- Unit tests in `TechniLuxTests/`
- Test ViewModels with mock API responses
- Test API client encoding/decoding

## Versioning

Update version in `TechniLux/Resources/Info.plist`:
- `CFBundleShortVersionString`: Marketing version (e.g., "1.0.0")
- `CFBundleVersion`: Build number (e.g., "1")
