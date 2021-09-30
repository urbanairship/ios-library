/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class EventTest: XCTestCase {
    
    func testAppInitEvent() throws {
        let testAnalytics = TestAnalytics()
        testAnalytics.conversionSendID = "push ID"
        testAnalytics.conversionPushMetadata = "base64metadataString"
    
        let event = AppInitEvent.init(analytics: testAnalytics, push: { return EventTestPush() })
    
        let data = event.gatherData()
        
        XCTAssertEqual(event.eventType, "app_init")
        XCTAssertEqual(data["connection_type"] as! String, "wifi")
        XCTAssertEqual(data["push_id"] as! String, "push ID")
        XCTAssertEqual(data["metadata"] as! String, "base64metadataString")
        XCTAssertEqual(data["time_zone"] as! NSNumber, NSNumber(value: Double(NSTimeZone.default.secondsFromGMT())))
        let daylightSavings = NSTimeZone.default as NSTimeZone
        XCTAssertEqual(data["daylight_savings"] as! String, daylightSavings.isDaylightSavingTime ? "true" : "false")
        XCTAssertEqual(data["os_version"] as! String, UIDevice.current.systemVersion)
        XCTAssertEqual(data["lib_version"] as! String, AirshipVersion.get())
        XCTAssertEqual(data["foreground"] as! String, "true")
    }
   
    func testForegroundEvent() throws {
        let testAnalytics = TestAnalytics()
        testAnalytics.conversionSendID = "push ID"
        testAnalytics.conversionPushMetadata = "base64metadataString"
    
        let event = AppForegroundEvent.init(analytics: testAnalytics, push: { return EventTestPush() })
    
        let data = event.gatherData()
        
        XCTAssertEqual(event.eventType, "app_foreground")
        XCTAssertEqual(data["connection_type"] as! String, "wifi")
        XCTAssertEqual(data["push_id"] as! String, "push ID")
        XCTAssertEqual(data["metadata"] as! String, "base64metadataString")
        XCTAssertEqual(data["time_zone"] as! NSNumber, NSNumber(value: Double(NSTimeZone.default.secondsFromGMT())))
        let daylightSavings = NSTimeZone.default as NSTimeZone
        XCTAssertEqual(data["daylight_savings"] as! String, daylightSavings.isDaylightSavingTime ? "true" : "false")
        XCTAssertEqual(data["notification_types"] as! Array <String>, [])
        XCTAssertEqual(data["notification_authorization"] as! String, "not_determined")
        XCTAssertEqual(data["os_version"] as! String, UIDevice.current.systemVersion)
        XCTAssertEqual(data["lib_version"] as! String, AirshipVersion.get())
    }
    
    func testAppExitEvent() throws {
        let testAnalytics = TestAnalytics()
        testAnalytics.conversionSendID = "push ID"
        testAnalytics.conversionPushMetadata = "base64metadataString"
    
        let event = AppExitEvent.init(analytics: testAnalytics)
    
        let data = event.gatherData()
        
        XCTAssertEqual(event.eventType, "app_exit")
        XCTAssertEqual(data["connection_type"] as! String, "wifi")
        XCTAssertEqual(data["push_id"] as! String, "push ID")
        XCTAssertEqual(data["metadata"] as! String, "base64metadataString")
    }
     

    func testAppBackgroundEvent() throws {
        let testAnalytics = TestAnalytics()
        testAnalytics.conversionSendID = "push ID"
        testAnalytics.conversionPushMetadata = "base64metadataString"
    
        let event = AppBackgroundEvent.init(analytics: testAnalytics)
        
        XCTAssertEqual(event.eventType, "app_background")
    }
    
    func testDeviceRegistrationEvent() throws {
        
        let testChannel = TestChannel()
        testChannel.identifier = "someChannelID"
        let testPush = InternalPush()
        
        let dataStore = PreferenceDataStore(keyPrefix: UUID().uuidString)
        let privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)
      
        let event = DeviceRegistrationEvent.init(channel: testChannel, push: testPush, privacyManager: privacyManager)
        
        XCTAssertEqual(event.data["device_token"] as! String, "a12312ad")
        XCTAssertEqual(event.data["channel_id"] as! String, "someChannelID")
        XCTAssertEqual(event.eventType, "device_registration")
     }
    
    func testDeviceRegistrationEventWhenPushIsDisabled() throws {
        
        let testChannel = TestChannel()
        testChannel.identifier = "someChannelID"
        let testPush = InternalPush()
        
        let dataStore = PreferenceDataStore(keyPrefix: UUID().uuidString)
        let privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)
        privacyManager.disableFeatures(.push)
      
        let event = DeviceRegistrationEvent.init(channel: testChannel, push: testPush, privacyManager: privacyManager)
        
        XCTAssertNil(event.data["device_token"])
        XCTAssertEqual(event.data["channel_id"] as! String, "someChannelID")
        XCTAssertEqual(event.eventType, "device_registration")
     }
   
    func testPushReceived() throws {
        let notification: [AnyHashable : Any] = ["_":"push ID",
                                                 "_uamid":"rich push ID",
                                                 "com.urbanairship.metadata":"base64metadataString"]
        
        let event = PushReceivedEvent.init(notification: notification)
        
        XCTAssertEqual(event.data["push_id"] as! String, "push ID")
        XCTAssertEqual(event.data["metadata"] as! String, "base64metadataString")
        XCTAssertEqual(event.eventType, "push_received")
     }
    
    func testPushReceivedNoPushID() throws {
        let notification: [AnyHashable : Any] = ["_uamid":"rich push ID"]
        
        let event = PushReceivedEvent.init(notification: notification)
        
        XCTAssertEqual(event.data["push_id"] as! String, "MISSING_SEND_ID")
        XCTAssertEqual(event.eventType, "push_received")
     }
    
    func testScreenTracking() throws {
        let event = ScreenTrackingEvent.init(screen: "test_screen", previousScreen: "previous_screen", startTime: 0, stopTime: 1)
        
        XCTAssertEqual(event!.data["duration"] as! String, "1.000")
        XCTAssertEqual(event!.data["entered_time"] as! String, "0.000")
        XCTAssertEqual(event!.data["exited_time"] as! String, "1.000")
        XCTAssertEqual(event!.data["previous_screen"] as! String, "previous_screen")
        XCTAssertEqual(event!.data["screen"] as! String, "test_screen")
     }
    
    func testScreenValidation() throws {
        var screenName = "".padding(toLength: 255, withPad: "test_screen_name", startingAt: 0)
        var event = ScreenTrackingEvent.init(screen: screenName, previousScreen: nil, startTime: 0, stopTime: 1)
        
        XCTAssertEqual(event!.screen, screenName)
        
        screenName = "".padding(toLength: 256, withPad: "test_screen_name", startingAt: 0)
        event = ScreenTrackingEvent.init(screen: screenName, previousScreen: nil, startTime: 0, stopTime: 1)
        XCTAssertNil(event)
        
        screenName = ""
        event = ScreenTrackingEvent.init(screen: screenName, previousScreen: nil, startTime: 0, stopTime: 1)
        XCTAssertNil(event)
     }
    
    func testScreenStopTimeValidation() throws {
        var event = ScreenTrackingEvent.init(screen: "test_screen", previousScreen: nil, startTime: 0, stopTime: 0)
        XCTAssertNil(event)
        
        event = ScreenTrackingEvent.init(screen: "test_screen", previousScreen: nil, startTime: 1, stopTime: 0)
        XCTAssertNil(event)
        
        event = ScreenTrackingEvent.init(screen: "test_screen", previousScreen: nil, startTime: 0, stopTime: 1)
        XCTAssertNotNil(event)
     }
    
    func testBackgroundInitEmitsAppInitEvent() throws {
        let testAppState = InternalAppStateTracker()
        testAppState.state = .background
      
        let testEventManager = InternalEventManager()
        let dataStore = PreferenceDataStore(keyPrefix: UUID().uuidString)
        let config = RuntimeConfig(config: Config(), dataStore: dataStore)
        let channel = TestChannel()
        let locale = TestLocaleManager()
        let privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)
        let dispatcher = TestDispatcher()
        
        let analytics = Analytics(config: config, dataStore: dataStore, channel: channel, eventManager: testEventManager, notificationCenter: NotificationCenter(), date: DateUtils(), dispatcher: dispatcher, localeManager: locale, appStateTracker: testAppState, privacyManager: privacyManager)
        
        let event = testEventManager.events.first
        let eventType = event?.eventType
        XCTAssertEqual(eventType, "app_init")
        XCTAssertTrue(testEventManager.addEventCalled)
        
    }
    
    func testFirstTransitionToForegroundEmitsAppInit() throws {
        let testAppState = InternalAppStateTracker()
        testAppState.state = .inactive
      
        let testEventManager = InternalEventManager()
        let dataStore = PreferenceDataStore(keyPrefix: UUID().uuidString)
        let config = RuntimeConfig(config: Config(), dataStore: dataStore)
        let channel = TestChannel()
        let locale = TestLocaleManager()
        let privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)
        let dispatcher = TestDispatcher()
        let notificationCenter = NotificationCenter.default
        
        let analytics = Analytics(config: config, dataStore: dataStore, channel: channel, eventManager: testEventManager, notificationCenter: notificationCenter, date: DateUtils(), dispatcher: dispatcher, localeManager: locale, appStateTracker: testAppState, privacyManager: privacyManager)
        
        notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
       
        let event = testEventManager.events.first
        let eventType = event?.eventType
        XCTAssertEqual(eventType, "app_init")
        XCTAssertTrue(testEventManager.addEventCalled)
    }
    
    func testSubsequentTransitionToForegroundEmitsForegroundEvent() throws {
        let testAppState = InternalAppStateTracker()
        testAppState.state = .inactive
      
        let testEventManager = InternalEventManager()
        let dataStore = PreferenceDataStore(keyPrefix: UUID().uuidString)
        let config = RuntimeConfig(config: Config(), dataStore: dataStore)
        let channel = TestChannel()
        let locale = TestLocaleManager()
        let privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)
        let dispatcher = TestDispatcher()
        let notificationCenter = NotificationCenter.default
        
        let analytics = Analytics(config: config, dataStore: dataStore, channel: channel, eventManager: testEventManager, notificationCenter: notificationCenter, date: DateUtils(), dispatcher: dispatcher, localeManager: locale, appStateTracker: testAppState, privacyManager: privacyManager)
        
        notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
        notificationCenter.post(name: AppStateTracker.didTransitionToForeground, object: nil)
        
        var appForegroundEvent: InternalEventManager.TestEvent?
        for event in testEventManager.events {
            if event.eventType == "app_foreground" {
                appForegroundEvent = event
            }
        }
        XCTAssertEqual(appForegroundEvent?.eventType, "app_foreground")
        XCTAssertTrue(testEventManager.addEventCalled)
    }
    
    func testBackgroundBeforeForegroundEmitsAppInit() throws {
        let testAppState = InternalAppStateTracker()
        testAppState.state = .inactive
      
        let testEventManager = InternalEventManager()
        let dataStore = PreferenceDataStore(keyPrefix: UUID().uuidString)
        let config = RuntimeConfig(config: Config(), dataStore: dataStore)
        let channel = TestChannel()
        let locale = TestLocaleManager()
        let privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)
        let dispatcher = TestDispatcher()
        let notificationCenter = NotificationCenter.default
        
        let analytics = Analytics(config: config, dataStore: dataStore, channel: channel, eventManager: testEventManager, notificationCenter: notificationCenter, date: DateUtils(), dispatcher: dispatcher, localeManager: locale, appStateTracker: testAppState, privacyManager: privacyManager)
        
        notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)
        
        var appBackgroundEvent: InternalEventManager.TestEvent?
        for event in testEventManager.events {
            if event.eventType == "app_background" {
                appBackgroundEvent = event
            }
        }
        XCTAssertEqual(appBackgroundEvent?.eventType, "app_background")
        XCTAssertTrue(testEventManager.addEventCalled)
    }
    
    func testBackgroundAfterForegroundDoesNotEmitAppInit() throws {
        let testAppState = InternalAppStateTracker()
        testAppState.state = .active
      
        let testEventManager = InternalEventManager()
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)
        
        let event = testEventManager.events.first
        let eventType = event?.eventType
        XCTAssertNotEqual(eventType, "app_init")
    }
    
    /// Test that tracking event adds itself on background
    func testTrackingEventBackground() throws {
        let testAppState = InternalAppStateTracker()
        testAppState.state = .active
        
        let testEventManager = InternalEventManager()
        let dataStore = PreferenceDataStore(keyPrefix: UUID().uuidString)
        let config = RuntimeConfig(config: Config(), dataStore: dataStore)
        let channel = TestChannel()
        let locale = TestLocaleManager()
        let privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)
        let dispatcher = TestDispatcher()
        let notificationCenter = NotificationCenter.default
        
        let analytics = Analytics(config: config, dataStore: dataStore, channel: channel, eventManager: testEventManager, notificationCenter: notificationCenter, date: DateUtils(), dispatcher: dispatcher, localeManager: locale, appStateTracker: testAppState, privacyManager: privacyManager)
        analytics.trackScreen("test_screen")
        
        notificationCenter.post(name: AppStateTracker.didEnterBackgroundNotification, object: nil)
        
        var screenEvent: InternalEventManager.TestEvent?
        for event in testEventManager.events {
            if event.eventType == "screen_tracking" {
                screenEvent = event
            }
        }
        
        XCTAssertEqual(screenEvent?.eventType, "screen_tracking")
        XCTAssertEqual(screenEvent?.eventScreen, "test_screen")
        XCTAssertTrue(testEventManager.addEventCalled)
    }
    
    /// Test tracking event adds itself and is set to nil on terminate event.
    func testTrackingEventTerminate() throws {
        let testAppState = InternalAppStateTracker()
        testAppState.state = .active
        
        let testEventManager = InternalEventManager()
        let dataStore = PreferenceDataStore(keyPrefix: UUID().uuidString)
        let config = RuntimeConfig(config: Config(), dataStore: dataStore)
        let channel = TestChannel()
        let locale = TestLocaleManager()
        let privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)
        let dispatcher = TestDispatcher()
        let notificationCenter = NotificationCenter.default
        
        let analytics = Analytics(config: config, dataStore: dataStore, channel: channel, eventManager: testEventManager, notificationCenter: notificationCenter, date: DateUtils(), dispatcher: dispatcher, localeManager: locale, appStateTracker: testAppState, privacyManager: privacyManager)
        analytics.trackScreen("test_screen")
        
        notificationCenter.post(name: AppStateTracker.willTerminateNotification, object: nil)
        
        var screenEvent: InternalEventManager.TestEvent?
        for event in testEventManager.events {
            if event.eventType == "screen_tracking" {
                screenEvent = event
            }
        }
        
        XCTAssertEqual(screenEvent?.eventType, "screen_tracking")
        XCTAssertEqual(screenEvent?.eventScreen, "test_screen")
        XCTAssertTrue(testEventManager.addEventCalled)
    }
    
    /// Tests that starting a screen tracking event when one is already started adds the event with the correct start and stop times
    func testStartTrackScreenAddEvent() throws {
        let testAppState = InternalAppStateTracker()
        testAppState.state = .active
        
        let testEventManager = InternalEventManager()
        let dataStore = PreferenceDataStore(keyPrefix: UUID().uuidString)
        let config = RuntimeConfig(config: Config(), dataStore: dataStore)
        let channel = TestChannel()
        let locale = TestLocaleManager()
        let privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: .all)
        let date = UATestDate(offset: 0, dateOverride: Date(timeIntervalSince1970: 0))
        let dispatcher = TestDispatcher()
        let notificationCenter = NotificationCenter.default
        
        let analytics = Analytics(config: config, dataStore: dataStore, channel: channel, eventManager: testEventManager, notificationCenter: notificationCenter, date: date, dispatcher: dispatcher, localeManager: locale, appStateTracker: testAppState, privacyManager: privacyManager)
        
        analytics.trackScreen("first_screen")
        date.offset = 20
        analytics.trackScreen("second_screen")
        
        var screenEvent: InternalEventManager.TestEvent?
        for event in testEventManager.events {
            if event.eventType == "screen_tracking" {
                screenEvent = event
            }
        }
        
        XCTAssertEqual(screenEvent?.eventType, "screen_tracking")
        XCTAssertEqual(screenEvent?.startTime ?? 0, 0.0, accuracy: 1.0)
        XCTAssertEqual(screenEvent?.stopTime ?? 0, 20.0, accuracy: 1.0)
        XCTAssertTrue(testEventManager.addEventCalled)
    }
}

