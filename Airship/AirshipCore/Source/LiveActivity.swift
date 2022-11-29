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

        let task = Task {
            for await token in self.pushTokenUpdates {
                try Task.checkCancellation()
                await tokenUpdates(token.tokenString)
            }
        }

        /// If the push token is already created it does not cause an update above,
        /// so we will call the tokenUpdate callback direclty if we have a token.
        if let token = self.pushToken {
            await tokenUpdates(token.tokenString)
        }

        for await update in self.activityStateUpdates {
            if update != .active || Task.isCancelled {
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
        Utils.deviceTokenStringFromDeviceToken(self)
    }
}

#endif
