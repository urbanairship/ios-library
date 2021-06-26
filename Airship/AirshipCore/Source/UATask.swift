/* Copyright Airship and Contributors */

import Foundation


/**
 * Task passed to the launcher when ready to execute.
 * @note For internal use only. :nodoc:
 */
@objc
public protocol UATask {
    
    /**
     * Expiration handler. Will be called when background time is about to expire. The launcher is still expected to call `taskCompleted` or `taskFailed`.
     */
    @objc
    var expirationHandler: (() -> Void)? { get set }

    /**
     * The task ID.
     */
    @objc
    var taskID: String { get }

    /**
     * The task request options.
     */
    @objc
    var requestOptions: UATaskRequestOptions { get }

    /**
     * The launcher should call this method to signal that the task was completed succesfully.
     */
    @objc
    func taskCompleted()

    /**
     * The launcher should call this method to signal the task failed and needs to be retried.
     */
    @objc
    func taskFailed()
}
