import Foundation

@testable import AirshipCore
import Combine

public class TestAnalytics: InternalAnalyticsProtocol, AirshipComponent, @unchecked Sendable {
    public var eventFeed: AirshipAnalyticsFeed = AirshipAnalyticsFeed()
    
    let eventSubject = PassthroughSubject<AirshipEventData, Never>()

    /// Airship event publisher
    public var eventPublisher: AnyPublisher<AirshipEventData, Never> {
        eventSubject.eraseToAnyPublisher()
    }


    public func recordCustomEvent(_ event: CustomEvent) {
        self.customEvents.append(event)
    }
    
    public func recordRegionEvent(_ event: RegionEvent) {

    }
    
    public func trackInstallAttribution(appPurchaseDate: Date?, iAdImpressionDate: Date?) {

    }
    
    public func recordEvent(_ event: AirshipEvent) {
        self.events.append(event)
    }

    private let screen = AirshipMainActorValue<String?>(nil)
    private let regions = AirshipMainActorValue<Set<String>>(Set())


    @MainActor
    public func setScreen(_ screen: String?) {
        self.screen.set(screen)
    }

    @MainActor
    public func setRegions(_ regions: Set<String>) {
        self.regions.set(regions)
    }


    public var screenUpdates: AsyncStream<String?> {
        return self.screen.updates
    }

    @MainActor
    public var currentScreen: String? {
        return self.screen.value
    }

    public var regionUpdates: AsyncStream<Set<String>> {
        return self.regions.updates
    }

    public var currentRegions: Set<String> {
        return self.regions.value
    }

    var onDeviceRegistrationCalled = false

    public func onDeviceRegistration(token: String) {
        onDeviceRegistrationCalled = true
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

    public var events: [AirshipEvent] = []
    public var customEvents: [CustomEvent] = []

    @objc
    public var conversionSendID: String?

    @objc
    public var conversionPushMetadata: String?

    @objc
    public var sessionID: String = ""

    public func addEvent(_ event: AirshipEvent) {
        events.append(event)
    }

    public func associateDeviceIdentifiers(
        _ associatedIdentifiers: AssociatedIdentifiers
    ) {
    }

    public func currentAssociatedDeviceIdentifiers() -> AssociatedIdentifiers {
        return AssociatedIdentifiers()
    }

    @MainActor
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

