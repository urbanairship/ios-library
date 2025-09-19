/* Copyright Airship and Contributors */

import XCTest
import Combine

@testable import AirshipCore

class AnalyticsTest: XCTestCase {

    private let appStateTracker = TestAppStateTracker()
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let config = RuntimeConfig.testConfig()
    private let channel = TestChannel()
    private let locale = TestLocaleManager()
    private var permissionsManager: AirshipPermissionsManager!
    private let notificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())
    private let date = UATestDate()
    private let eventManager = TestEventManager()
    private let sessionEventFactory = TestSessionEventFactory()
    private let sessionTracker = TestSessionTracker()

    private var privacyManager: TestPrivacyManager!
    private var analytics: DefaultAirshipAnalytics!
    private var testAirship: TestAirshipInstance!


    @MainActor
    override func setUp() async throws {
        testAirship = TestAirshipInstance()
        self.permissionsManager = AirshipPermissionsManager()
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: RuntimeConfig.testConfig(),
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )
        

        self.analytics = makeAnalytics()
    }

    @MainActor
    func makeAnalytics() -> DefaultAirshipAnalytics {
        return DefaultAirshipAnalytics(
            config: config,
            dataStore: dataStore,
            channel: channel,
            notificationCenter: notificationCenter,
            date: date,
            localeManager: locale,
            privacyManager: privacyManager,
            permissionsManager: permissionsManager,
            eventManager: eventManager,
            sessionTracker: sessionTracker,
            sessionEventFactory: sessionEventFactory
        )
    }

    override class func tearDown() {
        TestAirshipInstance.clearShared()
    }

    @MainActor
    func testScreenTrackingBackground() async throws {
        let notificationCenter = self.notificationCenter
        // Foreground
        notificationCenter.post(name: AppStateTracker.willEnterForegroundNotification)

        self.analytics.trackScreen("test_screen")

        let events = try await self.produceEvents(count: 1) { @MainActor in
            notificationCenter.post(
                name: AppStateTracker.didEnterBackgroundNotification,
                object: nil
            )
        }

        XCTAssertEqual("screen_tracking", events[0].type.reportingName)
    }

    @MainActor
    func testScreenTrackingTerminate() async throws {
        let notificationCenter = self.notificationCenter

        // Foreground
        notificationCenter.post(name: AppStateTracker.willEnterForegroundNotification)

        // Track the screen
        self.analytics.trackScreen("test_screen")

        self.analytics.trackScreen("test_screen")

        let events = try await self.produceEvents(count: 1) { @MainActor in
            notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification)
        }

        XCTAssertEqual("screen_tracking", events[0].type.reportingName)
    }

    func testScreenTracking() async throws {
        let date = self.date
        let analytics = self.analytics
        let currentTime = Date().timeIntervalSince1970
        let timeOffset = 3.0

        let events = try await self.produceEvents(count: 1) { @MainActor in
            analytics?.trackScreen("test_screen")
            date.offset = timeOffset
            analytics?.trackScreen("another_screen")
        }

        let body: AirshipJSON = events[0].body

        XCTAssertEqual("screen_tracking", events[0].type.reportingName)
        XCTAssertEqual("test_screen", body.object?["screen"]?.string)
        XCTAssertEqual("3.000", body.object?["duration"]?.string)

        compareTimestamps(value: body.object?["entered_time"]?.string, expectedValue: currentTime)
        compareTimestamps(value: body.object?["exited_time"]?.string, expectedValue: currentTime + timeOffset)
    }

    private func compareTimestamps(value: String?, expectedValue: TimeInterval) {
        if let value = value, let actualValue = Double(value) {
            XCTAssertEqual(actualValue, expectedValue, accuracy: 1)
        } else {
            XCTFail("Not a double")
        }
    }

    @MainActor
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


    @MainActor
    func testEnableAnalytics() throws {
        self.channel.identifier = "test channel"
        self.analytics.airshipReady()

        XCTAssertTrue(self.eventManager.uploadsEnabled)
        
        self.privacyManager.disableFeatures(.analytics)
        XCTAssertFalse(self.eventManager.uploadsEnabled)

        let expectation = XCTestExpectation()
        self.eventManager.scheduleUploadCallback = { priority in
            XCTAssertEqual(AirshipEventPriority.normal, priority)
            expectation.fulfill()
        }
        self.privacyManager.enableFeatures(.analytics)
        XCTAssertTrue(self.eventManager.uploadsEnabled)
        wait(for: [expectation], timeout: 5.0)
    }

    @MainActor
    func testCurrentScreen() throws {
        self.analytics.trackScreen("foo")
        XCTAssertEqual("foo", self.analytics.currentScreen)

        self.analytics.trackScreen("bar")
        XCTAssertEqual("bar", self.analytics.currentScreen)

        self.analytics.trackScreen(nil)
        XCTAssertEqual(nil, self.analytics.currentScreen)
    }

    @MainActor
    func testScreenUpdates() async throws {
        let expectation = expectation(description: "updates received")

        let screenUpdates = analytics.screenUpdates
        Task {
            var updates: [String?] = []
            for await update in screenUpdates {
                updates.append(update)
                if (updates.count == 4) {
                    break
                }
            }

            XCTAssertEqual([nil, "foo", "bar", nil], updates)
            expectation.fulfill()
        }

        self.analytics.trackScreen("foo")
        XCTAssertEqual("foo", self.analytics.currentScreen)


        self.analytics.trackScreen("bar")
        XCTAssertEqual("bar", self.analytics.currentScreen)

        self.analytics.trackScreen("bar")
        self.analytics.trackScreen("bar")


        self.analytics.trackScreen(nil)
        XCTAssertEqual(nil, self.analytics.currentScreen)

        await self.fulfillment(of: [expectation])
    }

    @MainActor
    func testRegions() async throws {
        var updates = self.analytics.regionUpdates.makeAsyncIterator()
        var update = await updates.next()
        XCTAssertEqual(Set(), update)

        self.analytics.recordRegionEvent(
            RegionEvent(regionID: "foo", source: "source", boundaryEvent: .enter)!
        )
        
        update = await updates.next()
        XCTAssertEqual(Set(["foo"]), update)
        XCTAssertEqual(Set(["foo"]), self.analytics.currentRegions)

        self.analytics.recordRegionEvent(
            RegionEvent(regionID: "bar", source: "source", boundaryEvent: .enter)!
        )

        update = await updates.next()
        XCTAssertEqual(Set(["foo", "bar"]), update)
        XCTAssertEqual(Set(["foo", "bar"]), self.analytics.currentRegions)

        self.analytics.recordRegionEvent(
            RegionEvent(regionID: "bar", source: "source", boundaryEvent: .exit)!
        )

        update = await updates.next()
        XCTAssertEqual(Set(["foo"]), update)
        XCTAssertEqual(Set(["foo"]), self.analytics.currentRegions)

        self.analytics.recordRegionEvent(
            RegionEvent(regionID: "baz", source: "source", boundaryEvent: .exit)!
        )

        update = await updates.next()
        XCTAssertEqual(Set(["foo"]), update)
        XCTAssertEqual(Set(["foo"]), self.analytics.currentRegions)

        self.analytics.recordRegionEvent(
            RegionEvent(regionID: "foo", source: "source", boundaryEvent: .exit)!
        )

        update = await updates.next()
        XCTAssertEqual(Set(), update)
        XCTAssertEqual(Set(), self.analytics.currentRegions)
    }

    func testAddEvent() throws {
        let expectation = XCTestExpectation()
        self.eventManager.addEventCallabck = { event in
            XCTAssertEqual("app_background", event.type.reportingName)
            expectation.fulfill()
        }

        self.analytics.recordEvent(AirshipEvent(priority: .normal, eventType: .appBackground, eventData: .string("body")))

        wait(for: [expectation], timeout: 5.0)
    }

    func testAssociateDeviceIdentifiers() async throws {
        let analytics = self.analytics
        let events = try await self.produceEvents(count: 1) {
            let ids = AssociatedIdentifiers(identifiers: ["neat": "id"])
            analytics?.associateDeviceIdentifiers(ids)
        }

        let expectedData = [
            "neat": "id",
        ]

        XCTAssertEqual("associate_identifiers", events[0].type.reportingName)
        XCTAssertEqual(
            try AirshipJSON.wrap(expectedData),
            events[0].body
        )
    }

    @MainActor
    func testMissingSendID() throws {
        let notification = ["aps": ["alert": "neat"]]
        self.analytics.launched(fromNotification: notification)
        XCTAssertEqual("MISSING_SEND_ID", self.analytics.conversionSendID)
        XCTAssertNil(self.analytics.conversionPushMetadata)
    }
    
    @MainActor
    func testConversionSendID() throws {
        let notification: [String: AnyHashable] = [
            "aps": ["alert": "neat"],
            "_": "some conversionSendID",
        ]
        self.analytics.launched(fromNotification: notification)
        XCTAssertEqual("some conversionSendID", self.analytics.conversionSendID)
    }

    @MainActor
    func testConversationMetadata() throws {
        let notification: [String: AnyHashable] = [
            "aps": ["alert": "neat"],
            "_": "some conversionSendID",
            "com.urbanairship.metadata": "some metadata",
        ]

        self.analytics.launched(fromNotification: notification)
        XCTAssertEqual("some metadata", self.analytics.conversionPushMetadata)
    }

    @MainActor
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

    func testScreenEventFeed() async throws {
        var feed = await self.analytics.eventFeed.updates.makeAsyncIterator()
        await self.analytics.trackScreen("some screen")

        let next = await feed.next()
        XCTAssertEqual(next, .screen(screen: "some screen"))
    }

    func testRegionEventEventFeed() async throws {
        let event = RegionEvent(
            regionID: "foo",
            source: "test",
            boundaryEvent: .enter
        )!

        var feed = await self.analytics.eventFeed.updates.makeAsyncIterator()
        self.analytics.recordRegionEvent(event)

        let next = await feed.next()
        XCTAssertEqual(next, .analytics(eventType: .regionEnter, body: try event.eventBody(stringifyFields: false), value: nil))
    }

    func testForwardCustomEvents() async throws {
        let event = CustomEvent(name: "foo", value: 10.0)

        var feed = await self.analytics.eventFeed.updates.makeAsyncIterator()
        self.analytics.recordCustomEvent(event)

        let next = await feed.next()
        XCTAssertEqual(
            next,
            .analytics(
                eventType: .customEvent,
                body: event.eventBody(
                    sendID: nil,
                    metadata: nil,
                    formatValue: false
                ),
                value: 10.0
            )
        )
    }

    func testForwardCustomEventNoValue() async throws {
        let event = CustomEvent(name: "foo")

        var feed = await self.analytics.eventFeed.updates.makeAsyncIterator()
        self.analytics.recordCustomEvent(event)

        let next = await feed.next()
        XCTAssertEqual(
            next,
            .analytics(
                eventType: .customEvent,
                body: event.eventBody(
                    sendID: nil,
                    metadata: nil,
                    formatValue: false
                ),
                value: 1.0
            )
        )
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
            "X-UA-Device-Model": AirshipUtils.deviceModelName(),
            "X-UA-Lib-Version": AirshipVersion.version,
            "X-UA-App-Key": self.config.appCredentials.appKey,
            "X-UA-Package-Name":
                Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String]
                as? String,
            "X-UA-Package-Version": AirshipUtils.bundleShortVersionString() ?? "",
        ]

        let headers = await self.eventManager.headers
        XCTAssertEqual(expected, headers)
    }

    func testAnalyticsHeaderExtension() async throws {
        await self.analytics.addHeaderProvider {
            return ["neat": "story"]
        }

        let headers = await self.eventManager.headers
        XCTAssertEqual(
            "story",
            headers["neat"]
        )
    }
    
    @MainActor
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

    @MainActor
    func produceEvents(
        count: Int,
        eventProducingAction: @escaping @Sendable () async -> Void
    ) async throws -> [AirshipEventData] {
        var subscription: AnyCancellable?
        defer {
            subscription?.cancel()
        }

        let stream = AsyncThrowingStream<AirshipEventData, Error> { continuation in
            let cancelTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000)
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
        }

        await eventProducingAction()

        var result: [AirshipEventData] = []
        for try await value in stream {
            result.append(value)
        }

        return result
    }

    func testSessionEvents() async throws {
        let date = Date()
        let sessionTracker = self.sessionTracker

        let events = try await self.produceEvents(count: 4) {
            sessionTracker.eventsContinuation.yield(
                SessionEvent(type: .background, date: date, sessionState: SessionState())
            )

            sessionTracker.eventsContinuation.yield(
                SessionEvent(type: .foreground, date: date, sessionState: SessionState())
            )

            sessionTracker.eventsContinuation.yield(
                SessionEvent(type: .foregroundInit, date: date, sessionState: SessionState())
            )
            sessionTracker.eventsContinuation.yield(
                SessionEvent(type: .backgroundInit, date: date, sessionState: SessionState())
            )
        }

        XCTAssertEqual(
            [
                EventType.appBackground.reportingName,
                EventType.appForeground.reportingName,
                EventType.appInit.reportingName,
                EventType.appInit.reportingName
            ],
            events.map { $0.type.reportingName }
        )
        XCTAssertEqual(
            [
                .string("app_background"),
                .string("app_foreground"),
                .string("app_foreground_init"),
                .string("app_background_init")
            ],
            events.map { $0.body }
        )
        XCTAssertEqual([date, date, date, date], events.map { $0.date })
    }
}


