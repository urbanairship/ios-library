/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc
public protocol TaskManagerProtocol {
    
    @objc(registerForTaskWithIDs:dispatcher:launchHandler:)
    func register(taskIDs: [String], dispatcher: UADispatcher?, launchHandler: @escaping (UATask) -> Void)

    @objc(registerForTaskWithID:dispatcher:launchHandler:)
    func register(taskID: String, dispatcher: UADispatcher?, launchHandler: @escaping (UATask) -> Void)

    @objc(enqueueRequestWithID:options:)
    func enqueueRequest(taskID: String, options: UATaskRequestOptions)
    
    @objc(enqueueRequestWithID:options:initialDelay:)
    func enqueueRequest(taskID: String, options: UATaskRequestOptions, initialDelay: TimeInterval)
}
