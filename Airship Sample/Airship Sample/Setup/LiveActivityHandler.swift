/* Copyright Airship and Contributors */

import AirshipCore
import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Example Live Activity integration handler.
///
/// This is a sample implementation showing how to integrate iOS Live Activities
/// with Airship.
///
/// - Note: This is an example - customize for your app's needs.
struct LiveActivityHandler {

    /// Sets up example Live Activity integration.
    static func setup() {

#if canImport(ActivityKit)

        // Restores live activity tracking
        Airship.channel.restoreLiveActivityTracking { restorer in
            // Call this for every type of Live Activity that you want
            // to update through Airship
            await restorer.restore(
                forType: Activity<DeliveryAttributes>.self
            )
        }

        // Important for APNS started Live Activties. Watch for any actvities and makes sure
        // they are tracked on Airship. This will get called for all activities that are started
        // whenever a new live activity is started and on first invoke.
        Activity<DeliveryAttributes>.airshipWatchActivities { activity in
            // Track the live activity with Airship with the order number as the name
            Airship.channel.trackLiveActivity(activity, name: activity.attributes.orderNumber)
        }

#endif
    }
}
