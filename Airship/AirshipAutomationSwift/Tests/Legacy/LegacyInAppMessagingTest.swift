/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomationSwift
@testable import AirshipCore

final class LegacyInAppMessagingTest: XCTestCase {
    
    private let analytics = TestLegacyAnalytics()
    private let engine = TestAutomationEngine()
    private let datastore = PreferenceDataStore(appKey: UUID().uuidString)
    private let date = UATestDate(offset: 0, dateOverride: Date())

    private var subject: LegacyInAppMessaging!

    override func setUp() {
        createSubject()
    }
    
    private func createSubject() {
        subject = LegacyInAppMessaging(
            analytics: analytics,
            dataStore: datastore,
            automationEngine: engine,
            date: date
        )
    }
    
    func testOldDataCleanedUpOnInit() {
        
        let keys = ["UAPendingInAppMessage", "UAAutoDisplayInAppMessageDataStoreKey", "UALastDisplayedInAppMessageID"]
        
        keys.forEach { key in
            datastore.setObject("\(key)-test-value", forKey: key)
        }
        
        keys.forEach { key in
            XCTAssert(datastore.keyExists(key))
        }
        
        createSubject()
        
        keys.forEach { key in
            XCTAssertFalse(datastore.keyExists(key))
        }
    }

    func testPendingMessageStorage() {
        XCTAssertNil(subject.pendingMessageId)
        
        subject.pendingMessageId = "message-id"
        XCTAssertEqual("message-id", subject.pendingMessageId)
    }
    
    func testAsapFlagStorage() async {
        var value = await subject.displayASAPEnabled
        XCTAssertTrue(value)
        
        await MainActor.run { [messaging = self.subject!] in
            messaging.displayASAPEnabled = false
        }
        
        value = await subject.displayASAPEnabled
        XCTAssertFalse(value)
    }
    
