/* Copyright Airship and Contributors */

import Testing
import Foundation
import UserNotifications
@testable @_spi(AirshipInternal) import AirshipAutomation
@testable import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

@MainActor
@Suite(.serialized)
final class LegacyInAppMessagingTest {
    
    private let analytics = TestLegacyAnalytics()
    private let engine = TestAutomationEngine()
    private let datastore = PreferenceDataStore(appKey: UUID().uuidString)
    private let date = UATestDate(offset: 0, dateOverride: Date())
    private let airshipTestInstance: TestAirshipInstance

    private var subject: DefaultLegacyInAppMessaging!
    init() async throws {
        airshipTestInstance = TestAirshipInstance()
        let push = TestPush()
        push.combinedCategories = NotificationCategories.defaultCategories()

        airshipTestInstance.components = [push]
        airshipTestInstance.makeShared()

        createSubject()
    }

    deinit {
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
    
    @Test
    func testOldDataCleanedUpOnInit() {
        
        let keys = ["UAPendingInAppMessage", "UAAutoDisplayInAppMessageDataStoreKey", "UALastDisplayedInAppMessageID"]
        
        keys.forEach { key in
            datastore.setObject("\(key)-test-value", forKey: key)
        }
        
        keys.forEach { key in
            #expect(datastore.keyExists(key))
        }
        
        createSubject()
        
        keys.forEach { key in
            #expect(!(datastore.keyExists(key)))
        }
    }

    @Test
    func testPendingMessageStorage() {
        #expect(subject.pendingMessageID == nil)

        subject.pendingMessageID = "message-id"
        #expect("message-id" == subject.pendingMessageID)
    }
    
    @Test
    func testAsapFlagStorage() async {
        var value = subject.displayASAPEnabled
        #expect(value)
        
        subject.displayASAPEnabled = false
        
        value = subject.displayASAPEnabled
        #expect(!(value))
    }
    
    @Test
    func testNotificationResponseCancelsPendingMessage() async throws {
        let pendingMessageID = "pending"
        
        #expect(subject.pendingMessageID == nil)
        await assertLastCancalledScheduleIDEquals(nil)
        
        subject.pendingMessageID = pendingMessageID
        
        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": pendingMessageID
        ])
        
        await subject.receivedNotificationResponse(response)
        
