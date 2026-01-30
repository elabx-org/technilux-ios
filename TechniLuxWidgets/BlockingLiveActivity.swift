import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Blocking Live Activity Attributes

struct BlockingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isEnabled: Bool
        var disableEndTime: Date?
        var remainingMinutes: Int
    }

    var serverName: String
}

// MARK: - Live Activity Widget

@available(iOS 16.2, *)
struct BlockingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BlockingActivityAttributes.self) { context in
            // Lock Screen/Banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.state.isEnabled ? "shield.checkmark.fill" : "shield.slash.fill")
                            .foregroundColor(context.state.isEnabled ? .green : .orange)
                        Text(context.state.isEnabled ? "Active" : "Paused")
                            .font(.caption)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let endTime = context.state.disableEndTime, !context.state.isEnabled {
                        Text(endTime, style: .timer)
                            .font(.caption)
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text("DNS Blocking")
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if !context.state.isEnabled, let endTime = context.state.disableEndTime {
                        HStack {
                            ProgressView(
                                timerInterval: Date()...endTime,
                                countsDown: true
                            ) {
                                Text("Resuming in")
                            }
                            .tint(.orange)
                        }
                        .padding(.horizontal)
                    } else {
                        Text("All DNS queries are being filtered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isEnabled ? "shield.checkmark.fill" : "shield.slash.fill")
                    .foregroundColor(context.state.isEnabled ? .green : .orange)
            } compactTrailing: {
                if !context.state.isEnabled, let endTime = context.state.disableEndTime {
                    Text(endTime, style: .timer)
                        .font(.caption)
                        .monospacedDigit()
                } else {
                    Text(context.state.isEnabled ? "On" : "Off")
                        .font(.caption)
                }
            } minimal: {
                Image(systemName: context.state.isEnabled ? "shield.checkmark.fill" : "shield.slash.fill")
                    .foregroundColor(context.state.isEnabled ? .green : .orange)
            }
            .widgetURL(URL(string: "technilux://blocking"))
        }
    }
}

@available(iOS 16.2, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BlockingActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(context.state.isEnabled ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: context.state.isEnabled ? "shield.checkmark.fill" : "shield.slash.fill")
                    .font(.title2)
                    .foregroundColor(context.state.isEnabled ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("DNS Blocking")
                    .font(.headline)

                if context.state.isEnabled {
                    Text("All queries are being filtered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let endTime = context.state.disableEndTime {
                    HStack {
                        Text("Temporarily disabled")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("Resumes in ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(endTime, style: .timer)
                            .font(.caption)
                            .monospacedDigit()
                    }
                } else {
                    Text("Blocking is disabled")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            if !context.state.isEnabled, let endTime = context.state.disableEndTime {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 4)
                        .frame(width: 40, height: 40)

                    Text("\(context.state.remainingMinutes)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
    }
}

// MARK: - Live Activity Manager

@available(iOS 16.2, *)
@MainActor
class BlockingActivityManager: ObservableObject {
    static let shared = BlockingActivityManager()

    @Published var currentActivity: Activity<BlockingActivityAttributes>?

    private init() {}

    func startActivity(serverName: String, isEnabled: Bool, disableEndTime: Date? = nil) {
        // End any existing activity
        endActivity()

        let attributes = BlockingActivityAttributes(serverName: serverName)
        let remainingMinutes = disableEndTime.map { max(0, Int($0.timeIntervalSinceNow / 60)) } ?? 0

        let state = BlockingActivityAttributes.ContentState(
            isEnabled: isEnabled,
            disableEndTime: disableEndTime,
            remainingMinutes: remainingMinutes
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: disableEndTime),
                pushType: nil
            )
            currentActivity = activity
            print("Started blocking Live Activity: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateActivity(isEnabled: Bool, disableEndTime: Date? = nil) {
        guard let activity = currentActivity else { return }

        let remainingMinutes = disableEndTime.map { max(0, Int($0.timeIntervalSinceNow / 60)) } ?? 0

        let state = BlockingActivityAttributes.ContentState(
            isEnabled: isEnabled,
            disableEndTime: disableEndTime,
            remainingMinutes: remainingMinutes
        )

        Task {
            await activity.update(.init(state: state, staleDate: disableEndTime))
        }
    }

    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}
