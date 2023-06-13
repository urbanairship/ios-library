import Foundation

@testable import AirshipCore

@objc(UATestAnalytics)
public class TestAnalytics: NSObject, InternalAnalyticsProtocol, AirshipComponent, @unchecked Sendable {
    public func onDeviceRegistration(token: String) {

    }

    public func onNotificationResponse(response: UNNotificationResponse, action: UNNotificationAction?) {

    }

    public func addHeaderProvider(_ headerProvider: @escaping () async -> [String : String]) {
        headerBlocks.append(headerProvider)
    }


    public var headerBlocks: [() async -> [String: String]] = []

    public var headers: [String: String] {
        get async {
            var allHeaders: [String: String] = [:]
            for headerBlock in self.headerBlocks {
                let headers = await headerBlock()
                allHeaders.merge(headers) { (_, new) in
                    return new
                }
            }
            return allHeaders
        }

    }

    public var isComponentEnabled: Bool = true

    @objc
    public var events: [Event] = []

    @objc
    public var conversionSendID: String?

    @objc
    public var conversionPushMetadata: String?

    @objc
    public var sessionID: String?

    public func addEvent(_ event: Event) {
        events.append(event)
    }

    public func associateDeviceIdentifiers(
        _ associatedIdentifiers: AssociatedIdentifiers
    ) {
    }

    public func currentAssociatedDeviceIdentifiers() -> AssociatedIdentifiers {
        return AssociatedIdentifiers()
    }

    public func trackScreen(_ screen: String?) {

    }

    public func scheduleUpload() {
    }

    public func registerSDKExtension(
        _ ext: AirshipSDKExtension,
        version: String
    ) {
    }

    public func launched(fromNotification notification: [AnyHashable: Any]) {
    }

}