    func testNotificationResponseCancelsPendingMessage() async throws {
        let pendingMessageId = "pending"
        
        XCTAssertNil(subject.pendingMessageId)
        XCTAssertNil(engine.lastCancelledScheduleId)
        
        subject.pendingMessageId = pendingMessageId
        
        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": pendingMessageId
        ])
        
        let expectation = XCTestExpectation(description: "processing notification")
        
        subject.receivedNotificationResponse(response) {
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5)
        
        XCTAssertEqual(pendingMessageId, engine.lastCancelledScheduleId)
        XCTAssertNil(subject.pendingMessageId)
    }

    func testNotificationResponseRecordsDirectOpen() async throws {
        let pendingMessageId = "pending"
        subject.pendingMessageId = pendingMessageId

        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": pendingMessageId
        ])

        let expectation = XCTestExpectation(description: "processing notification")

        subject.receivedNotificationResponse(response) {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5)

        XCTAssertEqual([pendingMessageId], self.analytics.directOpen)
    }

    func testNotificationResponseDoesNothingOnIdMismatch() async throws {
        
        XCTAssertNil(subject.pendingMessageId)
        XCTAssertNil(engine.lastCancelledScheduleId)
        
        subject.pendingMessageId = "mismatched"
        
        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": "pendingMessageId"
        ])
        
        let expectation = XCTestExpectation(description: "processing notification")
        
        subject.receivedNotificationResponse(response) {
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5)
        
        XCTAssertEqual("mismatched", subject.pendingMessageId)
        XCTAssertNil(engine.lastCancelledScheduleId)
    }
    
    func testNotificationResponseDoesNothingIfNoPending() async throws {
        
        XCTAssertNil(subject.pendingMessageId)
        XCTAssertNil(engine.lastCancelledScheduleId)
        
        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": "pendingMessageId"
        ])
        
        let expectation = XCTestExpectation(description: "processing notification")
        
        subject.receivedNotificationResponse(response) {
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5)
        
        XCTAssertNil(subject.pendingMessageId)
        XCTAssertNil(engine.lastCancelledScheduleId)
    }
    
    func testReceiveRemoteNotificationSchedulesMessageWithDefaults() async throws {
        let messageId = "test-id"
        let payload = [
            "identifier": messageId,
            "type": "banner",
            "alert": "test alert"
        ]
        
        XCTAssertNil(engine.lastCancelledScheduleId)
        XCTAssert(engine.schedules.isEmpty)
        
        let expection = XCTestExpectation(description: "schedule legacy message")
        
        subject.pendingMessageId = "some-pending"
        
        subject.receivedRemoteNotification(["com.urbanairship.in_app": payload]) { result in
            XCTAssertEqual(UIBackgroundFetchResult.noData, result)
            expection.fulfill()
        }
        
        await fulfillment(of: [expection], timeout: 5)

        let schedule = try XCTUnwrap(engine.schedules.first)
        
        XCTAssertEqual("some-pending", engine.lastCancelledScheduleId)
        XCTAssertEqual(messageId, subject.pendingMessageId)
        
        XCTAssertEqual(messageId, schedule.identifier)
        XCTAssertEqual(1, schedule.triggers.count)
        
        let trigger = try XCTUnwrap(schedule.triggers.first)
        XCTAssertEqual(1.0, trigger.goal)
        XCTAssertNil(trigger.predicate)
        XCTAssertEqual(AutomationTriggerType.activeSession, trigger.type)
        
        XCTAssertEqual(date.now, schedule.created)
        let timeDiff = 60 * 60 * 24 * 30 - (schedule.end?.timeIntervalSince(date.now) ?? 0)
        XCTAssert(fabs(timeDiff) < 10)
        XCTAssertNil(schedule.campaigns)
        XCTAssertNil(schedule.messageType)
        
        let inAppMessage: InAppMessage
        switch schedule.data {
        case .inAppMessage(let message):
            inAppMessage = message
        default:
            fatalError("unsupported schedule data")
        }
        
        XCTAssertEqual("test alert", inAppMessage.name)
        XCTAssertEqual(InAppMessageSource.legacyPush, inAppMessage.source)
        XCTAssertNil(inAppMessage.extras)
        
        let banner: InAppMessageDisplayContent.Banner
        switch inAppMessage.displayContent {
        case .banner(let model):
            banner = model
        default:
            fatalError("unsupported display content")
        }
        
        XCTAssertEqual("test alert", banner.body?.text)
        XCTAssertEqual("#1C1C1C", banner.body?.color?.hexColorString)
        XCTAssertEqual(InAppMessageButtonLayoutType.seperate, banner.buttonLayoutType)
        XCTAssertEqual("#FFFFFF", banner.backgroundColor?.hexColorString)
        XCTAssertEqual("#1C1C1C", banner.dismissButtonColor?.hexColorString)
        XCTAssertEqual(2, banner.borderRadius)
        XCTAssertEqual(15, banner.duration)
        XCTAssertEqual(InAppMessageDisplayContent.Banner.Placement.bottom, banner.placement)
        XCTAssertEqual(nil, banner.actions)
        XCTAssertNil(banner.buttons)
    }

    func testReceiveNotificationRecordsReplacement() async throws {
        subject.pendingMessageId = "some-pending"

        let payload = [
            "identifier": "test-id",
            "type": "banner",
            "alert": "test alert"
        ]


        let expection = XCTestExpectation(description: "schedule legacy message")
        subject.receivedRemoteNotification(["com.urbanairship.in_app": payload]) { result in
            XCTAssertEqual(UIBackgroundFetchResult.noData, result)
            expection.fulfill()
        }

        await fulfillment(of: [expection], timeout: 5)
        XCTAssertEqual("some-pending", self.analytics.replaced.first!.0)
        XCTAssertEqual("test-id", self.analytics.replaced.first!.1)
    }

    func testReceiveRemoteNotificationSchedulesMessage() async throws {
        let airshipTestInstance = TestAirshipInstance()
        airshipTestInstance.components = [await makePushComponent()]
        airshipTestInstance.makeShared()
        
        let messageId = "test-id"
        let payload: [String: Any] = [
            "identifier": "test-id",
            "type": "banner",
            "position": "top",
            "alert": "test alert",
            "duration": 100.0,
            "primary_color": "#ABCDEF",
            "secondary_color": "#FEDCBA",
            "extra": ["extra_value": "some text"],
            "expiry": AirshipUtils.isoDateFormatterUTCWithDelimiter().string(from: date.now),
            "on_click": ["onclick": "action"],
            "button_group": "ua_shop_now_share",
            "button_actions": ["shop_now": ["test": "json"], "share": ["test-2": "json-2"]],
            "campaigns": ["test-campaing": "json"],
            "message_type": "test-message"
        ]
        
        XCTAssertNil(engine.lastCancelledScheduleId)
        XCTAssert(engine.schedules.isEmpty)
        
        let expection = XCTestExpectation(description: "schedule legacy message")
        
        subject.pendingMessageId = "some-pending"
        
        subject.receivedRemoteNotification(["com.urbanairship.in_app": payload]) { result in
            XCTAssertEqual(UIBackgroundFetchResult.noData, result)
            expection.fulfill()
        }
        
        await fulfillment(of: [expection], timeout: 5)

        let schedule = try XCTUnwrap(engine.schedules.first)
        
        XCTAssertEqual("some-pending", engine.lastCancelledScheduleId)
        XCTAssertEqual(messageId, subject.pendingMessageId)
        
        XCTAssertEqual(messageId, schedule.identifier)
        XCTAssertEqual(1, schedule.triggers.count)
        
        let trigger = try XCTUnwrap(schedule.triggers.first)
        XCTAssertEqual(1.0, trigger.goal)
        XCTAssertNil(trigger.predicate)
        XCTAssertEqual(AutomationTriggerType.activeSession, trigger.type)
        
        XCTAssertEqual(date.now, schedule.created)
        let timeDiff = schedule.end?.timeIntervalSince(date.now) ?? 0
        XCTAssert(fabs(timeDiff) < 1)
        XCTAssertEqual(try! AirshipJSON.wrap(["test-campaing": "json"]), schedule.campaigns)
        XCTAssertEqual("test-message", schedule.messageType)
        
        let inAppMessage: InAppMessage
        switch schedule.data {
        case .inAppMessage(let message):
            inAppMessage = message
        default:
            fatalError("unsupported schedule data")
        }
        
        XCTAssertEqual("test alert", inAppMessage.name)
        XCTAssertEqual(InAppMessageSource.legacyPush, inAppMessage.source)
        XCTAssertEqual(try! AirshipJSON.wrap(["extra_value": "some text"]), inAppMessage.extras)
        
        let banner: InAppMessageDisplayContent.Banner
        switch inAppMessage.displayContent {
        case .banner(let model):
            banner = model
        default:
            fatalError("unsupported display content")
        }
        
        XCTAssertEqual("test alert", banner.body?.text)
        XCTAssertEqual("#FEDCBA", banner.body?.color?.hexColorString)
        XCTAssertEqual(InAppMessageButtonLayoutType.seperate, banner.buttonLayoutType)
        XCTAssertEqual("#ABCDEF", banner.backgroundColor?.hexColorString)
        XCTAssertEqual("#FEDCBA", banner.dismissButtonColor?.hexColorString)
        XCTAssertEqual(2, banner.borderRadius)
        XCTAssertEqual(100, banner.duration)
        XCTAssertEqual(InAppMessageDisplayContent.Banner.Placement.top, banner.placement)
        XCTAssertEqual(try! AirshipJSON.wrap(["onclick": "action"]), banner.actions)
        
        let buttons = try! XCTUnwrap(banner.buttons)
        XCTAssertEqual(2, buttons.count)
        
        let shopNowButton = buttons[0]
        XCTAssertEqual("shop_now", shopNowButton.identifier)
        XCTAssertEqual("Shop Now", shopNowButton.label.text)
        XCTAssertEqual("#ABCDEF", shopNowButton.label.color?.hexColorString)
        XCTAssertEqual(try! AirshipJSON.wrap(["test": "json"]), shopNowButton.actions)
        XCTAssertEqual("#FEDCBA", shopNowButton.backgroundColor?.hexColorString)
        XCTAssertEqual(2, shopNowButton.borderRadius)
        
        let share = buttons[1]
        XCTAssertEqual("share", share.identifier)
        XCTAssertEqual("Share", share.label.text)
        XCTAssertEqual("#ABCDEF", share.label.color?.hexColorString)
        XCTAssertEqual(try! AirshipJSON.wrap(["test-2": "json-2"]), share.actions)
        XCTAssertEqual("#FEDCBA", share.backgroundColor?.hexColorString)
        XCTAssertEqual(2, share.borderRadius)
    }
    
    func testTriggertIsLessAgressiveIfNotDisplayAsap() async throws {
        let payload = [
            "identifier": "test-id",
            "type": "banner",
            "alert": "test alert"
        ]
        
        let expection = XCTestExpectation(description: "schedule legacy message")
        
        await MainActor.run { [messaging = self.subject!] in
            messaging.displayASAPEnabled = false
        }
        
        subject.receivedRemoteNotification(["com.urbanairship.in_app": payload]) { result in
            XCTAssertEqual(UIBackgroundFetchResult.noData, result)
            expection.fulfill()
        }
        
        await fulfillment(of: [expection], timeout: 5)

        let schedule = try XCTUnwrap(engine.schedules.first)
        
        let trigger = try XCTUnwrap(schedule.triggers.first)
        XCTAssertEqual(1.0, trigger.goal)
        XCTAssertNil(trigger.predicate)
        XCTAssertEqual(AutomationTriggerType.foreground, trigger.type)
    }
    
    func testCustomMessageConverter() async throws {
        let payload = [
            "identifier": "test-id",
            "type": "banner",
            "alert": "test alert"
        ]
        
        let overridenId = "converter override id"
        
        await MainActor.run { [messaging = self.subject!] in
            messaging.customMessageConverter = { input in
                return AutomationSchedule(
                    identifier: overridenId,
                    triggers: [],
                    data: .inAppMessage(InAppMessage(name: "overriden", displayContent: .banner(InAppMessageDisplayContent.Banner()))))
            }
        }
        
        let expection = XCTestExpectation(description: "schedule legacy message")
        subject.receivedRemoteNotification(["com.urbanairship.in_app": payload]) { result in
            XCTAssertEqual(UIBackgroundFetchResult.noData, result)
            expection.fulfill()
        }
        
        await fulfillment(of: [expection], timeout: 5)

        let schedule = try XCTUnwrap(engine.schedules.first)
        XCTAssertEqual(overridenId, schedule.identifier)
    }
    
    func testMessageExtenderFunction() async throws {
        let payload = [
            "identifier": "test-id",
            "type": "banner",
            "alert": "test alert"
        ]
        
        let extendedMessageName = "extended message name"
        
        await MainActor.run { [messaging = self.subject!] in
            messaging.messageExtender = { input in
                return InAppMessage(name: extendedMessageName, displayContent: input.displayContent)
            }
        }
        
        let expection = XCTestExpectation(description: "schedule legacy message")
        subject.receivedRemoteNotification(["com.urbanairship.in_app": payload]) { result in
            XCTAssertEqual(UIBackgroundFetchResult.noData, result)
            expection.fulfill()
        }
        
        await fulfillment(of: [expection], timeout: 5)

        let schedule = try XCTUnwrap(engine.schedules.first)
        let inAppMessage: InAppMessage
        switch schedule.data {
        case .inAppMessage(let message):
            inAppMessage = message
        default:
            fatalError("unsupported schedule data")
        }
        
        XCTAssertEqual(extendedMessageName, inAppMessage.name)
    }
    
    func testScheduleExtendFunction() async throws {
        let payload = [
            "identifier": "test-id",
            "type": "banner",
            "alert": "test alert"
        ]
        
        let extendedScheduleId = "extended schedule id"
        
        await MainActor.run { [messaging = self.subject!] in
            messaging.scheduleExtender = { input in
                return AutomationSchedule(identifier: extendedScheduleId, triggers: input.triggers, data: input.data)
            }
        }
        
        let expection = XCTestExpectation(description: "schedule legacy message")
        subject.receivedRemoteNotification(["com.urbanairship.in_app": payload]) { result in
            XCTAssertEqual(UIBackgroundFetchResult.noData, result)
            expection.fulfill()
        }
        
        await fulfillment(of: [expection], timeout: 5)

        let schedule = try XCTUnwrap(engine.schedules.first)
        XCTAssertEqual(extendedScheduleId, schedule.identifier)
    }
    
    func testReceiveRemoteIgnoresNonlegacyMessages() async throws {
        
        XCTAssertNil(engine.lastCancelledScheduleId)
        XCTAssert(engine.schedules.isEmpty)
        
        let expection = XCTestExpectation(description: "schedule legacy message")
        
        subject.pendingMessageId = "some-pending"
        
        subject.receivedRemoteNotification([:]) { result in
            XCTAssertEqual(UIBackgroundFetchResult.noData, result)
            expection.fulfill()
        }
        
        await fulfillment(of: [expection], timeout: 5)

        XCTAssertNil(engine.lastCancelledScheduleId)
        XCTAssert(engine.schedules.isEmpty)
        XCTAssertEqual("some-pending", subject.pendingMessageId)
    }
    
    func testReceiveRemoteNotificationHandlesMessageIdOverride() async throws {
        let messageId = "overriden"
        let payload = [
            "identifier": "test-id",
            "type": "banner",
            "alert": "test alert"
        ]
        
        XCTAssert(engine.schedules.isEmpty)
        
        let expection = XCTestExpectation(description: "schedule legacy message")
        
        subject.receivedRemoteNotification([
            "com.urbanairship.in_app": payload,
            "_": messageId
        ]) { result in
            XCTAssertEqual(UIBackgroundFetchResult.noData, result)
            expection.fulfill()
        }
        
        await fulfillment(of: [expection], timeout: 5)

        XCTAssertTrue(engine.schedules.contains(where: { $0.identifier == messageId }))
        XCTAssertEqual(messageId, subject.pendingMessageId)
    }
    
    func testReceiveRemoteNotificationOverridesOnClick() async throws {
        let payload = [
            "identifier": "test-id",
            "type": "banner",
            "alert": "test alert"
        ]
        
        XCTAssert(engine.schedules.isEmpty)
        
        let expection = XCTestExpectation(description: "schedule legacy message")
        
        let onClickJson = try AirshipJSON.wrap(["onclick": "overriden"])
        
        subject.receivedRemoteNotification([
            "com.urbanairship.in_app": payload,
            "_uamid": onClickJson.unWrap()!
        ]) { result in
            XCTAssertEqual(UIBackgroundFetchResult.noData, result)
            expection.fulfill()
        }
        
        await fulfillment(of: [expection], timeout: 5)

        let schedule = try XCTUnwrap(engine.schedules.first)
        
        switch schedule.data {
        case .inAppMessage(let message):
            switch message.displayContent {
            case .banner(let banner):
                XCTAssertEqual(onClickJson, banner.actions)
            default:
                fatalError("unsupported display content")
            }
        default:
            fatalError("unsupported schedule data type")
        }
    }
    
    private func makePushComponent() async -> AirshipPush {
        return await AirshipPush(
            config: RuntimeConfig(
                config: AirshipConfig(),
                dataStore: datastore),
            dataStore: datastore,
            channel: TestChannel(),
            analytics: TestAnalytics(), 
            privacyManager: AirshipPrivacyManager(dataStore: datastore, defaultEnabledFeatures: .all),
            permissionsManager: AirshipPermissionsManager(),
            notificationRegistrar: TestNotificationRegistrar(),
            apnsRegistrar: TestAPNSRegistrar(),
            badger: TestBadger())
    }
}

