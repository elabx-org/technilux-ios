import SwiftUI

/// iOS 26 Liquid Glass UI style modifiers
extension View {
    /// Apply liquid glass card styling with depth and refraction
    func glassCard() -> some View {
        self
            .background(.glass)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    /// Apply glass card with subtle border highlight
    func glassCardWithBorder() -> some View {
        self
            .background(.glass)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    /// Apply glass button styling
    func glassButton() -> some View {
        self
            .background(.glass)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Apply subtle glass background for inputs
    func glassBackground() -> some View {
        self
            .background(.glass.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Apply prominent glass effect for hero elements
    func glassHero() -> some View {
        self
            .background(.glass)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Custom Button Styles

/// iOS 26 Liquid Glass button style
struct GlassButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                isDestructive
                    ? Color.techniluxDestructive.opacity(configuration.isPressed ? 0.8 : 1)
                    : Color.techniluxPrimary.opacity(configuration.isPressed ? 0.8 : 1)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Outlined glass button style
struct OutlinedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.glass.opacity(0.8))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
    static var glassDestructive: GlassButtonStyle { GlassButtonStyle(isDestructive: true) }
}

extension ButtonStyle where Self == OutlinedButtonStyle {
    static var outlined: OutlinedButtonStyle { OutlinedButtonStyle() }
}

// MARK: - Status Badge Styles

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.25), lineWidth: 0.5)
            )
    }
}

// MARK: - Loading Indicator

struct GlassLoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(.techniluxPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .glassCard()
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var action: (() -> Void)?
    var actionTitle: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let action, let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.glass)
                    .padding(.top, 8)
            }
        }
        .padding(40)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