        await assertLastCancalledScheduleIDEquals(pendingMessageID)
        #expect(subject.pendingMessageID == nil)
    }

    @Test
    func testNotificationResponseRecordsDirectOpen() async throws {
        let pendingMessageID = "pending"
        subject.pendingMessageID = pendingMessageID

        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": pendingMessageID
        ])

        await subject.receivedNotificationResponse(response)

        #expect([pendingMessageID] == self.analytics.directOpen)
    }

    @Test
    func testNotificationResponseDoesNothingOnIdMismatch() async throws {
        
        #expect(subject.pendingMessageID == nil)
        await assertLastCancalledScheduleIDEquals(nil)
        
        subject.pendingMessageID = "mismatched"
        
        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": "pendingMessageID"
        ])
        
        await subject.receivedNotificationResponse(response)
        
        #expect("mismatched" == subject.pendingMessageID)
        await assertLastCancalledScheduleIDEquals(nil)
    }
    
    @Test
    func testNotificationResponseDoesNothingIfNoPending() async throws {
        
        #expect(subject.pendingMessageID == nil)
        await assertLastCancalledScheduleIDEquals(nil)
        
        let response = try UNNotificationResponse.with(userInfo: [
            "com.urbanairship.in_app": [],
            "_": "pendingMessageID"
        ])
        
        await subject.receivedNotificationResponse(response)
        
        #expect(subject.pendingMessageID == nil)
        await assertLastCancalledScheduleIDEquals(nil)
    }
    
    @Test
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
        #expect(UABackgroundFetchResult.noData == result)

        let schedule = try await requireFirstSchedule()
        
        await assertLastCancalledScheduleIDEquals("some-pending")
        #expect(messageId == subject.pendingMessageID)
        
        #expect(messageId == schedule.identifier)
        #expect(1 == schedule.triggers.count)
        
        guard case .event(let trigger) = schedule.triggers.first else {
            Issue.record()
            return
        }
        #expect(1.0 == trigger.goal)
        #expect(trigger.predicate == nil)
        #expect(EventAutomationTriggerType.activeSession == trigger.type)

        #expect(date.now == schedule.created)
        let month: TimeInterval = 60 * 60 * 24 * 30.0
        #expect(schedule.end == date.now + month)
        #expect(schedule.campaigns == nil)
        #expect(schedule.messageType == nil)
        
        let inAppMessage: InAppMessage
        switch schedule.data {
        case .inAppMessage(let message):
            inAppMessage = message
        default:
            fatalError("unsupported schedule data")
        }
        
        #expect("test alert" == inAppMessage.name)
        #expect(InAppMessageSource.legacyPush == inAppMessage.source)
        #expect(inAppMessage.extras == nil)
        
        let banner: InAppMessageDisplayContent.Banner
        switch inAppMessage.displayContent {
        case .banner(let model):
            banner = model
        default:
            fatalError("unsupported display content")
        }
        
        #expect("test alert" == banner.body?.text)
        #expect("#1C1C1C" == banner.body?.color?.hexColorString)
        #expect(InAppMessageButtonLayoutType.separate == banner.buttonLayoutType)
        #expect("#FFFFFF" == banner.backgroundColor?.hexColorString)
        #expect("#1C1C1C" == banner.dismissButtonColor?.hexColorString)
        #expect(2 == banner.borderRadius)
        #expect(15 == banner.duration)
        #expect(InAppMessageDisplayContent.Banner.Placement.bottom == banner.placement)
        #expect(nil == banner.actions)
        #expect(banner.buttons == nil)
    }

    @Test
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
        #expect(UABackgroundFetchResult.noData == result)
        
        #expect("some-pending" == self.analytics.replaced.first!.0)
        #expect("test-id" == self.analytics.replaced.first!.1)
    }

    @Test
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
            "expiry": AirshipDateFormatter.string(fromDate: date.now, format: .iso8601),
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
        #expect(UABackgroundFetchResult.noData == result)

        let schedule = try await requireFirstSchedule()
        
        await assertLastCancalledScheduleIDEquals("some-pending")
        #expect(messageId == subject.pendingMessageID)
        
        #expect(messageId == schedule.identifier)
        #expect(1 == schedule.triggers.count)
        
        guard case .event(let trigger) = schedule.triggers.first else {
            Issue.record()
            return
        }
        #expect(1.0 == trigger.goal)
        #expect(trigger.predicate == nil)
        #expect(EventAutomationTriggerType.activeSession == trigger.type)

        #expect(date.now == schedule.created)
        let timeDiff = schedule.end?.timeIntervalSince(date.now) ?? 0
        #expect(fabs(timeDiff) < 1)
        #expect(try! AirshipJSON.wrap(["test-campaing": "json"]) == schedule.campaigns)
        #expect("test-message" == schedule.messageType)
        
        let inAppMessage: InAppMessage
        switch schedule.data {
        case .inAppMessage(let message):
            inAppMessage = message
        default:
            fatalError("unsupported schedule data")
        }
        
        #expect("test alert" == inAppMessage.name)
        #expect(InAppMessageSource.legacyPush == inAppMessage.source)
        #expect(try! AirshipJSON.wrap(["extra_value": "some text"]) == inAppMessage.extras)
        
        let banner: InAppMessageDisplayContent.Banner
        switch inAppMessage.displayContent {
        case .banner(let model):
            banner = model
        default:
            fatalError("unsupported display content")
        }
        
        #expect("test alert" == banner.body?.text)
        #expect("#FEDCBA" == banner.body?.color?.hexColorString)
        #expect(InAppMessageButtonLayoutType.separate == banner.buttonLayoutType)
        #expect("#ABCDEF" == banner.backgroundColor?.hexColorString)
        #expect("#FEDCBA" == banner.dismissButtonColor?.hexColorString)
        #expect(2 == banner.borderRadius)
        #expect(100 == banner.duration)
        #expect(InAppMessageDisplayContent.Banner.Placement.top == banner.placement)
        #expect(try! AirshipJSON.wrap(["onclick": "action"]) == banner.actions)
        
        let buttons = try! #require(banner.buttons)
        #expect(2 == buttons.count)
        
        let shopNowButton = buttons[0]
        #expect("shop_now" == shopNowButton.identifier)
        #expect("Shop Now" == shopNowButton.label.text)
        #expect("#ABCDEF" == shopNowButton.label.color?.hexColorString)
        #expect(try! AirshipJSON.wrap(["test": "json"]) == shopNowButton.actions)
        #expect("#FEDCBA" == shopNowButton.backgroundColor?.hexColorString)
        #expect(2 == shopNowButton.borderRadius)
        
        let share = buttons[1]
        #expect("share" == share.identifier)
        #expect("Share" == share.label.text)
        #expect("#ABCDEF" == share.label.color?.hexColorString)
        #expect(try! AirshipJSON.wrap(["test-2": "json-2"]) == share.actions)
        #expect("#FEDCBA" == share.backgroundColor?.hexColorString)
        #expect(2 == share.borderRadius)
    }
    
    @Test
    func testTriggertIsLessAgressiveIfNotDisplayAsap() async throws {
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        subject.displayASAPEnabled = false
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        #expect(UABackgroundFetchResult.noData == result)

        let schedule = try await requireFirstSchedule()
        
        guard case .event(let trigger) = schedule.triggers.first else {
            Issue.record()
            return
        }

        #expect(1.0 == trigger.goal)
        #expect(trigger.predicate == nil)
        #expect(EventAutomationTriggerType.foreground == trigger.type)
    }
    
    @Test
    func testCustomMessageConverter() async throws {
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        let overridenId = "converter override id"
        
        subject.customMessageConverter = { input in
            return AutomationSchedule(
                identifier: overridenId,
                triggers: [],
                data: .inAppMessage(InAppMessage(name: "overriden", displayContent: .banner(InAppMessageDisplayContent.Banner()))))
        }
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        #expect(UABackgroundFetchResult.noData == result)
        
        let schedule = try await requireFirstSchedule()
        #expect(overridenId == schedule.identifier)
    }
    
    @Test
    func testMessageExtenderFunction() async throws {
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]
        
        let extendedMessageName = "extended message name"
        
        subject.messageExtender = { input in
            input.name = extendedMessageName
        }
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        #expect(UABackgroundFetchResult.noData == result)

        let schedule = try await requireFirstSchedule()
        let inAppMessage: InAppMessage
        switch schedule.data {
        case .inAppMessage(let message):
            inAppMessage = message
        default:
            fatalError("unsupported schedule data")
        }
        
        #expect(extendedMessageName == inAppMessage.name)
    }
    
    @Test
    func testScheduleExtendFunction() async throws {
        let payload: [String: Any] = [
            "identifier": "test-id",
            "display": [
                "type": "banner",
                "alert": "test alert"
            ]
        ]

        
        subject.scheduleExtender = { input in
            input.limit = 10
        }
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap(["com.urbanairship.in_app": payload])
        )
        #expect(UABackgroundFetchResult.noData == result)

        let schedule = try await requireFirstSchedule()
        #expect(10 == schedule.limit)
    }
    
    @Test
    func testReceiveRemoteIgnoresNonlegacyMessages() async throws {
        
        await assertLastCancalledScheduleIDEquals(nil)
        await assertEmptySchedules()
        
        subject.pendingMessageID = "some-pending"
        
        let result = await subject.receivedRemoteNotification(
            try! AirshipJSON.wrap([:])
        )
        #expect(UABackgroundFetchResult.noData == result)

        await assertLastCancalledScheduleIDEquals(nil)
        await assertEmptySchedules()
        #expect("some-pending" == subject.pendingMessageID)
    }
    
    @Test
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
        #expect(UABackgroundFetchResult.noData == result)

        let schedules = await engine.schedules
        #expect(schedules.contains(where: { $0.identifier == messageId }))
        #expect(messageId == subject.pendingMessageID)
    }
    
    @Test
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
        #expect(UABackgroundFetchResult.noData == result)
        
        let schedule = try await requireFirstSchedule()
        
        switch schedule.data {
        case .inAppMessage(let message):
            switch message.displayContent {
            case .banner(let banner):
                #expect(onClickJson == banner.actions)
            default:
                fatalError("unsupported display content")
            }
        default:
            fatalError("unsupported schedule data type")
        }
    }

    private func requireFirstSchedule(sourceLocation: SourceLocation = #_sourceLocation) async throws -> AutomationSchedule {
        let schedule = await engine.schedules.first
        return try #require(schedule, sourceLocation: sourceLocation)
    }

    private func assertEmptySchedules(sourceLocation: SourceLocation = #_sourceLocation) async {
        let schedules = await engine.schedules
        #expect(schedules.isEmpty, sourceLocation: sourceLocation)
    }

    private func assertLastCancalledScheduleIDEquals(_ value: String?) async {
        let lastCancelledScheduleId = await engine.cancelledSchedules.last
        #expect(lastCancelledScheduleId == value)
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

        let notification = try #require(UNNotification(coder: coder))
        notification.setValue(request, forKey: "request")

        let response = try #require(UNNotificationResponse(coder: coder))
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
