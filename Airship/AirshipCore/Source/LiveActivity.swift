/* Copyright Airship and Contributors */

import Foundation

/// LiveActivity protocol. Makes everything testable.
protocol LiveActivityProtocol: Sendable {
    /// The activity's ID
    var id: String { get }

    var isUpdatable: Bool { get }

    var pushTokenString: String? { get }

    /// Awaits for the activity to be finished.
    /// - Parameters:
    ///     - tokenUpdates: A closure that is called whenever the token changes
    func track(tokenUpdates: @Sendable @escaping (String) async -> Void) async
}


#if canImport(ActivityKit)

import ActivityKit

@available(iOS 16.1, *)
fileprivate struct ActivityProvider<T : ActivityAttributes>: Sendable {
    public let id: String

    func getActivity() -> Activity<T>? {
        Activity<T>.activities.first { activity in
            activity.id == id
        }
    }
}


@available(iOS 16.1, *)
struct LiveActivity<T: ActivityAttributes>: LiveActivityProtocol {
    public let id: String

    public var isUpdatable: Bool {
        return provider.getActivity()?.activityState.isStaleOrActive ?? false
    }

    public var pushTokenString: String? {
        return provider.getActivity()?.pushToken?.tokenString
    }


    fileprivate let provider: ActivityProvider<T>

    init(activity: Activity<T>) {
        self.id = activity.id
        self.provider = ActivityProvider(id: activity.id)
    }

    /// Awaits for the activity to be finished.
    /// - Parameters:
    ///     - tokenUpdates: A closure that is called whenever the token changes
    func track(tokenUpdates: @Sendable @escaping (String) async -> Void) async {
        guard let activity = provider.getActivity(),
              activity.activityState == .active
        else {
            return
        }

        // Use a background task to wait for the first token update
        let backgroundTask = await AirshipBackgroundTask(
            name: "live_activity: \(self.id)",
            expiry: 30.0
        )

        let task = Task {
            guard let activity = provider.getActivity(),
                  activity.activityState.isStaleOrActive
            else {
                return
            }

            for await token in activity.pushTokenUpdates {
                if Task.isCancelled {
                    await backgroundTask.stop()
                    try Task.checkCancellation()
                }

                await tokenUpdates(token.tokenString)
                await backgroundTask.stop()
            }
        }

        /// If the push token is already created it does not cause an update above,
        /// so we will call the tokenUpdate callback directly if we have a token.
        if let token = activity.pushToken {
            await tokenUpdates(token.tokenString)
            await backgroundTask.stop()
        }

        for await update in activity.activityStateUpdates {
            if !update.isStaleOrActive || Task.isCancelled {
                await backgroundTask.stop()
                task.cancel()
                break
            }
        }
    }
}

@available(iOS 16.1, *)
extension ActivityState {
    public var isStaleOrActive: Bool {
        if #available(iOS 16.2, *) {
            return self == .active || self == .stale
        } else {
            return self == .active
        }
    }
}


extension Data {
    fileprivate var tokenString: String {
        AirshipUtils.deviceTokenStringFromDeviceToken(self)
    }
}


@MainActor
@available(iOS 16.1, *)
fileprivate class AirshipBackgroundTask {

    private var taskID = UIBackgroundTaskIdentifier.invalid

    private let name: String

    init(name: String, expiry: TimeInterval) {
        self.name = name

        taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            self.stop()
        }

        if (taskID != UIBackgroundTaskIdentifier.invalid) {
            AirshipLogger.trace("Background task started: \(name)")

            Task {
                try await Task.sleep(
                    nanoseconds: UInt64(expiry * 1_000_000_000)
                )
                self.stop()
            }
        }
    }

    func stop() {
        if (taskID != UIBackgroundTaskIdentifier.invalid) {
            UIApplication.shared.endBackgroundTask(taskID)
            AirshipLogger.trace("Background task ended: \(name)")
        }

        taskID = UIBackgroundTaskIdentifier.invalid
    }
}

#endif
