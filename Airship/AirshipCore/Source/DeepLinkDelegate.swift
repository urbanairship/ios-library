/* Copyright Airship and Contributors */

/// Protocol to be implemented by deep link handlers.
public protocol DeepLinkDelegate: AnyObject, Sendable {

    /// Called when a deep link has been triggered from Airship. If implemented, the delegate is responsible for processing the provided url.
    /// - Parameters:
    ///     - deepLink: The deep link.
    @MainActor
    func receivedDeepLink(_ deepLink: URL) async
}
