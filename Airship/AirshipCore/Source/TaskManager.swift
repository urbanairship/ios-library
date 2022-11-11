/* Copyright Airship and Contributors */

import UIKit

// Legacy
// NOTE: For internal use only. :nodoc:
@objc(UATaskManager)
public class TaskManager: NSObject, TaskManagerProtocol {

    @objc
    public static let shared = TaskManager(
        workManager: AirshipWorkManager.shared,
        dispatcher: UADispatcher.globalDispatcher(.utility)
    )

    let workManager: AirshipWorkManagerProtocol
    let dispatcher: UADispatcher

    init(
        workManager: AirshipWorkManagerProtocol,
        dispatcher: UADispatcher
    ) {
        self.workManager = workManager
        self.dispatcher = dispatcher
        super.init()
    }
    @objc(registerForTaskWithID:type:launchHandler:)
    public func register(
        taskID: String,
        type: AirshipWorkerType,
        launchHandler: @escaping (AirshipTask) -> Void
    ) {
        self.register(
            taskID: taskID,
            type: type,
            dispatcher: self.dispatcher,
            launchHandler: launchHandler
        )
    }

    @objc(registerForTaskWithID:type:dispatcher:launchHandler:)
    public func register(
        taskID: String,
        type: AirshipWorkerType,
        dispatcher: UADispatcher,
        launchHandler: @escaping (AirshipTask) -> Void
    ) {
        self.workManager._registerWorker(taskID, type: type) {
            request,
            continuation in

            let requestOptions = TaskRequestOptions(
                conflictPolicy: request.conflictPolicy,
                requiresNetwork: request.requiresNetwork,
                extras: request.extras
            )

            let expirableTask = ExpirableTask(
                taskID: taskID,
                requestOptions: requestOptions
            ) { success in
                if success {
                    continuation.finishTask(.success)
                } else {
                    continuation.finishTask(.failure)
                }
            }

            continuation.cancellationHandler = {
                expirableTask.expire()
            }

            dispatcher.dispatchAsync {
                launchHandler(expirableTask)
            }
        }
    }

    @objc(setRateLimitForID:rate:timeInterval:error:)
    public func setRateLimit(
        _ rateLimitID: String,
        rate: Int,
        timeInterval: TimeInterval
    ) throws {
        self.workManager.setRateLimit(
            rateLimitID,
            rate: rate,
            timeInterval: timeInterval
        )
    }

    @objc(enqueueRequestWithID:options:)
    public func enqueueRequest(taskID: String, options: TaskRequestOptions) {
        self.enqueueRequest(taskID: taskID, options: options, initialDelay: 0)
    }

    @objc(enqueueRequestWithID:options:initialDelay:)
    public func enqueueRequest(
        taskID: String,
        options: TaskRequestOptions,
        initialDelay: TimeInterval
    ) {
        self.enqueueRequest(
            taskID: taskID,
            rateLimitIDs: [],
            options: options,
            minDelay: initialDelay
        )
    }

    @objc(enqueueRequestWithID:rateLimitIDs:options:)
    public func enqueueRequest(
        taskID: String,
        rateLimitIDs: [String],
        options: TaskRequestOptions
    ) {
        self.enqueueRequest(
            taskID: taskID,
            rateLimitIDs: rateLimitIDs,
            options: options,
            minDelay: 0
        )
    }

    @objc(enqueueRequestWithID:rateLimitIDs:options:minDelay:)
    public func enqueueRequest(
        taskID: String,
        rateLimitIDs: [String],
        options: TaskRequestOptions,
        minDelay: TimeInterval
    ) {

        let workRequest = AirshipWorkRequest(
            workID: taskID,
            extras: options.extras,
            initialDelay: minDelay,
            rateLimitIDs: rateLimitIDs,
            conflictPolicy: options.conflictPolicy
        )

        self.workManager.dispatchWorkRequest(workRequest)
    }
}
