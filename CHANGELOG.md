# Changelog

All notable changes to TechniLux iOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-30

### Added

- Initial release of TechniLux iOS
- **Dashboard** - Real-time stats with auto-refresh, line/pie charts, top lists
- **Zones** - Full zone management with create, delete, enable/disable
- **Records** - View and manage DNS records for all zone types
- **Blocking** - Allowed/blocked domains, temporary disable with countdown
- **Cache** - Tree browser with flush and prefetch
- **DHCP** - Scopes and leases management
- **Apps** - App store browser and installed apps management
- **Logs** - Query logs with pagination and filters
- **Settings** - Read-only settings view with sections
- **Admin** - Users, groups, sessions, and cluster management
- **Network** - Device discovery via Network Helper
- **DNS Client** - Query tool with protocol selection
- **Profile** - Password change, 2FA management
- **About** - Version info and links

### Features

- iOS 18+ with SwiftUI
- iOS 26 glass UI design language
- Secure keychain storage for credentials
- Cluster support with node selector
- Adaptive navigation (TabView for iPhone, Sidebar for iPad)
- Pull-to-refresh on all data views
- Unsigned IPA distribution via Feather

### API

- Full Technitium DNS Server API support (60+ endpoints)
- JSON POST for settings (per API quirks)
- Cluster node parameter support
