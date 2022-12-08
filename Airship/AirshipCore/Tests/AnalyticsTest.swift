/* Copyright Airship and Contributors */

import XCTest
import Combine

@testable import AirshipCore

class AnalyticsTest: XCTestCase {

    private let appStateTracker = TestAppStateTracker()
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let config = Config()
    private let channel = TestChannel()
    private let locale = TestLocaleManager()
    private let permissionsManager = PermissionsManager()
    private let notificationCenter = NotificationCenter()
    private let date = UATestDate()
    private let eventManager = TestEventManager()
    private let lifecycleEventFactory = TestLifecyleEventFactory()

    private var privacyManager: PrivacyManager!
    private var analytics: Analytics!
    private let testAirship = TestAirshipInstance()

    override func setUpWithError() throws {
        self.privacyManager = PrivacyManager(
            dataStore: dataStore,
            defaultEnabledFeatures: .all,
            notificationCenter: notificationCenter
        )

        self.analytics = Analytics(
            config: RuntimeConfig(config: config, dataStore: dataStore),
            dataStore: dataStore,
            channel: channel,
            notificationCenter: notificationCenter,
            date: date,
            localeManager: locale,
            appStateTracker: appStateTracker,
            privacyManager: privacyManager,
            permissionsManager: permissionsManager,
            eventManager: eventManager,
            lifeCycleEventFactory: lifecycleEventFactory
        )
    }

    func testFirstTransitionToForegroundEmitsAppInit() async throws {
        self.appStateTracker.currentState = .inactive
        self.analytics.airshipReady()

        let events = try await self.produceEvents(count: 2) {
            self.notificationCenter.post(
                name: AppStateTracker.didTransitionToForeground,
                object: nil
            )

            self.notificationCenter.post(
                name: AppStateTracker.didTransitionToForeground,
                object: nil
            )
        }

        XCTAssertEqual("app_init", events[0].type)
        XCTAssertEqual("app_foreground", events[1].type)

        testAirship.components = [analytics]
        testAirship.makeShared()
    }

    override class func tearDown() {
        TestAirshipInstance.clearShared()
    }

    func testBackgroundBeforeForegroundEmitsAppInit() async throws {
        self.appStateTracker.currentState = .inactive
        self.analytics.airshipReady()

        let events = try await self.produceEvents(count: 2) {
            notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )
        }