final class TestEventManager: EventManagerProtocol, @unchecked Sendable {
    var uploadsEnabled: Bool = false

    var addEventCallabck: ((AirshipEventData) -> Void)?


    func addEvent(_ event: AirshipEventData) async throws {
        addEventCallabck?(event)
    }

    var deleteEventsCallback: (() -> Void)?
    func deleteEvents() async throws {
        self.deleteEventsCallback?()
    }

    var scheduleUploadCallback: ((AirshipEventPriority) -> Void)?

    func scheduleUpload(eventPriority: AirshipEventPriority) async {
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


final class TestSessionEventFactory: SessionEventFactoryProtocol, @unchecked Sendable {
    func make(event: SessionEvent) -> AirshipEvent {
        let eventType: EventType = switch(event.type) {
        case .backgroundInit, .foregroundInit: .appInit
        case .background: .appBackground
        case .foreground: .appForeground
        }

        let name: String = switch(event.type) {
        case .backgroundInit: "app_background_init"
        case .foregroundInit: "app_foreground_init"
        case .background: "app_background"
        case .foreground: "app_foreground"
        }

        return AirshipEvent(eventType: eventType, eventData: AirshipJSON.string(name))
    }
}

final class TestSessionTracker: SessionTrackerProtocol {

    let eventsContinuation: AsyncStream<SessionEvent>.Continuation
    public let events: AsyncStream<SessionEvent>

    private let _sessionState: AirshipAtomicValue<SessionState> = AirshipAtomicValue(SessionState())

    var sessionState: SessionState {
        return _sessionState.value
    }

    init() {
        (self.events, self.eventsContinuation) = AsyncStream<SessionEvent>.airshipMakeStreamWithContinuation()
    }

    func airshipReady() {

    }
    
    func launchedFromPush(sendID: String?, metadata: String?) {
        self._sessionState.update { state in
            var state = state
            state.conversionMetadata = metadata
            state.conversionSendID = sendID
            return state
        }
    }
}
