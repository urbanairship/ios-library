/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
@testable import AirshipCore

final class LegacyInAppMessagingTest: XCTestCase {
    
    private let analytics = TestLegacyAnalytics()
    private let engine = TestAutomationEngine()
    private let datastore = PreferenceDataStore(appKey: UUID().uuidString)
    private let date = UATestDate(offset: 0, dateOverride: Date())
    private var airshipTestInstance: TestAirshipInstance!

    private var subject: DefaultLegacyInAppMessaging!

    @MainActor
    override func setUp() async throws {
        airshipTestInstance = TestAirshipInstance()
        let push = TestPush()
        push.combinedCategories = NotificationCategories.defaultCategories()

        airshipTestInstance.components = [push]
        airshipTestInstance.makeShared()

        createSubject()
    }

    override func tearDown() {
        TestAirshipInstance.clearShared()
    }

    private func createSubject() {
        subject = DefaultLegacyInAppMessaging(
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
        XCTAssertNil(subject.pendingMessageID)

        subject.pendingMessageID = "message-id"
        XCTAssertEqual("message-id", subject.pendingMessageID)
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
        let pendingMessageID = "pending"
        
        XCTAssertNil(subject.pendingMessageID)
        await assertLastCancalledScheduleIDEquals(nil)
        
        subject.pendingMessageID = pendingMessageID
        
        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": pendingMessageID
        ])
        
        await subject.receivedNotificationResponse(response)
        
