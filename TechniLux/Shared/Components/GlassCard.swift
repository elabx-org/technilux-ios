import SwiftUI

/// Glass-style card container
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .glassCardWithBorder()
    }
}

/// Stat card with icon, value, and label
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .techniluxPrimary
    var trend: Double?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)

                    Spacer()

                    if let trend {
                        TrendIndicator(value: trend)
                    }
                }

                Spacer()

                Text(value)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 120)
    }
}

/// Trend indicator showing up/down arrow with percentage
struct TrendIndicator: View {
    let value: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption)
            Text("\(abs(value), specifier: "%.1f")%")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(value >= 0 ? .green : .red)
    }
}

/// Action card with icon and title
struct ActionCard: View {
    let icon: String
    let title: String
    var subtitle: String?
    var color: Color = .techniluxPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Info row for displaying key-value pairs
struct InfoRow: View {
    let label: String
    let value: String
    var icon: String?

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Stat Card") {
    StatCard(
        icon: "magnifyingglass",
        value: "12,345",
        label: "Total Queries",
        trend: 5.2
    )
    .padding()
}

#Preview("Action Card") {
    ActionCard(
        icon: "plus.circle.fill",
        title: "Add Zone",
        subtitle: "Create a new DNS zone"
    ) {}
    .padding()
}
