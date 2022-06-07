import XCTest

@testable
import AirshipCore

class AnalyticsTest: XCTestCase {

    private let appStateTracker = TestAppStateTracker()
    private let eventManager = TestEventManager()
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let config = Config()
    private let channel = TestChannel()
    private let locale = TestLocaleManager()
    private let permissionsManager = PermissionsManager()
    private let dispatcher = TestDispatcher()
    private let notificationCenter = NotificationCenter()
    private let date = UATestDate()

    private var privacyManager: PrivacyManager!
    private var analytics: Analytics!


    override func setUpWithError() throws {
        self.privacyManager = PrivacyManager(dataStore: dataStore,
                                             defaultEnabledFeatures: .all,
                                             notificationCenter: notificationCenter)

        self.analytics = Analytics(config: RuntimeConfig(config: config, dataStore: dataStore),
                                   dataStore: dataStore,
                                   channel: channel,
                                   eventManager: eventManager,
                                   notificationCenter: notificationCenter,
                                   date: date,
                                   dispatcher: dispatcher,
                                   localeManager: locale,
                                   appStateTracker: appStateTracker,
                                   privacyManager: privacyManager,
                                   permissionsManager: permissionsManager)

    }

    func testFirstTransitionToForegroundEmitsAppInit() throws {
        self.appStateTracker.currentState = .inactive
        self.analytics.airshipReady()
        self.notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)

