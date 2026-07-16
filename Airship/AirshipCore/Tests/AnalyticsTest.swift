/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Combine
import Foundation
#if !os(watchOS)
import UIKit
#endif

@_spi(AirshipInternal) @testable import AirshipCore

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AnalyticsTest {

    private let appStateTracker = TestAppStateTracker()
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let config = RuntimeConfig.testConfig()
    private let channel = TestChannel()
    private let locale = TestLocaleManager()
    private let permissionsManager: DefaultAirshipPermissionsManager
    private let notificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())
    private let date = UATestDate()
    private let eventManager = TestEventManager()
    private let sessionEventFactory = TestSessionEventFactory()
    private let sessionTracker = TestSessionTracker()

    private let privacyManager: TestPrivacyManager
    private let analytics: DefaultAirshipAnalytics
    private let testAirship: TestAirshipInstance

    init() {
        self.testAirship = TestAirshipInstance()
        self.permissionsManager = DefaultAirshipPermissionsManager()
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: RuntimeConfig.testConfig(),
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.analytics = DefaultAirshipAnalytics(
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

    @Test
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

        #expect("screen_tracking" == events[0].type.reportingName)
    }

    @Test
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

        #expect("screen_tracking" == events[0].type.reportingName)
    }

    @Test
    func testScreenTracking() async throws {
        let date = self.date
        let analytics = self.analytics
        let currentTime = Date().timeIntervalSince1970
        let timeOffset = 3.0

        let events = try await self.produceEvents(count: 1) { @MainActor in
            analytics.trackScreen("test_screen")
            date.offset = timeOffset
            analytics.trackScreen("another_screen")
        }

        let body: AirshipJSON = events[0].body

        #expect("screen_tracking" == events[0].type.reportingName)
        #expect("test_screen" == body.object?["screen"]?.string)
        #expect("3.000" == body.object?["duration"]?.string)

        compareTimestamps(value: body.object?["entered_time"]?.string, expectedValue: currentTime)
        compareTimestamps(value: body.object?["exited_time"]?.string, expectedValue: currentTime + timeOffset)
    }

    private func compareTimestamps(value: String?, expectedValue: TimeInterval) {
        if let value = value, let actualValue = Double(value) {
            #expect(abs(actualValue - expectedValue) <= 1)
        } else {
            Issue.record("Not a double")
        }
    }

    @Test
    func testDisablingAnalytics() async throws {
        self.channel.identifier = "test channel"
        self.analytics.airshipReady()

        #expect(self.eventManager.uploadsEnabled)

        let expectation = AirshipTestExpectation()
        self.eventManager.deleteEventsCallback = {
            expectation.fulfill()
        }

        self.privacyManager.disableFeatures(.analytics)
        await fulfillment(of: [expectation], timeout: 5.0)
        #expect(!(self.eventManager.uploadsEnabled))

    }


    @Test
    func testEnableAnalytics() async throws {
        self.channel.identifier = "test channel"
        self.analytics.airshipReady()

        #expect(self.eventManager.uploadsEnabled)
        
        self.privacyManager.disableFeatures(.analytics)
        #expect(!(self.eventManager.uploadsEnabled))

        let expectation = AirshipTestExpectation()
        self.eventManager.scheduleUploadCallback = { priority in
            #expect(AirshipEventPriority.normal == priority)
            expectation.fulfill()
        }
        self.privacyManager.enableFeatures(.analytics)
        #expect(self.eventManager.uploadsEnabled)
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    @Test
    func testCurrentScreen() throws {
        self.analytics.trackScreen("foo")
        #expect("foo" == self.analytics.currentScreen)

        self.analytics.trackScreen("bar")
        #expect("bar" == self.analytics.currentScreen)

        self.analytics.trackScreen(nil)
        #expect(nil == self.analytics.currentScreen)
    }

    @Test
    func testScreenUpdates() async throws {
        let expectation = AirshipTestExpectation(description: "updates received")

        let screenUpdates = analytics.screenUpdates
        Task {
            var updates: [String?] = []
            for await update in screenUpdates {
                updates.append(update)
                if (updates.count == 4) {
                    break
                }
            }

            #expect([nil, "foo", "bar", nil] == updates)
            expectation.fulfill()
        }

        self.analytics.trackScreen("foo")
        #expect("foo" == self.analytics.currentScreen)


        self.analytics.trackScreen("bar")
        #expect("bar" == self.analytics.currentScreen)

        self.analytics.trackScreen("bar")
        self.analytics.trackScreen("bar")


        self.analytics.trackScreen(nil)
        #expect(nil == self.analytics.currentScreen)

        await fulfillment(of: [expectation])
    }

    @Test
    func testRegions() async throws {
        var updates = self.analytics.regionUpdates.makeAsyncIterator()
        var update = await updates.next()
        #expect(Set<String>() == update)

        self.analytics.recordRegionEvent(
            RegionEvent(regionID: "foo", source: "source", boundaryEvent: .enter)!
        )
        
        update = await updates.next()
        #expect(Set(["foo"]) == update)
        #expect(Set(["foo"]) == self.analytics.currentRegions)

        self.analytics.recordRegionEvent(
            RegionEvent(regionID: "bar", source: "source", boundaryEvent: .enter)!
        )

        update = await updates.next()
        #expect(Set(["foo", "bar"]) == update)
        #expect(Set(["foo", "bar"]) == self.analytics.currentRegions)

        self.analytics.recordRegionEvent(
            RegionEvent(regionID: "bar", source: "source", boundaryEvent: .exit)!
        )

        update = await updates.next()
        #expect(Set(["foo"]) == update)
        #expect(Set(["foo"]) == self.analytics.currentRegions)

        self.analytics.recordRegionEvent(
            RegionEvent(regionID: "baz", source: "source", boundaryEvent: .exit)!
        )

        update = await updates.next()
        #expect(Set(["foo"]) == update)
        #expect(Set(["foo"]) == self.analytics.currentRegions)

        self.analytics.recordRegionEvent(
            RegionEvent(regionID: "foo", source: "source", boundaryEvent: .exit)!
        )

        update = await updates.next()
        #expect(Set<String>() == update)
        #expect(Set<String>() == self.analytics.currentRegions)
    }

    @Test
    func testAddEvent() async throws {
        let expectation = AirshipTestExpectation()
        self.eventManager.addEventCallabck = { event in
            #expect("app_background" == event.type.reportingName)
            expectation.fulfill()
        }

        self.analytics.recordEvent(AirshipEvent(priority: .normal, eventType: .appBackground, eventData: "body"))

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    @Test
    func testAssociateDeviceIdentifiers() async throws {
        let analytics = self.analytics
        let events = try await self.produceEvents(count: 1) {
            let ids = AssociatedIdentifiers(identifiers: ["neat": "id"])
            analytics.associateDeviceIdentifiers(ids)
        }

        let expectedData = [
            "neat": "id",
        ]

        #expect("associate_identifiers" == events[0].type.reportingName)
        #expect(
            (try AirshipJSON.wrap(expectedData)) == events[0].body
        )
    }

    @Test
    func testMissingSendID() throws {
        let notification = ["aps": ["alert": "neat"]]
        self.analytics.launched(fromNotification: notification)
        #expect("MISSING_SEND_ID" == self.analytics.conversionSendID)
        #expect(self.analytics.conversionPushMetadata == nil)
    }
    
    @Test
    func testConversionSendID() throws {
        let notification: [String: AnyHashable] = [
            "aps": ["alert": "neat"],
            "_": "some conversionSendID",
        ]
        self.analytics.launched(fromNotification: notification)
        #expect("some conversionSendID" == self.analytics.conversionSendID)
    }

    @Test
    func testConversationMetadata() throws {
        let notification: [String: AnyHashable] = [
            "aps": ["alert": "neat"],
            "_": "some conversionSendID",
            "com.urbanairship.metadata": "some metadata",
        ]

        self.analytics.launched(fromNotification: notification)
        #expect("some metadata" == self.analytics.conversionPushMetadata)
    }

    @Test
    func testLaunchedFromSilentPush() throws {
        let notification: [String: AnyHashable] = [
            "aps": ["neat": "neat"],
            "_": "some conversionSendID",
            "com.urbanairship.metadata": "some metadata",
        ]

        self.analytics.launched(fromNotification: notification)
        #expect(self.analytics.conversionPushMetadata == nil)
        #expect(self.analytics.conversionSendID == nil)
    }

    @Test
    func testScreenEventFeed() async throws {
        var feed = await self.analytics.eventFeed.updates.makeAsyncIterator()
        self.analytics.trackScreen("some screen")

        let next = await feed.next()
        #expect(next == .screen(screen: "some screen"))
    }

    @Test
    func testForegroundDoesNotReEmitScreenEvent() async throws {
        var feed = await self.analytics.eventFeed.updates.makeAsyncIterator()

        self.analytics.trackScreen("foo")
        self.notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification)
        self.notificationCenter.post(name: AppStateTracker.willEnterForegroundNotification)

        // The previous screen should be restored for duration tracking.
        #expect("foo" == self.analytics.currentScreen)

        self.analytics.trackScreen("bar")

        // Collect screen events from the feed until we see "bar".
        // A re-emitted "foo" between nil and "bar" would mean foreground
        // re-fired the screenview trigger.
        var screenEvents: [String?] = []
        while screenEvents.last != "bar" {
            guard let event = await feed.next() else { break }
            if case let .screen(screen) = event {
                screenEvents.append(screen)
            }
        }

        #expect(screenEvents == ["foo", nil, "bar"])
    }

    @Test
    func testRegionEventEventFeed() async throws {
        let event = RegionEvent(
            regionID: "foo",
            source: "test",
            boundaryEvent: .enter
        )!

        var feed = await self.analytics.eventFeed.updates.makeAsyncIterator()
        self.analytics.recordRegionEvent(event)

        let next = await feed.next()
        #expect(next == .analytics(eventType: .regionEnter, body: try event.eventBody(stringifyFields: false), value: nil))
    }

    @Test
    func testForwardCustomEvents() async throws {
        let event = CustomEvent(name: "foo", value: 10.0)

        var feed = await self.analytics.eventFeed.updates.makeAsyncIterator()
        self.analytics.recordCustomEvent(event)

        let next = await feed.next()
        #expect(
            next ==
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

    @Test
    func testForwardCustomEventNoValue() async throws {
        let event = CustomEvent(name: "foo")

        var feed = await self.analytics.eventFeed.updates.makeAsyncIterator()
        self.analytics.recordCustomEvent(event)

        let next = await feed.next()
        #expect(
            next ==
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

    @Test
    func testSDKExtensions() async throws {
        self.analytics.registerSDKExtension(.cordova, version: "1.2.3")
        self.analytics.registerSDKExtension(.unity, version: "5,.6,.7,,,")

        let headers = await self.eventManager.headers
        #expect(
            "cordova:1.2.3, unity:5.6.7" == headers["X-UA-Frameworks"]
        )
    }

    @Test
    func testAnalyticsHeaders() async throws {
        self.channel.identifier = "someChannelID"
        self.locale.currentLocale = Locale(identifier: "en-US-POSIX")

        let expected = [
            "X-UA-Channel-ID": "someChannelID",
            "X-UA-Timezone": NSTimeZone.default.identifier,
            "X-UA-Locale-Language": "en",
            "X-UA-Locale-Country": "US",
            "X-UA-Locale-Variant": "POSIX",
            "X-UA-Device-Family": UIDevice.current.systemName,
            "X-UA-OS-Version": UIDevice.current.systemVersion,
            "X-UA-Device-Model": AirshipDevice.modelIdentifier,
            "X-UA-Lib-Version": AirshipVersion.version,
            "X-UA-App-Key": self.config.appCredentials.appKey,
            "X-UA-Package-Name":
                Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String]
                as? String,
            "X-UA-Package-Version": AirshipUtils.bundleShortVersionString() ?? "",
        ]

        let headers = await self.eventManager.headers
        #expect(expected == headers)
    }

    @Test
    func testAnalyticsHeaderExtension() async throws {
        self.analytics.addHeaderProvider {
            return ["neat": "story"]
        }

        let headers = await self.eventManager.headers
        #expect(
            "story" == headers["neat"]
        )
    }
    
    @Test
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

        #expect(
            "denied" == headers["X-UA-Permission-display_notifications"]
        )
        #expect("granted" == headers["X-UA-Permission-location"])
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

    @Test
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

        #expect(
            [
                AirshipEventType.appBackground.reportingName,
                AirshipEventType.appForeground.reportingName,
                AirshipEventType.appInit.reportingName,
                AirshipEventType.appInit.reportingName
            ] ==
            events.map { $0.type.reportingName }
        )
        #expect(
            [
                "app_background",
                "app_foreground",
                "app_foreground_init",
                "app_background_init"
            ] ==
            events.map { $0.body }
        )
        #expect([date, date, date, date] == events.map { $0.date })
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
        let eventType: AirshipEventType = switch(event.type) {
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
            state.conversionMetadata = metadata
            state.conversionSendID = sendID
        }
    }
}
