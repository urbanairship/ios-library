/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc
public protocol TaskManagerProtocol {
    
    @objc(registerForTaskWithIDs:dispatcher:launchHandler:)
    func register(taskIDs: [String], dispatcher: UADispatcher?, launchHandler: @escaping (Task) -> Void)

    @objc(registerForTaskWithID:dispatcher:launchHandler:)
    func register(taskID: String, dispatcher: UADispatcher?, launchHandler: @escaping (Task) -> Void)

    @objc(enqueueRequestWithID:options:)
    func enqueueRequest(taskID: String, options: TaskRequestOptions)
    
    @objc(enqueueRequestWithID:options:initialDelay:)
    func enqueueRequest(taskID: String, options: TaskRequestOptions, initialDelay: TimeInterval)
}