        await assertLastCancalledScheduleIDEquals(pendingMessageID)
        XCTAssertNil(subject.pendingMessageID)
    }

    func testNotificationResponseRecordsDirectOpen() async throws {
        let pendingMessageID = "pending"
        subject.pendingMessageID = pendingMessageID

        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": pendingMessageID
        ])

        await subject.receivedNotificationResponse(response)

        XCTAssertEqual([pendingMessageID], self.analytics.directOpen)
    }

    func testNotificationResponseDoesNothingOnIdMismatch() async throws {
        
        XCTAssertNil(subject.pendingMessageID)
        await assertLastCancalledScheduleIDEquals(nil)
        
        subject.pendingMessageID = "mismatched"
        
        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": "pendingMessageID"
        ])
        
        await subject.receivedNotificationResponse(response)
        
        XCTAssertEqual("mismatched", subject.pendingMessageID)
        await assertLastCancalledScheduleIDEquals(nil)
    }
    
    func testNotificationResponseDoesNothingIfNoPending() async throws {
        
        XCTAssertNil(subject.pendingMessageID)
        await assertLastCancalledScheduleIDEquals(nil)
        
        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": "pendingMessageID"
        ])
        
        await subject.receivedNotificationResponse(response)
        
        XCTAssertNil(subject.pendingMessageID)
        await assertLastCancalledScheduleIDEquals(nil)
    }
    
    func testReceiveRemoteNotificationSchedulesMessageWithDefaults() async throws {
        let messageId = "test-id"
        let payload: [String: Any] = [
            "identifier": messageId,
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        await assertLastCancalledScheduleIDEquals(nil)
        await assertEmptySchedules()
        
        subject.pendingMessageID = "some-pending"
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        XCTAssertEqual(UABackgroundFetchResult.noData, result)

        let schedule = try await requireFirstSchedule()
        
        await assertLastCancalledScheduleIDEquals("some-pending")
        XCTAssertEqual(messageId, subject.pendingMessageID)
        
        XCTAssertEqual(messageId, schedule.identifier)
        XCTAssertEqual(1, schedule.triggers.count)
        
        guard case .event(let trigger) = schedule.triggers.first else {
            XCTFail()
            return
        }
        XCTAssertEqual(1.0, trigger.goal)
        XCTAssertNil(trigger.predicate)
        XCTAssertEqual(EventAutomationTriggerType.activeSession, trigger.type)

        XCTAssertEqual(date.now, schedule.created)
        let month: TimeInterval = 60 * 60 * 24 * 30.0
        XCTAssertEqual(schedule.end, date.now + month)
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
        XCTAssertEqual(InAppMessageButtonLayoutType.separate, banner.buttonLayoutType)
        XCTAssertEqual("#FFFFFF", banner.backgroundColor?.hexColorString)
        XCTAssertEqual("#1C1C1C", banner.dismissButtonColor?.hexColorString)
        XCTAssertEqual(2, banner.borderRadius)
        XCTAssertEqual(15, banner.duration)
        XCTAssertEqual(InAppMessageDisplayContent.Banner.Placement.bottom, banner.placement)
        XCTAssertEqual(nil, banner.actions)
        XCTAssertNil(banner.buttons)
    }

    func testReceiveNotificationRecordsReplacement() async throws {
        subject.pendingMessageID = "some-pending"

        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]

        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        XCTAssertEqual(UABackgroundFetchResult.noData, result)
        
        XCTAssertEqual("some-pending", self.analytics.replaced.first!.0)
        XCTAssertEqual("test-id", self.analytics.replaced.first!.1)
    }

    func testReceiveRemoteNotificationSchedulesMessage() async throws {
        let messageId = "test-id"
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert",
                "position": "top",
                "duration": 100.0,
                "primary_color": "#ABCDEF",
                "secondary_color": "#FEDCBA",
            ],
            "extra": ["extra_value": "some text"],
            "expiry": AirshipDateFormatter.string(fromDate: date.now, format: .isoDelimitter),
            "actions": [
                "on_click": ["onclick": "action"],
                "button_group": "ua_shop_now_share",
                "button_actions": ["shop_now": ["test": "json"], "share": ["test-2": "json-2"]],
            ],
            "campaigns": ["test-campaing": "json"],
            "message_type": "test-message"
        ]
        
        await assertLastCancalledScheduleIDEquals(nil)
        await assertEmptySchedules()
        
        subject.pendingMessageID = "some-pending"
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        XCTAssertEqual(UABackgroundFetchResult.noData, result)

        let schedule = try await requireFirstSchedule()
        
        await assertLastCancalledScheduleIDEquals("some-pending")
        XCTAssertEqual(messageId, subject.pendingMessageID)
        
        XCTAssertEqual(messageId, schedule.identifier)
        XCTAssertEqual(1, schedule.triggers.count)
        
        guard case .event(let trigger) = schedule.triggers.first else {
            XCTFail()
            return
        }
        XCTAssertEqual(1.0, trigger.goal)
        XCTAssertNil(trigger.predicate)
        XCTAssertEqual(EventAutomationTriggerType.activeSession, trigger.type)

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
        XCTAssertEqual(InAppMessageButtonLayoutType.separate, banner.buttonLayoutType)
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
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        await MainActor.run { [messaging = self.subject!] in
            messaging.displayASAPEnabled = false
        }
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        XCTAssertEqual(UABackgroundFetchResult.noData, result)

        let schedule = try await requireFirstSchedule()
        
        guard case .event(let trigger) = schedule.triggers.first else {
            XCTFail()
            return
        }

        XCTAssertEqual(1.0, trigger.goal)
        XCTAssertNil(trigger.predicate)
        XCTAssertEqual(EventAutomationTriggerType.foreground, trigger.type)
    }
    
    func testCustomMessageConverter() async throws {
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
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
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        XCTAssertEqual(UABackgroundFetchResult.noData, result)
        
        let schedule = try await requireFirstSchedule()
        XCTAssertEqual(overridenId, schedule.identifier)
    }
    
    func testMessageExtenderFunction() async throws {
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        let extendedMessageName = "extended message name"
        
        await MainActor.run { [messaging = self.subject!] in
            messaging.messageExtender = { input in
                input.name = extendedMessageName
            }
        }
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        XCTAssertEqual(UABackgroundFetchResult.noData, result)

        let schedule = try await requireFirstSchedule()
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
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]

        
        await MainActor.run { [messaging = self.subject!] in
            messaging.scheduleExtender = { input in
                input.limit = 10
            }
        }
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        XCTAssertEqual(UABackgroundFetchResult.noData, result)

        let schedule = try await requireFirstSchedule()
        XCTAssertEqual(10, schedule.limit)
    }
    
    func testReceiveRemoteIgnoresNonlegacyMessages() async throws {
        
        await assertLastCancalledScheduleIDEquals(nil)
        await assertEmptySchedules()
        
        subject.pendingMessageID = "some-pending"
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap([:])
        )
        XCTAssertEqual(UABackgroundFetchResult.noData, result)

        await assertLastCancalledScheduleIDEquals(nil)
        await assertEmptySchedules()
        XCTAssertEqual("some-pending", subject.pendingMessageID)
    }
    
    func testReceiveRemoteNotificationHandlesMessageIdOverride() async throws {
        let messageId = "overriden"
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        await assertEmptySchedules()
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap([
                "com.urbanairship.in_app": payload,
                "_": messageId
            ])
        )
        XCTAssertEqual(UABackgroundFetchResult.noData, result)

        let schedules = await engine.schedules
        XCTAssertTrue(schedules.contains(where: { $0.identifier == messageId }))
        XCTAssertEqual(messageId, subject.pendingMessageID)
    }
    
    func testReceiveRemoteNotificationOverridesOnClick() async throws {
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        await assertEmptySchedules()
        
        let onClickJson = try AirshipJSON.wrap(["onclick": "overriden"])
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap([
                "com.urbanairship.in_app": payload,
                "_uamid": onClickJson.unWrap()!
            ])
        )
        XCTAssertEqual(UABackgroundFetchResult.noData, result)
        
        let schedule = try await requireFirstSchedule()
        
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

    private func requireFirstSchedule(line: UInt = #line) async throws -> AutomationSchedule {
        let schedule = await engine.schedules.first
        return try XCTUnwrap(schedule)
    }

    private func assertEmptySchedules(line: UInt = #line) async {
        let schedules = await engine.schedules
        XCTAssert(schedules.isEmpty)
    }

    private func assertLastCancalledScheduleIDEquals(_ value: String?) async {
        let lastCancelledScheduleId = await engine.cancelledSchedules.last
        XCTAssertEqual(lastCancelledScheduleId, value)
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