        let event = self.eventManager.events.last
        XCTAssertEqual("app_init", event?.eventType)
    }

    func testSubsequentTransitionToForegroundEmitsForegroundEvent() throws {
        self.appStateTracker.currentState = .inactive

        self.notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
        self.notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)

        let event = self.eventManager.events.last
        XCTAssertEqual("app_foreground", event?.eventType)
    }

    func testBackgroundBeforeForegroundEmitsAppInit() throws {
        self.appStateTracker.currentState = .inactive
        self.notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)

        let event = self.eventManager.events.last
        XCTAssertEqual("app_background", event?.eventType)
    }

    func testBackgroundAfterForegroundDoesNotEmitAppInit() throws {
        self.appStateTracker.currentState = .active
        self.notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)

        let event = self.eventManager.events.last
        XCTAssertNotEqual("app_init", event?.eventType)
    }

    func testScreenTrackingBackground() throws {
        self.analytics.trackScreen("test_screen")

        XCTAssertNil(self.eventManager.events.last)
        self.notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)

        let screenEvent = self.eventManager.events.first?.event as! ScreenTrackingEvent
        XCTAssertEqual("test_screen", screenEvent.screen)
    }

    func testScreenTrackingTerminate() throws {
        self.analytics.trackScreen("test_screen")

        XCTAssertNil(self.eventManager.events.last)
        self.notificationCenter.post(name: AppStateTracker.willTerminateNotification, object: nil)

        let screenEvent = self.eventManager.events.first?.event as! ScreenTrackingEvent
        XCTAssertEqual("test_screen", screenEvent.screen)
    }

    func testScreenTrackingNextScreen() throws {
        self.analytics.trackScreen("test_screen")

        XCTAssertNil(self.eventManager.events.last)
        self.analytics.trackScreen("another_screen")

        let screenEvent = self.eventManager.events.first?.event as! ScreenTrackingEvent
        XCTAssertEqual("test_screen", screenEvent.screen)
    }

    func testDisablingAnalytics() throws {
        XCTAssertTrue(self.eventManager.uploadsEnabled)
        XCTAssertFalse(self.eventManager.deleteAllEventsCalled)

        self.privacyManager.disableFeatures(.analytics)

        XCTAssertFalse(self.eventManager.uploadsEnabled)
        XCTAssertTrue(self.eventManager.deleteAllEventsCalled)
    }

    func testDisablingAnalyticsComponent() throws {
        XCTAssertTrue(self.eventManager.uploadsEnabled)
        XCTAssertFalse(self.eventManager.deleteAllEventsCalled)

        self.analytics.isComponentEnabled = false

        XCTAssertFalse(self.eventManager.uploadsEnabled)
        XCTAssertTrue(self.eventManager.deleteAllEventsCalled)
    }

    func testEnableAnalytics() throws {
        self.privacyManager.disableFeatures(.analytics)
        XCTAssertFalse(self.eventManager.uploadsEnabled)

        self.privacyManager.enableFeatures(.analytics)
        XCTAssertTrue(self.eventManager.uploadsEnabled)
    }

    func testAddEvent() throws {
        self.analytics.addEvent(ValidEvent())
        XCTAssertFalse(self.eventManager.events.isEmpty)
    }

    func testAddInvalidEvent() throws {
        self.analytics.addEvent(InvalidEvent())
        XCTAssertTrue(self.eventManager.events.isEmpty)
    }

    func testAddEventAnalyticsDisabled() throws {
        self.privacyManager.disableFeatures(.analytics)
        self.analytics.addEvent(ValidEvent())
        XCTAssertTrue(self.eventManager.events.isEmpty)
    }

    func testAssociateDeviceIdentifiers() throws {
        let ids = AssociatedIdentifiers(dictionary: ["neat": "id"])
        self.analytics.associateDeviceIdentifiers(ids)

        let event = self.eventManager.events.first?.event as! AssociateIdentifiersEvent
        XCTAssertEqual(["neat": "id"] as NSDictionary, event.data as NSDictionary)
    }

    func testAssociateDeviceIdentifiersAnalyticsDisbaled() throws {
        self.privacyManager.disableFeatures(.analytics)

        let ids = AssociatedIdentifiers(dictionary: ["neat": "id"])
        self.analytics.associateDeviceIdentifiers(ids)

        XCTAssertTrue(self.eventManager.events.isEmpty)
    }

    func testAssociateDeviceIdentifiersDedupe() throws {
        let ids = AssociatedIdentifiers(dictionary: ["neat": "id"])
        self.analytics.associateDeviceIdentifiers(ids)
        self.eventManager.events.removeAll()

        self.analytics.associateDeviceIdentifiers(ids)
        self.analytics.associateDeviceIdentifiers(ids)
        self.analytics.associateDeviceIdentifiers(ids)
        XCTAssertTrue(self.eventManager.events.isEmpty)
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
            "_": "some conversionSendID"
        ]
        self.analytics.launched(fromNotification: notification)
        XCTAssertEqual("some conversionSendID", self.analytics.conversionSendID)
    }

    func testConversationMetadata() throws {
        let notification: [String: AnyHashable] = [
            "aps": ["alert": "neat"],
            "_": "some conversionSendID",
            "com.urbanairship.metadata": "some metadata"
        ]

        self.analytics.launched(fromNotification: notification)
        XCTAssertEqual("some metadata", self.analytics.conversionPushMetadata)
    }

    func testLaunchedFromSilentPush() throws {
        let notification: [String: AnyHashable] = [
            "aps": ["neat": "neat"],
            "_": "some conversionSendID",
            "com.urbanairship.metadata": "some metadata"
        ]

        self.analytics.launched(fromNotification: notification)
        XCTAssertNil(self.analytics.conversionPushMetadata)
        XCTAssertNil(self.analytics.conversionSendID)
    }

    func testForwardScreenTracking() throws {
        let eventAdded = self.expectation(description: "Event added")
        self.notificationCenter.addObserver(forName: Analytics.screenTracked,
                                            object: nil,
                                            queue: nil) { notification in

            XCTAssertEqual(["screen": "some screen"], notification.userInfo as? [String: String])
            eventAdded.fulfill()
        }

        self.analytics.trackScreen("some screen")

        self.wait(for: [eventAdded], timeout: 1)
    }

    func testForwardRegionEvents() throws {
        let event = RegionEvent(regionID: "foo", source: "test", boundaryEvent: .enter)!

        let eventAdded = self.expectation(description: "Event added")
        self.notificationCenter.addObserver(forName: Analytics.regionEventAdded,
                                            object: nil,
                                            queue: nil) { notification in

            XCTAssertEqual(event, notification.userInfo?["event"] as? RegionEvent)
            eventAdded.fulfill()
        }

        self.analytics.addEvent(event)
        self.wait(for: [eventAdded], timeout: 1)
    }

    func testForwardCustomEvents() throws {
        let event = CustomEvent(name: "foo")

        let eventAdded = self.expectation(description: "Event added")
        self.notificationCenter.addObserver(forName: Analytics.customEventAdded,
                                            object: nil,
                                            queue: nil) { notification in

            XCTAssertEqual(event, notification.userInfo?["event"] as? CustomEvent)
            eventAdded.fulfill()
        }

        self.analytics.addEvent(event)
        self.wait(for: [eventAdded], timeout: 1)
    }

    func testSDKExtensions() throws {
        self.analytics.registerSDKExtension(.cordova, version: "1.2.3")
        self.analytics.registerSDKExtension(.unity, version:"5,.6,.7,,,")

        let headersFetched = self.expectation(description: "Headers fetched")
        self.analytics.analyticsHeaders { headers in
            XCTAssertEqual("cordova:1.2.3, unity:5.6.7", headers["X-UA-Frameworks"])
            headersFetched.fulfill()
        }

        self.wait(for: [headersFetched], timeout: 1)
    }

    func testAnalyticsHeaders() throws {
        self.channel.identifier = "someChannelID"
        self.locale.currentLocale = Locale(identifier: "en-US-POSIX")

        let expected = [
            "X-UA-Channel-ID": "someChannelID",
            "X-UA-Timezone": NSTimeZone.default.identifier,
            "X-UA-Locale-Language": "en",
            "X-UA-Locale-Country": "US",
            "X-UA-Locale-Variant": "POSIX",
            "X-UA-Device-Family": UIDevice.current.systemName,
            "X-UA-OS-Version":  UIDevice.current.systemVersion,
            "X-UA-Device-Model": Utils.deviceModelName(),
            "X-UA-Lib-Version": AirshipVersion.get(),
            "X-UA-App-Key": self.config.appKey,
            "X-UA-Package-Name": Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String] as? String,
            "X-UA-Package-Version": Utils.bundleShortVersionString() ?? ""
        ]

        let headersFetched = self.expectation(description: "Headers fetched")
        self.analytics.analyticsHeaders { headers in
            XCTAssertEqual(expected, headers)
            headersFetched.fulfill()
        }

        self.wait(for: [headersFetched], timeout: 1)
    }

    func testAnalyticsHeaderExtension() throws {
        self.analytics.add {
            return ["neat": "story"]
        }

        let headersFetched = self.expectation(description: "Headers fetched")
        self.analytics.analyticsHeaders { headers in
            XCTAssertEqual("story", headers["neat"])
            headersFetched.fulfill()
        }

        self.wait(for: [headersFetched], timeout: 1)
    }

    func testPermissionHeaders() throws {
        let testPushDelegate = TestPermissionsDelegate()
        testPushDelegate.permissionStatus = .denied
        self.permissionsManager.setDelegate(testPushDelegate, permission: .postNotifications)

        let testLocationDelegate = TestPermissionsDelegate()
        testLocationDelegate.permissionStatus = .granted
        self.permissionsManager.setDelegate(testLocationDelegate, permission: .location)

        let headersFetched = self.expectation(description: "Headers fetched")
        self.analytics.analyticsHeaders { headers in
            XCTAssertEqual("denied", headers["X-UA-Permission-post_notifications"])
            XCTAssertEqual("granted", headers["X-UA-Permission-location"])
            headersFetched.fulfill()
        }

        self.wait(for: [headersFetched], timeout: 1)
    }

}

class TestEventManager: EventManagerProtocol {
    var uploadsEnabled: Bool = false
    var deleteAllEventsCalled = false

    var delegate: EventManagerDelegate?

    func deleteAllEvents() {
        self.deleteAllEventsCalled = true
    }

    func scheduleUpload() {}

    var events: [TestEvent] = []

    struct TestEvent {
        let eventType: String
        let event: Event
        let sessionID: String
        let eventID: String
    }

    func add(_ event: Event, eventID: String, eventDate: Date, sessionID: String) {
        let testEvent = TestEvent(eventType: event.eventType,
                                  event: event,
                                  sessionID: sessionID,
                                  eventID: eventID)
        events.append(testEvent)
    }
}

class InvalidEvent: NSObject, Event {
    var data: [AnyHashable : Any] = [:]
    var eventType: String = "invliad"
    var priority: EventPriority = .normal

    func isValid() -> Bool {
        return false
    }
}

class ValidEvent: NSObject, Event {
    var data: [AnyHashable : Any] = [:]
    var eventType: String = "valid"
    var priority: EventPriority = .normal

    func isValid() -> Bool {
        return true
    }
}