        XCTAssertEqual("app_init", events[0].type)
        XCTAssertEqual("app_background", events[1].type)
    }

    func testBackgroundAfterForegroundDoesNotEmitAppInit() async throws {
        let _ = try await self.produceEvents(count: 1) {
            self.appStateTracker.currentState = .active
            self.analytics.airshipReady()
        }

        let events = try await self.produceEvents(count: 1) {
            self.notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )
        }

        XCTAssertEqual("app_background", events[0].type)
    }

    func testScreenTrackingBackground() async throws {
        // Foreground
        let _ = try await self.produceEvents(count: 1) {
            self.appStateTracker.currentState = .active
            self.analytics.airshipReady()
        }

        self.analytics.trackScreen("test_screen")

        let events = try await self.produceEvents(count: 2) {
            self.notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )
        }

        XCTAssertEqual("app_background", events[0].type)
        XCTAssertEqual("screen_tracking", events[1].type)
    }

    func testScreenTrackingTerminate() async throws {
        // Foreground
        let _ = try await self.produceEvents(count: 1) {
            self.appStateTracker.currentState = .active
            self.analytics.airshipReady()
        }

        self.analytics.trackScreen("test_screen")

        let events = try await self.produceEvents(count: 1) {
            self.notificationCenter.post(
                name: AppStateTracker.willTerminateNotification,
                object: nil
            )
        }

        XCTAssertEqual("screen_tracking", events[0].type)
    }

    func testScreenTracking() async throws {
        self.date.dateOverride = Date(timeIntervalSince1970: 100.0)

        let events = try await self.produceEvents(count: 1) {
            self.analytics.trackScreen("test_screen")
            self.date.offset = 3.0
            self.analytics.trackScreen("another_screen")
        }

        let expectedData = [
            "screen": "test_screen",
            "entered_time": "100.000",
            "exited_time": "103.000",
            "duration": "3.000"
        ]

        XCTAssertEqual("screen_tracking", events[0].type)
        XCTAssertEqual(
            try AirshipJSON.wrap(expectedData),
            try AirshipJSON.wrap(events[0].body)
        )
    }

    func testDisablingAnalytics() throws {
        self.channel.identifier = "test channel"
        self.analytics.airshipReady()

        XCTAssertTrue(self.eventManager.uploadsEnabled)

        let expectation = XCTestExpectation()
        self.eventManager.deleteEventsCallback = {
            expectation.fulfill()
        }

        self.privacyManager.disableFeatures(.analytics)
        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(self.eventManager.uploadsEnabled)

    }

    func testDisablingAnalyticsComponent() throws {
        self.channel.identifier = "test channel"
        self.analytics.airshipReady()

        XCTAssertTrue(self.eventManager.uploadsEnabled)

        let expectation = XCTestExpectation()
        self.eventManager.deleteEventsCallback = {
            expectation.fulfill()
        }

        self.analytics.isComponentEnabled = false

        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(self.eventManager.uploadsEnabled)
    }


    func testEnableAnalytics() throws {
        self.channel.identifier = "test channel"
        self.analytics.airshipReady()

        XCTAssertTrue(self.eventManager.uploadsEnabled)
        
        self.privacyManager.disableFeatures(.analytics)
        XCTAssertFalse(self.eventManager.uploadsEnabled)

        let expectation = XCTestExpectation()
        self.eventManager.scheduleUploadCallback = { priority in
            XCTAssertEqual(EventPriority.normal, priority)
            expectation.fulfill()
        }
        self.privacyManager.enableFeatures(.analytics)
        XCTAssertTrue(self.eventManager.uploadsEnabled)
        wait(for: [expectation], timeout: 5.0)
    }

    func testAddEvent() throws {
        let expectation = XCTestExpectation()
        self.eventManager.addEventCallabck = { event in
            XCTAssertEqual("valid", event.type)
            expectation.fulfill()
        }

        self.analytics.addEvent(ValidEvent())

        wait(for: [expectation], timeout: 5.0)
    }

    func testAssociateDeviceIdentifiers() async throws {
        let events = try await self.produceEvents(count: 1) {
            let ids = AssociatedIdentifiers(dictionary: ["neat": "id"])
            self.analytics.associateDeviceIdentifiers(ids)
        }

        let expectedData = [
            "neat": "id",
        ]

        XCTAssertEqual("associate_identifiers", events[0].type)
        XCTAssertEqual(
            try AirshipJSON.wrap(expectedData),
            try AirshipJSON.wrap(events[0].body)
        )
    }

    func testMissingSendID() throws {
        let notification = ["aps": ["alert": "neat"]]
        self.analytics.launched(fromNotification: notification)
        XCTAssertEqual("MISSING_SEND_ID", self.analytics.conversionSendID)
        XCTAssertNil(self.analytics.conversionPushMetadata)
    }

    func testConversionSendID() throws {
        let notification: [String: AnyHashable] = [
            "aps": ["alert": "neat"],
            "_": "some conversionSendID",
        ]
        self.analytics.launched(fromNotification: notification)
        XCTAssertEqual("some conversionSendID", self.analytics.conversionSendID)
    }

    func testConversationMetadata() throws {
        let notification: [String: AnyHashable] = [
            "aps": ["alert": "neat"],
            "_": "some conversionSendID",
            "com.urbanairship.metadata": "some metadata",
        ]

        self.analytics.launched(fromNotification: notification)
        XCTAssertEqual("some metadata", self.analytics.conversionPushMetadata)
    }

    func testLaunchedFromSilentPush() throws {
        let notification: [String: AnyHashable] = [
            "aps": ["neat": "neat"],
            "_": "some conversionSendID",
            "com.urbanairship.metadata": "some metadata",
        ]

        self.analytics.launched(fromNotification: notification)
        XCTAssertNil(self.analytics.conversionPushMetadata)
        XCTAssertNil(self.analytics.conversionSendID)
    }

    func testForwardScreenTracking() throws {
        let eventAdded = self.expectation(description: "Event added")
        self.notificationCenter.addObserver(
            forName: Analytics.screenTracked,
            object: nil,
            queue: nil
        ) { notification in

            XCTAssertEqual(
                ["screen": "some screen"],
                notification.userInfo as? [String: String]
            )
            eventAdded.fulfill()
        }

        self.analytics.trackScreen("some screen")

        self.wait(for: [eventAdded], timeout: 1)
    }

    func testForwardRegionEvents() throws {
        let event = RegionEvent(
            regionID: "foo",
            source: "test",
            boundaryEvent: .enter
        )!

        let eventAdded = self.expectation(description: "Event added")
        self.notificationCenter.addObserver(
            forName: Analytics.regionEventAdded,
            object: nil,
            queue: nil
        ) { notification in

            XCTAssertEqual(
                event,
                notification.userInfo?["event"] as? RegionEvent
            )
            eventAdded.fulfill()
        }

        self.analytics.addEvent(event)
        self.wait(for: [eventAdded], timeout: 1)
    }

    func testForwardCustomEvents() throws {
        let event = CustomEvent(name: "foo")

        let eventAdded = self.expectation(description: "Event added")
        self.notificationCenter.addObserver(
            forName: Analytics.customEventAdded,
            object: nil,
            queue: nil
        ) { notification in

            XCTAssertEqual(
                event,
                notification.userInfo?["event"] as? CustomEvent
            )
            eventAdded.fulfill()
        }

        self.analytics.addEvent(event)
        self.wait(for: [eventAdded], timeout: 1)
    }

    func testSDKExtensions() async throws {
        self.analytics.registerSDKExtension(.cordova, version: "1.2.3")
        self.analytics.registerSDKExtension(.unity, version: "5,.6,.7,,,")

        let headers = await self.eventManager.headers
        XCTAssertEqual(
            "cordova:1.2.3, unity:5.6.7",
            headers["X-UA-Frameworks"]
        )
    }

    func testAnalyticsHeaders() async throws {
        self.channel.identifier = "someChannelID"
        self.locale.currentLocale = Locale(identifier: "en-US-POSIX")

        let expected = await [
            "X-UA-Channel-ID": "someChannelID",
            "X-UA-Timezone": NSTimeZone.default.identifier,
            "X-UA-Locale-Language": "en",
            "X-UA-Locale-Country": "US",
            "X-UA-Locale-Variant": "POSIX",
            "X-UA-Device-Family": UIDevice.current.systemName,
            "X-UA-OS-Version": UIDevice.current.systemVersion,
            "X-UA-Device-Model": Utils.deviceModelName(),
            "X-UA-Lib-Version": AirshipVersion.get(),
            "X-UA-App-Key": self.config.appKey,
            "X-UA-Package-Name":
                Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String]
                as? String,
            "X-UA-Package-Version": Utils.bundleShortVersionString() ?? "",
        ]

        let headers = await self.eventManager.headers
        XCTAssertEqual(expected, headers)
    }

    func testAnalyticsHeaderExtension() async throws {
        self.analytics.addHeaderProvider {
            return ["neat": "story"]
        }

        let headers = await self.eventManager.headers
        XCTAssertEqual(
            "story",
            headers["neat"]
        )
    }

    func testPermissionHeaders() async throws {
        let testPushDelegate = TestPermissionsDelegate()
        testPushDelegate.permissionStatus = .denied
        self.permissionsManager.setDelegate(
            testPushDelegate,
            permission: .displayNotifications
        )

        let testLocationDelegate = TestPermissionsDelegate()
        testLocationDelegate.permissionStatus = .granted
        self.permissionsManager.setDelegate(
            testLocationDelegate,
            permission: .location
        )

        let headers = await self.eventManager.headers

        XCTAssertEqual(
            "denied",
            headers["X-UA-Permission-display_notifications"]
        )
        XCTAssertEqual("granted", headers["X-UA-Permission-location"])
    }

    func produceEvents(
        count: Int,
        eventProducingAction: () -> Void
    ) async throws -> [AirshipEventData] {
        var subscription: AnyCancellable?
        defer {
            subscription?.cancel()
        }

        let stream = AsyncThrowingStream<AirshipEventData, Error> { continuation in
            let cancelTask = Task {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                continuation.finish(
                    throwing: AirshipErrors.error("Failed to get event")
                )
            }

            var received = 0
            subscription = self.analytics.eventPublisher
                .sink { data in
                    continuation.yield(data)
                    received += 1
                    if (received >= count) {
                        cancelTask.cancel()
                        continuation.finish()
                    }
                }
            eventProducingAction()
        }

        var result: [AirshipEventData] = []
        for try await value in stream {
            result.append(value)
        }

        return result
    }

}

