/* Copyright Airship and Contributors */

import XCTest
import Combine

@testable import AirshipCore

class AirshipEventsTest: XCTestCase {

    @MainActor
    func testForegroundAppInitEvent() throws {
        let sessionEvent = SessionEvent(
            type: .foregroundInit,
            date: Date(),
            sessionState: SessionState(
                conversionSendID: UUID().uuidString,
                conversionMetadata: UUID().uuidString
            )
        )

        let expectedBody = """
        {
           "notification_types": [],
           "notification_authorization": "not_determined",
           "time_zone": \(TimeZone.current.secondsFromGMT()),
           "daylight_savings": "\(TimeZone.current.isDaylightSavingTime().toString())",
           "package_version": "\(AirshipUtils.bundleShortVersionString()!)",
           "foreground": "true",
           "os_version": "\(UIDevice.current.systemVersion)",
           "lib_version": "\(AirshipVersion.version)",
           "push_id": "\(sessionEvent.sessionState.conversionSendID!)",
           "metadata": "\(sessionEvent.sessionState.conversionMetadata!)"
        }
        """

        let event = AirshipEvents.sessionEvent(
            sessionEvent: sessionEvent,
            push: EventTestPush()
        )

        XCTAssertEqual(event.eventType.reportingName, "app_init")
        XCTAssertEqual(event.priority, .normal)
        XCTAssertEqual(try AirshipJSON.from(json: expectedBody), event.eventData)
    }

    @MainActor
    func testBackgroundAppInitEvent() throws {
        let sessionEvent = SessionEvent(
            type: .backgroundInit,
            date: Date(),
            sessionState: SessionState(
                conversionSendID: UUID().uuidString,
                conversionMetadata: UUID().uuidString
            )
        )

        let expectedBody = """
        {
           "notification_types": [],
           "notification_authorization": "not_determined",
           "time_zone": \(TimeZone.current.secondsFromGMT()),
           "daylight_savings": "\(TimeZone.current.isDaylightSavingTime().toString())",
           "package_version": "\(AirshipUtils.bundleShortVersionString()!)",
           "foreground": "false",
           "os_version": "\(UIDevice.current.systemVersion)",
           "lib_version": "\(AirshipVersion.version)",
           "push_id": "\(sessionEvent.sessionState.conversionSendID!)",
           "metadata": "\(sessionEvent.sessionState.conversionMetadata!)"
        }
        """

        let event = AirshipEvents.sessionEvent(
            sessionEvent: sessionEvent,
            push: EventTestPush()
        )

        XCTAssertEqual(event.eventType.reportingName, "app_init")
        XCTAssertEqual(event.priority, .normal)
        XCTAssertEqual(try AirshipJSON.from(json: expectedBody), event.eventData)
    }

    @MainActor
    func testAppForegroundEvent() throws {
        let sessionEvent = SessionEvent(
            type: .foreground,
            date: Date(),
            sessionState: SessionState(
                conversionSendID: UUID().uuidString,
                conversionMetadata: UUID().uuidString
            )
        )

        let expectedBody = """
        {
           "notification_types": [],
           "notification_authorization": "not_determined",
           "time_zone": \(TimeZone.current.secondsFromGMT()),
           "daylight_savings": "\(TimeZone.current.isDaylightSavingTime().toString())",
           "package_version": "\(AirshipUtils.bundleShortVersionString()!)",
           "os_version": "\(UIDevice.current.systemVersion)",
           "lib_version": "\(AirshipVersion.version)",
           "push_id": "\(sessionEvent.sessionState.conversionSendID!)",
           "metadata": "\(sessionEvent.sessionState.conversionMetadata!)"
        }
        """

        let event = AirshipEvents.sessionEvent(
            sessionEvent: sessionEvent,
            push: EventTestPush()
        )

        XCTAssertEqual(event.eventType.reportingName, "app_foreground")
        XCTAssertEqual(event.priority, .normal)
        XCTAssertEqual(try AirshipJSON.from(json: expectedBody), event.eventData)
    }

