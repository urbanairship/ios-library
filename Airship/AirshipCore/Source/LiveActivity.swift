/* Copyright Airship and Contributors */

import Foundation

/// LiveActivity protocol. Makes everything testable.
protocol LiveActivity {
    /// The activity's ID
    var id: String { get }

    /// If the activity is active or not
    var isActive: Bool { get }

    /// Push token
    var pushTokenString: String? { get }

    /// Awaits for the activity to be finished.
    /// - Parameters:
    ///     - tokenUpdates: A closure that is called whenever the token changes
    func track(tokenUpdates: @escaping (String) async -> Void) async
}

#if canImport(ActivityKit)

import ActivityKit

@available(iOS 16.1, *)
extension Activity: LiveActivity {
    func track(tokenUpdates: @escaping (String) async -> Void) async {

        guard self.activityState == .active else {
            return
        }

        // Use a background task to wait for the first token update
        let backgroundTask = await AirshipBackgroundTask(
            name: "live_activity: \(self.id)",
            expiry: 10.0
        )

        let task = Task {
            for await token in self.pushTokenUpdates {
                if Task.isCancelled {
                    await backgroundTask.stop()
                    try Task.checkCancellation()
                }

                await tokenUpdates(token.tokenString)
                await backgroundTask.stop()
            }
        }

        /// If the push token is already created it does not cause an update above,
        /// so we will call the tokenUpdate callback direclty if we have a token.
        if let token = self.pushToken {
            await tokenUpdates(token.tokenString)
            await backgroundTask.stop()
        }

        for await update in self.activityStateUpdates {
            if update != .active || Task.isCancelled {
                await backgroundTask.stop()
                task.cancel()
                break
            }
        }
    }

    var isActive: Bool {
        return self.activityState == .active
    }

    var pushTokenString: String? {
        return self.pushToken?.tokenString
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
