/* Copyright Airship and Contributors */

import Foundation

/// Analytics protocol
/// For internal use only. :nodoc:
@objc(UAAnalyticsProtocol)
public protocol AnalyticsProtocol {
    /// The conversion send ID. :nodoc:
    @objc
    var conversionSendID: String? { get }

    /// The conversion push metadata. :nodoc:
    @objc
    var conversionPushMetadata: String? { get }

    /// The current session ID.
    @objc
    var sessionID: String? { get }

    /// Optional event consumer.
    ///
    /// - Note: AirshipDebug uses the event consumer to capture events. Setting the event
    /// consumer for other purposes will result in an interruption to AirshipDebug's event stream.
    ///
    /// For internal use only. :nodoc:
    @objc
    var eventConsumer: AnalyticsEventConsumerProtocol? { get set}

    /// Triggers an analytics event.
    /// - Parameter event: The event to be triggered
    @objc
    func addEvent(_ event: Event)

    /// Associates identifiers with the device. This call will add a special event
    /// that will be batched and sent up with our other analytics events. Previous
    /// associated identifiers will be replaced.
    ///
    /// For internal use only. :nodoc:
    ///
    /// - Parameter associatedIdentifiers: The associated identifiers.
    @objc
    func associateDeviceIdentifiers(_ associatedIdentifiers: AssociatedIdentifiers)

    /// The device's current associated identifiers.
    /// - Returns: The device's current associated identifiers.
    @objc
    func currentAssociatedDeviceIdentifiers() -> AssociatedIdentifiers

    /// Initiates screen tracking for a specific app screen, must be called once per tracked screen.
    /// - Parameter screen: The screen's identifier.
    @objc
    func trackScreen(_ screen: String?)

    /// Schedules an event upload if one is not already scheduled.
    @objc
    func scheduleUpload()

    /// Registers an SDK extension with the analytics module.
    /// For internal use only. :nodoc:
    ///
    /// - Parameters:
    ///   - ext: The SDK extension.
    ///   - version: The version.
    @objc
    func registerSDKExtension(_ ext: SDKExtension, version: String)

    /// Called to notify analytics the app was launched from a push notification.
    /// For internal use only. :nodoc:
    /// - Parameter notification: The push notification.
    @objc
    func launched(fromNotification notification: [AnyHashable : Any])
    
    /// For internal use only. :nodoc:
    @objc(addAnalyticsHeadersBlock:)
    func add(_ headerBlock: @escaping () -> [String : String]?)
}


protocol InternalAnalyticsProtocol {
    func onDeviceRegistration()
    
    #if !os(tvOS)
    func onNotificationResponse(response: UNNotificationResponse, action: UNNotificationAction?)
    #endif
}