class ValidEvent: NSObject, Event {
    var data: [AnyHashable: Any] = [:]
    var eventType: String = "valid"
    var priority: EventPriority = .normal

    func isValid() -> Bool {
        return true
    }
}

class TestEventManager: EventManagerProtocol {
    var uploadsEnabled: Bool = false

    var addEventCallabck: ((AirshipEventData) -> Void)?


    func addEvent(_ event: AirshipEventData) async throws {
        addEventCallabck?(event)
    }

    var deleteEventsCallback: (() -> Void)?
    func deleteEvents() async throws {
        self.deleteEventsCallback?()
    }

    var scheduleUploadCallback: ((EventPriority) -> Void)?

    func scheduleUpload(eventPriority: EventPriority) async {
        scheduleUploadCallback?(eventPriority)
    }

    var headerProviders: [() async -> [String : String]] = []
    func addHeaderProvider(
        _ headerProvider: @escaping () async -> [String : String]
    ) {
        headerProviders.append(headerProvider)
    }

    public var headers: [String: String] {
        get async {
            var allHeaders: [String: String] = [:]
            for provider in self.headerProviders {
                let headers = await provider()
                allHeaders.merge(headers) { (_, new) in
                    return new
                }
            }
            return allHeaders
        }

    }
}


class TestLifecyleEventFactory: LifeCycleEventFactoryProtocol {
    func make(type: LifeCycleEventType) -> Event {
        return TestLifeCycleEvent(type: type)
    }
}

class TestLifeCycleEvent: NSObject, Event {
    var data: [AnyHashable: Any] = [:]
    let eventType: String
    var priority: EventPriority = .normal

    init(type: LifeCycleEventType) {
        switch(type) {
        case .appInit:
            self.eventType = "app_init"
        case .background:
            self.eventType = "app_background"
        case .foreground:
            self.eventType = "app_foreground"
        }
    }

    func isValid() -> Bool {
        return true
    }
}
