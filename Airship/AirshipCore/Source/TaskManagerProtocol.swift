/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc
public protocol TaskManagerProtocol {
    
    @objc(registerForTaskWithIDs:dispatcher:launchHandler:)
    func register(taskIDs: [String], dispatcher: UADispatcher?, launchHandler: @escaping (AirshipTask) -> Void)

    @objc(registerForTaskWithID:dispatcher:launchHandler:)
    func register(taskID: String, dispatcher: UADispatcher?, launchHandler: @escaping (AirshipTask) -> Void)

    @objc(enqueueRequestWithID:options:)
    func enqueueRequest(taskID: String, options: TaskRequestOptions)
    
    @objc(enqueueRequestWithID:options:initialDelay:)
    func enqueueRequest(taskID: String, options: TaskRequestOptions, initialDelay: TimeInterval)

    @objc(setRateLimitForID:rate:timeInterval:error:)
    func setRateLimit(_ rateLimitID: String, rate: Int, timeInterval: TimeInterval) throws

    @objc(enqueueRequestWithID:rateLimitIDs:options:minDelay:)
    func enqueueRequest(taskID: String,
                        rateLimitIDs: [String],
                        options: TaskRequestOptions,
                        minDelay: TimeInterval)

    @objc(enqueueRequestWithID:rateLimitIDs:options:)
    func enqueueRequest(taskID: String, rateLimitIDs: [String], options: TaskRequestOptions)
}
