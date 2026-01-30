import SwiftUI

/// Color palette matching the TechniLux web UI
/// Note: techniluxPrimary and techniluxAccent are auto-generated from Assets.xcassets
extension Color {
    // MARK: - Semantic Colors

    /// Success green - HSB(142, 71%, 45%)
    static let techniluxSuccess = Color(hue: 142/360, saturation: 0.71, brightness: 0.45)

    /// Warning orange - HSB(38, 92%, 50%)
    static let techniluxWarning = Color(hue: 38/360, saturation: 0.92, brightness: 0.50)

    /// Destructive red - HSB(0, 72%, 51%)
    static let techniluxDestructive = Color(hue: 0, saturation: 0.72, brightness: 0.51)

    /// Info blue - HSB(199, 89%, 48%)
    static let techniluxInfo = Color(hue: 199/360, saturation: 0.89, brightness: 0.48)
}

/// Color scheme definitions for asset catalog
enum TechniluxColors {
    /// Primary teal - use in Assets.xcassets
    static let primaryLight = Color(hue: 173/360, saturation: 0.58, brightness: 0.39)
    static let primaryDark = Color(hue: 173/360, saturation: 0.58, brightness: 0.50)

    /// Accent teal - lighter variant
    static let accentLight = Color(hue: 173/360, saturation: 0.40, brightness: 0.92)
    static let accentDark = Color(hue: 173/360, saturation: 0.35, brightness: 0.18)

    /// Background colors
    static let backgroundLight = Color(hue: 210/360, saturation: 0.20, brightness: 0.98)
    static let backgroundDark = Color(hue: 222/360, saturation: 0.47, brightness: 0.08)

    /// Card colors
    static let cardLight = Color.white
    static let cardDark = Color(hue: 222/360, saturation: 0.40, brightness: 0.11)
}

// MARK: - Gradient Definitions

extension LinearGradient {
    /// Primary gradient for headers and highlights
    static let techniluxPrimaryGradient = LinearGradient(
        colors: [
            Color(hue: 173/360, saturation: 0.58, brightness: 0.45),
            Color(hue: 173/360, saturation: 0.58, brightness: 0.35)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle background gradient
    static let techniluxBackground = LinearGradient(
        colors: [
            Color(UIColor.systemBackground),
            Color(UIColor.systemBackground).opacity(0.95)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