    @MainActor
    func testAppBackgroundEvent() throws {
        let sessionEvent = SessionEvent(
            type: .background,
            date: Date(),
            sessionState: SessionState(
                conversionSendID: UUID().uuidString,
                conversionMetadata: UUID().uuidString
            )
        )

        let expectedBody = """
        {
           "push_id": "\(sessionEvent.sessionState.conversionSendID!)",
           "metadata": "\(sessionEvent.sessionState.conversionMetadata!)"
        }
        """

        let event = AirshipEvents.sessionEvent(
            sessionEvent: sessionEvent,
            push: EventTestPush()
        )

        XCTAssertEqual(event.eventType.reportingName, "app_background")
        XCTAssertEqual(event.priority, .normal)
        XCTAssertEqual(try AirshipJSON.from(json: expectedBody), event.eventData)
    }

    func testScreenTracking() throws {
        let expectedBody = """
        {
           "screen": "test_screen",
           "previous_screen": "previous_screen",
           "duration": "1.000",
           "exited_time": "1.000",
           "entered_time": "0.000"
        }
        """

        let event = try AirshipEvents.screenTrackingEvent(
            screen: "test_screen",
            previousScreen: "previous_screen",
            startDate: Date(timeIntervalSince1970: 0),
            duration: 1
        )

        XCTAssertEqual(event.eventType.reportingName, "screen_tracking")
        XCTAssertEqual(event.priority, .normal)
        XCTAssertEqual(try AirshipJSON.from(json: expectedBody), event.eventData)
    }


    func testScreenValidation() throws {
        var screenName = ""
            .padding(
                toLength: 255,
                withPad: "test_screen_name",
                startingAt: 0
            )

        _ = try AirshipEvents.screenTrackingEvent(
            screen: screenName,
            previousScreen: nil,
            startDate: Date(),
            duration: 1
        )

        screenName = ""
            .padding(
                toLength: 256,
                withPad: "test_screen_name",
                startingAt: 0
            )

        do {
            _ = try AirshipEvents.screenTrackingEvent(
                screen: screenName,
                previousScreen: nil,
                startDate: Date(),
                duration: 1
            )
            XCTFail()
        } catch {}


        do {
            _ = try AirshipEvents.screenTrackingEvent(
                screen: "",
                previousScreen: nil,
                startDate: Date(),
                duration: 1
            )
            XCTFail()
        } catch {}
    }


    func testInstallAttributeTest() throws {
        let expectedBody = """
        {
           "app_store_purchase_date": "100.000",
           "app_store_ad_impression_date": "99.000",
        }
        """

        let event = AirshipEvents.installAttirbutionEvent(
            appPurchaseDate: Date(timeIntervalSince1970: 100.0),
            iAdImpressionDate: Date(timeIntervalSince1970: 99.0)
        )
        
        XCTAssertEqual(event.eventType.reportingName, "install_attribution")
        XCTAssertEqual(event.priority, .normal)
        XCTAssertEqual(try AirshipJSON.from(json: expectedBody), event.eventData)
    }

    func testInstallAttributeNoDatesTest() throws {
        let expectedBody = """
        {
        }
        """

        let event = AirshipEvents.installAttirbutionEvent()

        XCTAssertEqual(event.eventType.reportingName, "install_attribution")
        XCTAssertEqual(event.priority, .normal)
        XCTAssertEqual(try AirshipJSON.from(json: expectedBody), event.eventData)
    }

    func testInteractiveNotificationEventTest() throws {

        let expectedBody = """
        {
           "foreground": "true",
           "button_id": "action_identifier",
           "button_description": "action_title",
           "button_group": "category_id",
           "send_id": "send ID",
           "user_input": "some response text"
        }
        """
        
        let event = AirshipEvents.interactiveNotificationEvent(
            action: UNNotificationAction(
                identifier: "action_identifier",
                title: "action_title",
                options: .foreground
            ),
            category: "category_id",
            notification: [
                "_": "send ID",
                "aps": [
                    "alert": "sample alert!",
                    "badge": 2,
                    "sound": "cat",
                    "category": "category_id"
                ]
            ],
            responseText: "some response text"
        )

        XCTAssertEqual(event.eventType.reportingName, "interactive_notification_action")
        XCTAssertEqual(event.priority, .high)
        XCTAssertEqual(try AirshipJSON.from(json: expectedBody), event.eventData)
    }
}

private final class EventTestPush: AirshipPushProtocol, @unchecked Sendable {
    var onAPNSRegistrationFinished: (@MainActor @Sendable (AirshipCore.APNSRegistrationResult) -> Void)?
    
