# TechniLux iOS

Native iOS app for managing [Technitium DNS Server](https://technitium.com/dns/). Built with SwiftUI for iOS 18+.

## Features

- **Dashboard** - Real-time stats, charts, and top lists
- **Zones** - Full zone and record management with DNSSEC
- **Blocking** - Allowed/blocked domains and block lists
- **Cache** - Browse, flush, and prefetch DNS cache
- **DHCP** - Scope and lease management
- **Apps** - Install and configure DNS apps
- **Logs** - Query logs with filtering
- **Settings** - Complete server configuration
- **Admin** - Users, groups, sessions, and cluster management
- **Network** - Device discovery (requires Network Helper)
- **DNS Client** - Query tool with protocol selection

## Installation

TechniLux iOS is distributed as an unsigned IPA. You'll need to sign it with your Apple ID using [Feather](https://github.com/khcrysalis/Feather).

### Steps

1. Download the latest `.ipa` from [Releases](https://github.com/elabx-org/technilux-ios/releases)
2. Install [Feather](https://github.com/khcrysalis/Feather) on your iOS device
3. Import the IPA into Feather
4. Sign with your Apple ID
5. Install and launch

### Requirements

- iOS 18.0 or later
- iPhone or iPad
- Apple ID (for signing)

## Connecting to Your Server

1. Open TechniLux
2. Enter your Technitium server URL (e.g., `http://10.0.0.1:5380`)
3. Log in with your credentials

### HTTPS/Remote Access

For remote access over the internet:
- Enable HTTPS on your Technitium server
- Use a reverse proxy (Caddy, nginx) with valid SSL certificate
- Or use VPN to access your local network

## Building from Source

### Prerequisites

- Xcode 16.0+
- iOS 18 SDK

### Build

```bash
# Clone the repository
git clone https://github.com/elabx-org/technilux-ios.git
cd technilux-ios

# Open in Xcode
open TechniLux.xcodeproj

# Or build from command line
xcodebuild -project TechniLux.xcodeproj \
  -scheme TechniLux \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO build
```

## Architecture

The app follows MVVM architecture with SwiftUI:

- **Core/API** - `TechnitiumClient` for all API calls
- **Core/Models** - Codable data models
- **Core/Services** - Auth, Keychain, Cluster management
- **Features/** - 14 feature modules, each with View + ViewModel
- **Shared/** - Reusable UI components and styles

## Related Projects

- [TechniLux Web UI](https://github.com/elabx-org/technilux) - Modern web interface
- [TechniLux Apps](https://github.com/elabx-org/technilux-apps) - Custom DNS apps
- [Technitium DNS Server](https://github.com/TechnitiumSoftware/DnsServer) - The DNS server

## License

MIT License - see [LICENSE](LICENSE)
