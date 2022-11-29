#if canImport(ActivityKit)
import ActivityKit

/// Restores live activity tracking
@available(iOS 16.1, *)
public protocol LiveActivityRestorer {
    /// Should be called for every live activity type that you track with Airship.
    /// This method will check if any previously tracked live activities are still available by comparing
    /// the activity's ID. If we previously tracked the activity, Airship will resume tracking the status
    /// and push token.
    /// - Parameters:
    ///     - forType: The live activity type
    func restore<T: ActivityAttributes>(forType: Activity<T>.Type) async
}

@available(iOS 16.1, *)
class AirshipLiveActivityRestorer: LiveActivityRestorer {
    let registry: LiveActivityRegistry

    init(registry: LiveActivityRegistry) {
        self.registry = registry
    }

    public func restore<T: ActivityAttributes>(forType: Activity<T>.Type)
        async
    {
        await self.registry.restoreTracking(activities: forType.activities)
    }
}
#endif
