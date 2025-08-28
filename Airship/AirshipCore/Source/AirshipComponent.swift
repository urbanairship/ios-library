/* Copyright Airship and Contributors */



/// Airship component.
///  - Note: For internal use only. :nodoc:
public protocol AirshipComponent: Sendable {

    /// Called once the Airship instance is ready.
    @MainActor
    func airshipReady()

    /// Called to handle `uairship://` deep links. The first component that
    /// returns true will prevent others from receiving the deep link.
    /// - Parameters:
    ///     - deepLink: The deep link.
    /// - Returns: true if the deep link was handled, otherwise false.
    @MainActor
    func deepLink(_ deepLink: URL) -> Bool
}

public extension AirshipComponent {
    func airshipReady() {}
    func deepLink(_ deepLink: URL) -> Bool { return false }
}
