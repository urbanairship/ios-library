/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class CancelSchedulesActionTest: XCTestCase {
    
    let automation = TestAutomationEngine()
    var action: CancelSchedulesAction!
    
    override func setUp() async throws {
        let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        let config = RuntimeConfig.testConfig()
        
        let inAppAutomation = await DefaultInAppAutomation(
            engine: automation,
            inAppMessaging: TestInAppMessaging(),
            legacyInAppMessaging: TestLegacyInAppMessaging(),
            remoteData: TestRemoteData(),
            remoteDataSubscriber: TestRemoteDataSubscriber(),
            dataStore: dataStore,
            privacyManager: TestPrivacyManager(
                dataStore: dataStore,
                config: config,
                defaultEnabledFeatures: .all),
            config: config)
        
        action = CancelSchedulesAction(overrideAutomation: inAppAutomation)
    }
    
    func testAcceptsArguments() async throws {
        let valid: [ActionSituation] = [
            .foregroundPush, .backgroundPush, .manualInvocation, .webViewInvocation, .automation
        ]
        
        let rejected: [ActionSituation] = [
            .launchedFromPush, .foregroundInteractiveButton, .backgroundInteractiveButton
        ]
        
        for situation in valid {
            let args = ActionArguments(value: AirshipJSON.null, situation: situation)
            let result = await action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in rejected {
            let args = ActionArguments(value: AirshipJSON.null, situation: situation)
            let result = await action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }
    
    func testArguments() async throws {
        //should accept all
        var args = ActionArguments(value: try AirshipJSON.wrap("all"), situation: .automation)
        var result = try await action.perform(arguments: args)
        XCTAssertNil(result)
        
        //should fail other strings
        args = ActionArguments(value: try AirshipJSON.wrap("invalid"), situation: .automation)
        await assertThrowsAsync { _ = try await action.perform(arguments: args) }
        
        //should accept dictionaries with groups
        args = ActionArguments(value: try AirshipJSON.wrap(["groups": "test"]), situation: .automation)
        result = try await action.perform(arguments: args)
        XCTAssertNil(result)
        
        //should accept dictionaries with groups array
        args = ActionArguments(value: try AirshipJSON.wrap(["groups": ["test"]]), situation: .automation)
        result = try await action.perform(arguments: args)
        XCTAssertNil(result)
        
        //should accept dictionaries with ids
        args = ActionArguments(value: try AirshipJSON.wrap(["ids": "test"]), situation: .automation)
        result = try await action.perform(arguments: args)
        XCTAssertNil(result)
        
        //should accept dictionaries with ids array
        args = ActionArguments(value: try AirshipJSON.wrap(["ids": ["test"]]), situation: .automation)
        result = try await action.perform(arguments: args)
        XCTAssertNil(result)
        
        //should accept dictionaries with ids and groups
        args = ActionArguments(value: try AirshipJSON.wrap(["ids": ["test"], "groups": "test1"]), situation: .automation)
        result = try await action.perform(arguments: args)
        XCTAssertNil(result)
        
        //should fail if neither groups nor ids key found
        args = ActionArguments(value: try AirshipJSON.wrap(["key": "invalid"]), situation: .automation)
        await assertThrowsAsync { _ = try await action.perform(arguments: args) }
    }
    
    func assertThrowsAsync(_ block: () async throws -> Void) async {
        do {
            try await block()
            XCTFail()
        } catch { }
    }
    
    func testCancellAll() async throws {
        await automation.setSchedules([
            AutomationSchedule(identifier: "action1", data: .actions(.null), triggers: []),
            AutomationSchedule(identifier: "action2", data: .actions(.null), triggers: []),
            AutomationSchedule(identifier: "message", data: .inAppMessage(InAppMessage(name: "test", displayContent: .custom(.null))), triggers: [])
        ])
        
        var count = await automation.schedules.count
        XCTAssertEqual(3, count)
        
        _ = try await action.perform(arguments: ActionArguments(value: AirshipJSON.string("all")))
        count = await automation.schedules.count
        XCTAssertEqual(1, count)
        let schedule = await automation.schedules.first
        XCTAssertEqual("message", schedule?.identifier)
    }
    
    func testCancelGroups() async throws {
        await automation.setSchedules([
            AutomationSchedule(identifier: "group1", triggers: [], data: .actions(.null), group: "group-1"),
            AutomationSchedule(identifier: "group2", triggers: [], data: .actions(.null), group: "group-2"),
            AutomationSchedule(identifier: "group3", triggers: [], data: .actions(.null), group: "group-3"),
        ])
        
        let count = await automation.schedules.count
        XCTAssertEqual(3, count)
        
        _ = try await action.perform(
            arguments: ActionArguments(
                value: AirshipJSON.object(["groups": .string("group-1")])))
        
        var scheduleIds = await automation.schedules.map({ $0.identifier })
        XCTAssertEqual(["group2", "group3"], scheduleIds)
        
        _ = try await action.perform(
            arguments: ActionArguments(
                value: AirshipJSON.object(["groups": .array([.string("group-2"), .string("group-3")])])))
        
        scheduleIds = await automation.schedules.map({ $0.identifier })
        XCTAssert(scheduleIds.isEmpty)
    }
    
    func testCancelWithIds() async throws {
        await automation.setSchedules([
            AutomationSchedule(identifier: "id-1", triggers: [], data: .actions(.null)),
            AutomationSchedule(identifier: "id-2", triggers: [], data: .actions(.null)),
            AutomationSchedule(identifier: "id-3", triggers: [], data: .actions(.null)),
        ])
        
        let count = await automation.schedules.count
        XCTAssertEqual(3, count)
        
        _ = try await action.perform(
            arguments: ActionArguments(
                value: AirshipJSON.object(["ids": .string("id-1")])))
        
        var scheduleIds = await automation.schedules.map({ $0.identifier })
        XCTAssertEqual(["id-2", "id-3"], scheduleIds)
        
        _ = try await action.perform(
            arguments: ActionArguments(
                value: AirshipJSON.object(["ids": .array([.string("id-2"), .string("id-3")])])))
        
        scheduleIds = await automation.schedules.map({ $0.identifier })
        XCTAssert(scheduleIds.isEmpty)
    }
    
    func testBothGroupsAndIds() async throws {
        await automation.setSchedules([
            AutomationSchedule(identifier: "id-1", triggers: [], data: .actions(.null)),
            AutomationSchedule(identifier: "id-2", triggers: [], data: .actions(.null), group: "group")
        ])
        
        let count = await automation.schedules.count
        XCTAssertEqual(2, count)
        
        _ = try await action.perform(
            arguments: ActionArguments(
                value: AirshipJSON.object(["ids": .string("id-1"), "groups": .string("group")])))
        
        let scheduleIds = await automation.schedules.map({ $0.identifier })
        XCTAssert(scheduleIds.isEmpty)
    }
}

final class TestInAppMessaging: InAppMessaging, @unchecked Sendable {
    @MainActor
    var themeManager: InAppAutomationThemeManager = InAppAutomationThemeManager()

    var displayInterval: TimeInterval = 0.0
    
    var displayDelegate: InAppMessageDisplayDelegate?
    
    var sceneDelegate: InAppMessageSceneDelegate?
    
    func setAdapterFactoryBlock(
        forType: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (InAppMessage, AirshipCachedAssetsProtocol) -> CustomDisplayAdapter?
    ) {

    }

    func setCustomAdapter(
        forType: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (DisplayAdapterArgs) -> CustomDisplayAdapter?
    ) {

    }

    func notifyDisplayConditionsChanged() {
        
    }
}

final class TestLegacyInAppMessaging: InternalLegacyInAppMessaging, @unchecked Sendable {
    
    init(customMessageConverter: AirshipAutomation.MessageConvertor? = nil, messageExtender: AirshipAutomation.MessageExtender? = nil, scheduleExtender: AirshipAutomation.ScheduleExtender? = nil, displayASAPEnabled: Bool = true) {
        self.customMessageConverter = customMessageConverter
        self.messageExtender = messageExtender
        self.scheduleExtender = scheduleExtender
        self.displayASAPEnabled = displayASAPEnabled
    }
    
    func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        
    }
    
    func receivedRemoteNotification(_ notification: AirshipJSON) async -> UABackgroundFetchResult {
        return .noData
    }
    
    var customMessageConverter: AirshipAutomation.MessageConvertor?
    
    var messageExtender: AirshipAutomation.MessageExtender?
    
    var scheduleExtender: AirshipAutomation.ScheduleExtender?
    
    var displayASAPEnabled: Bool
}

final class TestRemoteDataSubscriber: AutomationRemoteDataSubscriberProtocol {
    func subscribe() {
        
    }
    
    func unsubscribe() {
        
    }
}