fileprivate class InternalAppStateTracker: AppStateTrackerProtocol {
    func applicationDidBecomeActive() {
        self.state = .active
    }
    
    func applicationWillEnterForeground() {
        
        
    }
    
    func applicationDidEnterBackground() {
        self.state = .background
    }
    
    func applicationWillResignActive() {}
    
    func applicationWillTerminate() {}
    
    var state: ApplicationState = .active
}

fileprivate class InternalEventManager: EventManagerProtocol {
    var uploadsEnabled: Bool = false
    
    var delegate: EventManagerDelegate?
    
    func deleteAllEvents() {}
    
    func scheduleUpload() {}
    
    var events: [TestEvent] = []
    
    struct TestEvent : Codable {
        var eventType = ""
        var eventScreen = ""
        var startTime: Double? = 0.0
        var stopTime: Double? = 0.0
    }
    
    var addEventCalled = false
    
    func add(_ event: Event, eventID: String, eventDate: Date, sessionID: String) {
        self.addEventCalled = true
        
        var testEvent = TestEvent()
        
        testEvent.eventType = event.eventType
      
        if let screenTrackEvent = event as? ScreenTrackingEvent {
            testEvent.eventScreen = screenTrackEvent.screen
            testEvent.startTime = screenTrackEvent.startTime
            testEvent.stopTime = screenTrackEvent.stopTime
        }
        events.append(testEvent)
    }
}

