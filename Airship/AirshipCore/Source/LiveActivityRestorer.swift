#if canImport(ActivityKit)
import ActivityKit

/// Restores live activity tracking
@available(iOS 16.1, *)
public protocol LiveActivityRestorer: Actor {
    /// Should be called for every live activity type that you track with Airship.
    /// This method will  track a push to start token for the activity and check if any previousl
    /// tracked live activities are still available by comparing the activity's ID. If we previously tracked
    /// the activity, Airship will resume tracking the status and push token.
    /// - Parameters:
    ///     - forType: The live activity type
    func restore<T: ActivityAttributes>(forType: Activity<T>.Type) async
    
}

@available(iOS 16.1, *)
actor AirshipLiveActivityRestorer: LiveActivityRestorer {

    var liveActivities: [LiveActivityProtocol] = []
    var pushToStartTokenTrackers: [LiveActivityPushToStartTrackerProtocol] = []

    public func restore<T: ActivityAttributes>(
        forType: Activity<T>.Type
    ) {
        self.liveActivities.append(
            contentsOf: forType.activities.map { LiveActivity(activity: $0) }
        )

        if #available(iOS 17.2, *) {
            self.pushToStartTokenTrackers.append(
                LiveActivityPushToStartTracker<T>()
            )
        }
    }

    func apply(registry: LiveActivityRegistry) async {
        await registry.restoreTracking(
            activities: liveActivities,
            startTokenTrackers: pushToStartTokenTrackers
        )
    }
}


#endif
