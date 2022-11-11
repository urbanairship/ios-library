import Foundation

@testable import AirshipCore

@objc(UATestAnalytics)
public class TestAnalytics: NSObject, AnalyticsProtocol, Component {

    public var headerBlocks: [() -> [String: String]?] = []

    public var headers: [String: String] {
        var headers: [String: String] = [:]
        headerBlocks.forEach {
            headers.merge(
                $0() ?? [:],
                uniquingKeysWith: { (current, _) in current }
            )
        }
        return headers
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

    public var eventConsumer: AnalyticsEventConsumerProtocol?

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

    public func registerSDKExtension(_ ext: SDKExtension, version: String) {
    }

    public func launched(fromNotification notification: [AnyHashable: Any]) {
    }

    public func add(_ headerBlock: @escaping () -> [String: String]?) {
        headerBlocks.append(headerBlock)
    }
}
