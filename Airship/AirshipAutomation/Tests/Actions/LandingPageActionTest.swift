/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class LandingPageActionTest: XCTestCase {

    func testAcceptsArguments() async throws {
        let action = LandingPageAction()

        let validSituations = [
            ActionSituation.foregroundInteractiveButton,
            ActionSituation.launchedFromPush,
            ActionSituation.manualInvocation,
            ActionSituation.webViewInvocation,
            ActionSituation.automation,
            ActionSituation.foregroundPush,
        ]

        let rejectedSituations = [
            ActionSituation.backgroundPush,
            ActionSituation.backgroundInteractiveButton,
        ]


        for situation in validSituations {
            let args = ActionArguments(value: AirshipJSON.null, situation: situation)
            let result = await action.accepts(arguments: args)
            XCTAssertTrue(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(value: AirshipJSON.null, situation: situation)
            let result = await action.accepts(arguments: args)
            XCTAssertFalse(result)
        }
    }

    func testSimpleURLArg() async throws {
        let urlChecked = expectation(description: "url checked")
        let scheduled = expectation(description: "scheduled")

        let expectedMessage = InAppMessage(
            name: "Landing Page https://some-url",
            displayContent: .html(
                .init(
                    url: "https://some-url",
                    requiresConnectivity: false,
                    borderRadius: 10
                )
            ),
            isReportingEnabled: false,
            displayBehavior: .immediate
        )

        let action = LandingPageAction(
            borderRadius: 10,
            scheduleExtender: nil,
            allowListChecker: { url in
                XCTAssertEqual("https://some-url", url.absoluteString)
                urlChecked.fulfill()
                return true
            },
            scheduler: { schedule in
                XCTAssertEqual(schedule.data, .inAppMessage(expectedMessage))
                XCTAssertEqual(schedule.triggers.count, 1)
                XCTAssertEqual(schedule.triggers[0].type, .activeSession)
                XCTAssertEqual(schedule.triggers[0].goal, 1.0)
                XCTAssertTrue(schedule.bypassHoldoutGroups!)
                XCTAssertEqual(schedule.productID, "landing_page")
                XCTAssertEqual(schedule.priority, Int.min)
                scheduled.fulfill()
            }
        )

        let args = ActionArguments(value: .string("https://some-url"), situation: .manualInvocation)

        let result = try await action.perform(arguments: args)
        XCTAssertNil(result)

        await self.fulfillment(of: [urlChecked, scheduled])
    }

    func testDictionaryArgs() async throws {
        let urlChecked = expectation(description: "url checked")
        let scheduled = expectation(description: "scheduled")

        let expectedMessage = InAppMessage(
            name: "Landing Page https://some-url",
            displayContent: .html(
                .init(
                    url: "https://some-url",
                    height: 20.0,
                    width: 10.0,
                    aspectLock: true,
                    requiresConnectivity: false,
                    borderRadius: 10
                )
            ),
            isReportingEnabled: false,
            displayBehavior: .immediate
        )

        let action = LandingPageAction(
            borderRadius: 10,
            scheduleExtender: nil,
            allowListChecker: { url in
                XCTAssertEqual("https://some-url", url.absoluteString)
                urlChecked.fulfill()
                return true
            },
            scheduler: { schedule in
                XCTAssertEqual(schedule.data, .inAppMessage(expectedMessage))
                XCTAssertEqual(schedule.triggers.count, 1)
                XCTAssertEqual(schedule.triggers[0].type, .activeSession)
                XCTAssertEqual(schedule.triggers[0].goal, 1.0)
                XCTAssertTrue(schedule.bypassHoldoutGroups!)
                XCTAssertEqual(schedule.productID, "landing_page")
                XCTAssertEqual(schedule.priority, Int.min)
                scheduled.fulfill()
            }
        )

        let argsJSON = """
        {
            "url": "https://some-url",
            "width": 10.0,
            "height": 20.0,
            "aspect_lock": true
        }
        """

        let args = ActionArguments(value: try AirshipJSON.from(json: argsJSON), situation: .manualInvocation)

        let result = try await action.perform(arguments: args)
        XCTAssertNil(result)

        await self.fulfillment(of: [urlChecked, scheduled])
    }

    func testAppendSchema() async throws {
        let urlChecked = expectation(description: "url checked")
        let scheduled = expectation(description: "scheduled")

        let expectedMessage = InAppMessage(
            name: "Landing Page https://some-url",
            displayContent: .html(
                .init(
                    url: "https://some-url",
                    requiresConnectivity: false,
                    borderRadius: 10
                )
            ),
            isReportingEnabled: false,
            displayBehavior: .immediate
        )

        let action = LandingPageAction(
            borderRadius: 10,
            scheduleExtender: nil,
            allowListChecker: { url in
                XCTAssertEqual("https://some-url", url.absoluteString)
                urlChecked.fulfill()
                return true
            },
            scheduler: { schedule in
                XCTAssertEqual(schedule.data, .inAppMessage(expectedMessage))
                XCTAssertEqual(schedule.triggers.count, 1)
                XCTAssertEqual(schedule.triggers[0].type, .activeSession)
                XCTAssertEqual(schedule.triggers[0].goal, 1.0)
                XCTAssertTrue(schedule.bypassHoldoutGroups!)
                XCTAssertEqual(schedule.productID, "landing_page")
                XCTAssertEqual(schedule.priority, Int.min)
                scheduled.fulfill()
            }
        )

        let args = ActionArguments(value: .string("some-url"), situation: .manualInvocation)
        let result = try await action.perform(arguments: args)
        XCTAssertNil(result)

        await self.fulfillment(of: [urlChecked, scheduled])
    }

    func testExtendSchedule() async throws {
        let urlChecked = expectation(description: "url checked")
        let scheduled = expectation(description: "scheduled")

        let expectedMessage = InAppMessage(
            name: "Landing Page https://some-url",
            displayContent: .html(
                .init(
                    url: "https://some-url",
                    requiresConnectivity: false,
                    borderRadius: 20
                )
            ),
            isReportingEnabled: false,
            displayBehavior: .immediate
        )

        let action = LandingPageAction(
            borderRadius: 10,
            scheduleExtender: { args, schedule in
                schedule.group = "some-group"
                guard case .inAppMessage(var message) = schedule.data else { return }
                guard case .html(var html) = message.displayContent else { return }
                html.borderRadius = 20.0

                message.displayContent = .html(html)
                schedule.data = .inAppMessage(message)
            },
            allowListChecker: { url in
                XCTAssertEqual("https://some-url", url.absoluteString)
                urlChecked.fulfill()
                return true
            },
            scheduler: { schedule in
                XCTAssertEqual(schedule.data, .inAppMessage(expectedMessage))
                XCTAssertEqual(schedule.triggers.count, 1)
                XCTAssertEqual(schedule.triggers[0].type, .activeSession)
                XCTAssertEqual(schedule.triggers[0].goal, 1.0)
                XCTAssertTrue(schedule.bypassHoldoutGroups!)
                XCTAssertEqual(schedule.productID, "landing_page")
                XCTAssertEqual(schedule.priority, Int.min)
                scheduled.fulfill()
            }
        )

        let args = ActionArguments(value: .string("some-url"), situation: .manualInvocation)
        let result = try await action.perform(arguments: args)
        XCTAssertNil(result)

        await self.fulfillment(of: [urlChecked, scheduled])
    }

    func testRejectsURL() async throws {
        let expectation = expectation(description: "url checked")
        let action = LandingPageAction(
            borderRadius: 2,
            scheduleExtender: nil,
            allowListChecker: { url in
                XCTAssertEqual("https://some-url", url.absoluteString)
                expectation.fulfill()
                return false
            },
            scheduler: { schedule in
                XCTFail("Should skip scheduling")
            }
        )

        let args = ActionArguments(value: .string("https://some-url"), situation: .manualInvocation)

        do {
            _ = try await action.perform(arguments: args)
            XCTFail("should throw")
        } catch {}

        await self.fulfillment(of: [expectation])
    }

    func testReportingEnabled() async throws {
        let pushMetadata = AirshipJSON.object(["_": .string("some-send-ID")])

        let scheduled = expectation(description: "scheduled")

        let expectedMessage = InAppMessage(
            name: "Landing Page https://some-url",
            displayContent: .html(
                .init(
                    url: "https://some-url",
                    requiresConnectivity: false,
                    borderRadius: 10
                )
            ),
            isReportingEnabled: true,
            displayBehavior: .immediate
        )

        let action = LandingPageAction(
            borderRadius: 10,
            scheduleExtender: nil,
            allowListChecker: { url in
                return true
            },
            scheduler: { schedule in
                XCTAssertEqual(schedule.data, .inAppMessage(expectedMessage))
                XCTAssertEqual(schedule.triggers.count, 1)
                XCTAssertEqual(schedule.triggers[0].type, .activeSession)
                XCTAssertEqual(schedule.triggers[0].goal, 1.0)
                XCTAssertTrue(schedule.bypassHoldoutGroups!)
                XCTAssertEqual(schedule.productID, "landing_page")
                XCTAssertEqual(schedule.priority, Int.min)
                XCTAssertEqual(schedule.identifier, "some-send-ID")
                scheduled.fulfill()
            }
        )

        let args = ActionArguments(
            value: .string("https://some-url"),
            situation: .manualInvocation,
            metadata: [ActionArguments.pushPayloadJSONMetadataKey: pushMetadata]
        )

        let result = try await action.perform(arguments: args)
        XCTAssertNil(result)

        await self.fulfillment(of: [scheduled])
    }
}
