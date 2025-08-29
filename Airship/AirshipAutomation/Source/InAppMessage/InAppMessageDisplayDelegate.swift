/* Copyright Airship and Contributors */

import Foundation

/// Message display delegate
public protocol InAppMessageDisplayDelegate: AnyObject, Sendable{

    /// Called to check if the message is ready to be displayed. This method will be called for
    /// every message that is pending display whenever a display condition changes. Use `notifyDisplayConditionsChanged`
    /// to notify whenever a condition changes to reevaluate the pending In-App messages.
    ///
    /// - Parameters:
    ///     - message: The message
    ///     - scheduleID: The schedule ID
    /// - Returns: true if the message is ready to display, false otherwise.
    @MainActor
    func isMessageReadyToDisplay(_ message: InAppMessage, scheduleID: String) -> Bool

    /// Called when a message will be displayed.
    /// - Parameters:
    ///     - message: The message
    ///     - scheduleID: The schedule ID
    @MainActor
    func messageWillDisplay(_ message: InAppMessage, scheduleID: String)


    /// Called when a message finished displaying
    /// - Parameters:
    ///     - message: The message
    ///     - scheduleID: The schedule ID
    @MainActor
    func messageFinishedDisplaying(_ message: InAppMessage, scheduleID: String)
}
