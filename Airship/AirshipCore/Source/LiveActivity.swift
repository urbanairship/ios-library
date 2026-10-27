/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

#if canImport(UIKit)
import UIKit
#endif


/// LiveActivity protocol. Makes everything testable.
protocol LiveActivityPushToStartTrackerProtocol: Sendable {
    var attributeType: String { get }
    func track(tokenUpdates: @Sendable @escaping (String) async -> Void) async
}

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


#if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && !os(macOS)

public import ActivityKit

@available(iOS 17.2, *)
struct LiveActivityPushToStartTracker<T: ActivityAttributes>: LiveActivityPushToStartTrackerProtocol {
    var attributeType: String {
        return String(describing: T.self)
    }


    func track(tokenUpdates: @escaping @Sendable (String) async -> Void) async {
        var tokenString: String? = Activity<T>.pushToStartToken?.tokenString

        if let tokenString = tokenString {
            await tokenUpdates(tokenString)
        }

        for await token in Activity<T>.pushToStartTokenUpdates {
            if Task.isCancelled {
               break
            }

            let newTokenString = token.tokenString
            if tokenString != newTokenString {
                tokenString = newTokenString
                await tokenUpdates(newTokenString)
            }
        }
    }
}


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
              activity.activityState.isStaleOrActive
        else {
            return
        }

        // Use a background task to wait for the first token update
        let backgroundTask = await AirshipBackgroundTask(
            name: "live_activity: \(self.id)",
            expiry: 30.0
        )

        let task = Task {
            // This nested function is a workaround for a Swift compiler Sendable warning.
            // It avoids the Task's @Sendable closure from directly capturing the generic type.
            func run() async throws {
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

            try await run()
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
fileprivate final class AirshipBackgroundTask {

    private var taskID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

    private let name: String

    init(name: String, expiry: TimeInterval) {
        self.name = name

        taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            Task { @MainActor [weak self = self] in
                self?.stop()
            }
        }

        if (taskID != UIBackgroundTaskIdentifier.invalid) {
            AirshipLogger.trace("Background task started: \(name)")

            Task {
                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(expiry * 1_000_000_000)
                    )
                    self.stop()
                } catch {
                    AirshipLogger.error("Background task expiry sleep failed: \(error)")
                }
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

@available(iOS 16.1, *)
extension Activity where Attributes : ActivityAttributes {

    /// Calls `activityBlock` once for every active activity on the first call, and once for each new activity afterwards.
    /// A scheduled activity is passed once it becomes active.
    /// - Parameters:
    ///     - activityBlock: Block that is called with the activity
    public class func airshipWatchActivities(
        activityBlock: @escaping @Sendable (Activity<Attributes>) -> Void
    ) {
        Task {
            // This nested function is a workaround for a Swift compiler Sendable warning.
            // It avoids the Task's @Sendable closure from directly capturing the generic type.
            func run() async {
                let handledIDs = AirshipAtomicValue<Set<String>>([])
                let markHandled: @Sendable (String) -> Bool = { id in
                    var isNew = false
                    handledIDs.update { ids in
                        isNew = ids.insert(id).inserted
                    }
                    return isNew
                }

                func handle(_ activity: Activity<Attributes>) {
                    if markHandled(activity.id) {
                        activityBlock(activity)
                    }
                }

                func consider(_ activity: Activity<Attributes>) {
                    let state = activity.activityState
                    if state.isStaleOrActive {
                        handle(activity)
                    } else if state != .ended && state != .dismissed {
                        // A scheduled activity is not active until its start date.
                        let provider = ActivityProvider<Attributes>(id: activity.id)
                        Task {
                            func run() async {
                                guard let activity = provider.getActivity() else { return }
                                for await state in activity.activityStateUpdates {
                                    if state.isStaleOrActive {
                                        if markHandled(activity.id) {
                                            activityBlock(activity)
                                        }
                                        return
                                    }
                                    if state == .ended || state == .dismissed {
                                        return
                                    }
                                }
                            }
                            await run()
                        }
                    }
                }

                Activity<Attributes>.activities.forEach(consider)

                // Not `pushToStartTokenUpdates`, which `LiveActivityPushToStartTracker` already iterates.
                for await activity in Activity<Attributes>.activityUpdates {
                    consider(activity)
                }
            }
            await run()
        }
    }

    /// Calls `activityBlock` once for every active activity on the first call, and once for each new activity afterwards.
    /// - Parameters:
    ///     - unique: Ignored. `activityBlock` is always called at most once per Live Activity, so `false` no longer
    ///     calls it again for an activity it has already received.
    ///     - activityBlock: Block that is called with the activity
    @available(*, deprecated, message: "`unique` is ignored and `activityBlock` is now always called once per activity. Use `airshipWatchActivities(activityBlock:)`.")
    public class func airshipWatchActivities(
        unique: Bool,
        activityBlock: @escaping @Sendable (Activity<Attributes>) -> Void
    ) {
        airshipWatchActivities(activityBlock: activityBlock)
    }
}


#endif


