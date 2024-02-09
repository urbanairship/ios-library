/* Copyright Airship and Contributors */

import Foundation

public protocol InAppMessageViewDelegate {
    /// Called whenever the view appears
    @MainActor
    func onAppear()

    /// Called when a button dismisses the in-app message
    /// - Parameters:
    ///     - buttonInfo: The button info on the dismissing button.
    @MainActor
    func onButtonDismissed(buttonInfo: InAppMessageButtonInfo)

    /// Called when a message dismisses after the set timeout period
    @MainActor
    func onTimedOut()

    /// Called when a message dismisses with the close button or banner drawer handle
    @MainActor
    func onUserDismissed()

    /// Called when a message is dismissed via a tap to the message body
    @MainActor
    func onMessageTapDismissed()
}