private final class KeyedArchiver: NSKeyedArchiver {
//    override func decodeObject(of classes: [AnyClass]?, forKey key: String) -> Any? {
//        return ""
//    }
    override func decodeObject(forKey _: String) -> Any { "" }
    override func decodeInt64(forKey key: String) -> Int64 { 0 }
}

private extension UNNotificationResponse {
    static func with(
        userInfo: [AnyHashable: Any],
        actionIdentifier: String = UNNotificationDefaultActionIdentifier
    ) throws -> UNNotificationResponse {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        let request = UNNotificationRequest(
            identifier: "",
            content: content,
            trigger: nil
        )
        
        let coder = KeyedArchiver(requiringSecureCoding: false)

        let notification = try XCTUnwrap(UNNotification(coder: coder))
        notification.setValue(request, forKey: "request")

        let response = try XCTUnwrap(UNNotificationResponse(coder: coder))
        response.setValue(notification, forKey: "notification")
        response.setValue(actionIdentifier, forKey: "actionIdentifier")
        
        coder.finishEncoding()
        return response
    }
}

fileprivate final class TestLegacyAnalytics: LegacyInAppAnalyticsProtocol, @unchecked Sendable {
    var replaced: [(String, String)] = []
    var directOpen: [String] = []
    func recordReplacedEvent(scheduleID: String, replacementID: String) {
        replaced.append((scheduleID, replacementID))
    }

    func recordDirectOpenEvent(scheduleID: String) {
        directOpen.append(scheduleID)
    }
}