    var onNotificationRegistrationFinished: (@MainActor @Sendable (AirshipCore.NotificationRegistrationResult) -> Void)?
    
    var onNotificationAuthorizedSettingsDidChange: (@MainActor @Sendable (AirshipCore.AirshipAuthorizedNotificationSettings) -> Void)?
    

    var quietTime: QuietTimeSettings?
    

    func enableUserPushNotifications() async -> Bool {
        return true
    }

    func enableUserPushNotifications(fallback: PromptPermissionFallback) async -> Bool {
        return true
    }


    func setBadgeNumber(_ newBadgeNumber: Int) async {

    }

    func resetBadge() async {

    }

    var autobadgeEnabled: Bool = false

    var timeZone: NSTimeZone?

    var quietTimeEnabled: Bool = false

    func setQuietTimeStartHour(_ startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {

    }

    var notificationStatusPublisher: AnyPublisher<AirshipCore.AirshipNotificationStatus, Never> {
        fatalError("not implemented")
    }

    var notificationStatus: AirshipCore.AirshipNotificationStatus {
        fatalError("not implemented")
    }
    
    let notificationStatusUpdates: AsyncStream<AirshipNotificationStatus>
    let statusUpdateContinuation: AsyncStream<AirshipNotificationStatus>.Continuation

    var isPushNotificationsOptedIn: Bool = false

    var deviceToken: String?

    var combinedCategories: Set<UNNotificationCategory> = []

    var backgroundPushNotificationsEnabled = true

    var userPushNotificationsEnabled = true

    var extendedPushNotificationPermissionEnabled = false

    var requestExplicitPermissionWhenEphemeral = false

    var notificationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]

    var customCategories: Set<UNNotificationCategory> = []

    var accengageCategories: Set<UNNotificationCategory> = []

    var requireAuthorizationForDefaultCategories = false

    var pushNotificationDelegate: PushNotificationDelegate?

    var registrationDelegate: RegistrationDelegate?

    var launchNotificationResponse: UNNotificationResponse?

    var authorizedNotificationSettings: AirshipAuthorizedNotificationSettings = []

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var userPromptedForNotifications = false

    var defaultPresentationOptions: UNNotificationPresentationOptions = [
        .list, .sound, .badge,
    ]

    var badgeNumber: Int = 0

    // Notification callbacks
    var onForegroundNotificationReceived: (@MainActor @Sendable ([AnyHashable: Any]) async -> Void)?

#if !os(watchOS)
    var onBackgroundNotificationReceived: (@MainActor @Sendable ([AnyHashable: Any]) async -> UIBackgroundFetchResult)?
#else
    var onBackgroundNotificationReceived: (@MainActor @Sendable ([AnyHashable: Any]) async -> WKBackgroundFetchResult)?
#endif

#if !os(tvOS)
    var onNotificationResponseReceived: (@MainActor @Sendable (UNNotificationResponse) async -> Void)?
#endif

    var onExtendPresentationOptions: (@MainActor @Sendable (UNNotificationPresentationOptions, UNNotification) async -> UNNotificationPresentationOptions)?

    init() {
        (self.notificationStatusUpdates, self.statusUpdateContinuation) = AsyncStream<AirshipNotificationStatus>.airshipMakeStreamWithContinuation()
    }
}

private final class InternalPush: InternalPushProtocol {
    
    var deviceToken: String? = "a12312ad"

    func dispatchUpdateAuthorizedNotificationTypes() {}

    func didRegisterForRemoteNotifications(_ deviceToken: Data) {}

    func didFailToRegisterForRemoteNotifications(_ error: Error) {}

    func didReceiveRemoteNotification(
        _ userInfo: [AnyHashable: Any],
        isForeground: Bool
    ) async -> any Sendable {
        return 0
    }

    func presentationOptionsForNotification(
        _ notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return []
    }

    func didReceiveNotificationResponse(
        _ response: UNNotificationResponse
    ) async {}

    var combinedCategories: Set<UNNotificationCategory> = Set()
}

fileprivate extension TimeInterval {
    func toString() -> String {
        String(
            format: "%0.3f",
            self
        )
    }
}

fileprivate extension Bool {
    func toString() -> String {
        return self ? "true" : "false"
    }
}
