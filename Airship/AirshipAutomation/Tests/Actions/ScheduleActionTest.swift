/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

struct ScheduleActionTest {
    
    let automation = TestAutomationEngine()
    let action: ScheduleAction
    
    init() async throws {
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
    
    @Test
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
            #expect(result)
        }

        for situation in rejected {
            let args = ActionArguments(value: AirshipJSON.null, situation: situation)
            let result = await action.accepts(arguments: args)
            #expect(!(result))
        }
    }
    
    @Test
    func testSchedule() async throws {
        let start = Date(timeIntervalSince1970: 1709138610)
        let end = Date(timeIntervalSince1970: 1709138610).advanced(by: 1)
        let json: AirshipJSON = [
            "id": "test-id",
            "type": "actions",
            "group": "test-group",
            "limit": 1,
            "actions": ["action-name": "action-value"],
            "end": .string(AirshipDateFormatter.string(fromDate: end, format: .iso8601)),
            "start": .string(AirshipDateFormatter.string(fromDate: start, format: .iso8601)),
            "triggers": [
                [
                    "type": "foreground",
                    "goal": 2
                ]
            ]
        ]
        
        var count = await automation.schedules.count
        #expect(0 == count)
        
        let scheduleId = try await action.perform(arguments: ActionArguments(value: json))
        #expect("test-id" == scheduleId?.string)
        
        count = await automation.schedules.count
        #expect(1 == count)
        
        let schedule = await automation.schedules.first
        
        #expect("test-id" == schedule?.identifier)
        #expect("test-group" == schedule?.group)
        #expect(1 == schedule?.limit)
        #expect(end == schedule?.end)
        #expect(start == schedule?.start)
        #expect(1 == schedule?.triggers.count)
        #expect(EventAutomationTriggerType.foreground.rawValue == schedule?.triggers.first?.type)
        #expect(2 == schedule?.triggers.first?.goal)
        
        let actionJson: AirshipJSON
        switch schedule?.data {
        case .actions(let json): actionJson = json
        default: actionJson = .null
        }
        
        #expect(AirshipJSON.object(["action-name": "action-value"]) == actionJson)
    }
    
    @Test
    func testScheduleThrowsOnInvalidSource() async throws {
        do {
            _ = try await action.perform(arguments: ActionArguments(value: [:]))
            Issue.record()
        } catch { }
    }
}
