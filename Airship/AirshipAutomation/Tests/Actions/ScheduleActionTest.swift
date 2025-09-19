/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class ScheduleActionTest: XCTestCase {
    
    let automation = TestAutomationEngine()
    var action: ScheduleAction!
    
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
        
        action = ScheduleAction(overrideAutomation: inAppAutomation)
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
    
    func testSchedule() async throws {
        let start = Date(timeIntervalSince1970: 1709138610)
        let end = Date(timeIntervalSince1970: 1709138610).advanced(by: 1)
        let json = AirshipJSON.object([
            "id": .string("test-id"),
            "type": .string("actions"),
            "group": .string("test-group"),
            "limit": .number(1),
            "actions": .object(["action-name": .string("action-value")]),
            "end": .string(AirshipDateFormatter.string(fromDate: end, format: .iso)),
            "start": .string(AirshipDateFormatter.string(fromDate: start, format: .iso)),
            "triggers": .array([
                .object([
                    "type": .string("foreground"),
                    "goal": .number(2)
                ])
            ])
        ])
        
        var count = await automation.schedules.count
        XCTAssertEqual(0, count)
        
        let scheduleId = try await action.perform(arguments: ActionArguments(value: json))
        XCTAssertEqual("test-id", scheduleId?.string)
        
        count = await automation.schedules.count
        XCTAssertEqual(1, count)
        
        let schedule = await automation.schedules.first
        
        XCTAssertEqual("test-id", schedule?.identifier)
        XCTAssertEqual("test-group", schedule?.group)
        XCTAssertEqual(1, schedule?.limit)
        XCTAssertEqual(end, schedule?.end)
        XCTAssertEqual(start, schedule?.start)
        XCTAssertEqual(1, schedule?.triggers.count)
        XCTAssertEqual(EventAutomationTriggerType.foreground.rawValue, schedule?.triggers.first?.type)
        XCTAssertEqual(2, schedule?.triggers.first?.goal)
        
        let actionJson: AirshipJSON
        switch schedule?.data {
        case .actions(let json): actionJson = json
        default: actionJson = .null
        }
        
        XCTAssertEqual(AirshipJSON.object(["action-name": .string("action-value")]), actionJson)
    }
    
    func testScheduleThrowsOnInvalidSource() async throws {
        do {
            _ = try await action.perform(arguments: ActionArguments(value: .object([:])))
            XCTFail()
        } catch { }
    }
}
