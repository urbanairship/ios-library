/* Copyright Airship and Contributors */

import Foundation

/// Analytics protocol
/// For internal use only. :nodoc:
@objc(UAAnalyticsProtocol)
public protocol AnalyticsProtocol: Sendable {
    /// The conversion send ID. :nodoc:
    @objc
    var conversionSendID: String? { get }

    /// The conversion push metadata. :nodoc:
    @objc
    var conversionPushMetadata: String? { get }

    /// The current session ID.
    @objc
    var sessionID: String? { get }

    /// Triggers an analytics event.
    /// - Parameter event: The event to be triggered
    @objc
    func addEvent(_ event: AirshipEvent)

    /// Associates identifiers with the device. This call will add a special event
    /// that will be batched and sent up with our other analytics events. Previous
    /// associated identifiers will be replaced.
    ///
    /// For internal use only. :nodoc:
    ///
    /// - Parameter associatedIdentifiers: The associated identifiers.
    @objc
    func associateDeviceIdentifiers(
        _ associatedIdentifiers: AssociatedIdentifiers
    )

    /// The device's current associated identifiers.
    /// - Returns: The device's current associated identifiers.
    @objc
    func currentAssociatedDeviceIdentifiers() -> AssociatedIdentifiers

    /// Initiates screen tracking for a specific app screen, must be called once per tracked screen.
    /// - Parameter screen: The screen's identifier.
    @objc
    @MainActor
    func trackScreen(_ screen: String?)

    /// Registers an SDK extension with the analytics module.
    /// For internal use only. :nodoc:
    ///
    /// - Parameters:
    ///   - ext: The SDK extension.
    ///   - version: The version.
    @objc
    func registerSDKExtension(_ ext: AirshipSDKExtension, version: String)

}

/// Internal Analytics protocol
/// For internal use only. :nodoc:
public protocol InternalAnalyticsProtocol: AnalyticsProtocol {
    @MainActor
    var screenUpdates: AsyncStream<String?> { get }

    @MainActor
    var currentScreen: String? { get }

    @MainActor
    var regionUpdates: AsyncStream<Set<String>> { get }

    @MainActor
    var currentRegions: Set<String> { get }


    func onDeviceRegistration(token: String)

    #if !os(tvOS)
    @MainActor
    func onNotificationResponse(
        response: UNNotificationResponse,
        action: UNNotificationAction?
    )
    #endif


    /// Called to notify analytics the app was launched from a push notification.
    /// For internal use only. :nodoc:
    /// - Parameter notification: The push notification.
    @MainActor
    func launched(fromNotification notification: [AnyHashable: Any])

    @MainActor
    func addHeaderProvider(_ headerProvider: @Sendable @escaping () async -> [String: String])

}