fileprivate class EventTestPush: PushProtocol {
    var deviceToken: String?
    
    var combinedCategories: Set<UNNotificationCategory> = []
    
    var backgroundPushNotificationsEnabled = true
    
    var userPushNotificationsEnabled = true
    
    var extendedPushNotificationPermissionEnabled = false
    
    var notificationOptions: UANotificationOptions = [.alert, .sound, .badge]
    
    var customCategories: Set<UNNotificationCategory> = []
    
    var accengageCategories: Set<UNNotificationCategory> = []
    
    var requireAuthorizationForDefaultCategories = false
    
    var pushNotificationDelegate: PushNotificationDelegate?
    
    var registrationDelegate: RegistrationDelegate?
    
    var launchNotificationResponse: UNNotificationResponse?
    
    var authorizedNotificationSettings: UAAuthorizedNotificationSettings = []
    
    var authorizationStatus: UAAuthorizationStatus = .notDetermined
    
    var userPromptedForNotifications = false
    
    var defaultPresentationOptions: UNNotificationPresentationOptions = [.alert, .sound, .badge]
    
    var badgeNumber: Int = 0
}

fileprivate final class InternalPush: InternalPushProtocol {
    var deviceToken: String? = "a12312ad"
    
    func updateAuthorizedNotificationTypes() {}
    
    func didRegisterForRemoteNotifications(_ deviceToken: Data) {}
    
    func didFailToRegisterForRemoteNotifications(_ error: Error) {}
    
    func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], isForeground: Bool, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {}
    
    func presentationOptionsForNotification(_ notification: UNNotification) -> UNNotificationPresentationOptions {
        return []
    }
    
    func didReceiveNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void) {}
    
    var combinedCategories: Set<UNNotificationCategory> = Set()
}
