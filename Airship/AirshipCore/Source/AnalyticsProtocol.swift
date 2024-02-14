/* Copyright Airship and Contributors */

import Foundation
import Combine

/// Analytics protocol
@objc(UAAnalyticsProtocol)
public protocol AirshipBaseAnalyticsProtocol: AnyObject, Sendable {

    /// The conversion send ID. :nodoc:
    @objc
    var conversionSendID: String? { get }

    /// The conversion push metadata. :nodoc:
    @objc
    var conversionPushMetadata: String? { get }

    /// The current session ID.
    @objc
    var sessionID: String { get }

    /// Adds a custom event.
    /// - Parameter event: The event.
    @objc
    func recordCustomEvent(_ event: CustomEvent)

    /// Tracks a custom event.
    /// - Parameter event: The event.
    @objc
    func recordRegionEvent(_ event: RegionEvent)

    @objc
    func trackInstallAttribution(appPurchaseDate: Date?, iAdImpressionDate: Date?)

    /// Associates identifiers with the device. This call will add a special event
    /// that will be batched and sent up with our other analytics events. Previous
    /// associated identifiers will be replaced.
    ///
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


/// Airship Analytics
public protocol AirshipAnalyticsProtocol: AirshipBaseAnalyticsProtocol {
    /// A publisher of event data that is tracked through Airship.
    var eventPublisher: AnyPublisher<AirshipEventData, Never> { get }
}

/// Internal Analytics protocol
/// For internal use only. :nodoc:
public protocol InternalAnalyticsProtocol: AirshipAnalyticsProtocol {
    var eventFeed: AirshipAnalyticsFeed { get }

    @MainActor
    var screenUpdates: AsyncStream<String?> { get }

    @MainActor
    var currentScreen: String? { get }

    @MainActor
    var regionUpdates: AsyncStream<Set<String>> { get }

    @MainActor
    var currentRegions: Set<String> { get }

    func recordEvent(_ event: AirshipEvent)

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
