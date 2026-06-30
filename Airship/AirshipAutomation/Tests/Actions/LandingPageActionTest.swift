/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore

struct LandingPageActionTest {

    @Test
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
            #expect(result)
        }

        for situation in rejectedSituations {
            let args = ActionArguments(value: AirshipJSON.null, situation: situation)
            let result = await action.accepts(arguments: args)
            #expect(!(result))
        }
    }

    @Test
    func testSimpleURLArg() async throws {
        let expectedMessage = InAppMessage(
            name: "Landing Page https://some-url",
            displayContent: .html(
                .init(
                    url: "https://some-url",
                    requiresConnectivity: false,
                    borderRadius: 10
                )
            ),
            source: .pushAction,
            isReportingEnabled: false,
            displayBehavior: .immediate
        )

        try await confirmation("url checked") { urlChecked in
            try await confirmation("scheduled") { scheduled in
                let action = LandingPageAction(
                    borderRadius: 10,
                    scheduleExtender: nil,
                    allowListChecker: { url in
                        #expect("https://some-url" == url.absoluteString)
                        urlChecked()
                        return true
                    },
                    scheduler: { schedule in
                        #expect(schedule.data == .inAppMessage(expectedMessage))
                        #expect(schedule.triggers.count == 1)
                        #expect(schedule.triggers[0].type == EventAutomationTriggerType.activeSession.rawValue)
                        #expect(schedule.triggers[0].goal == 1.0)
                        #expect(schedule.bypassHoldoutGroups!)
                        #expect(schedule.productID == "landing_page")
                        #expect(schedule.queue == "landing_page")
                        #expect(schedule.priority == Int.min)
                        scheduled()
                    }
                )

                let args = ActionArguments(value: "https://some-url", situation: .manualInvocation)

                let result = try await action.perform(arguments: args)
                #expect(result == nil)
            }
        }
    }

    @Test
    func testDictionaryArgs() async throws {
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
            source: .pushAction,
            isReportingEnabled: false,
            displayBehavior: .immediate
        )

        try await confirmation("url checked") { urlChecked in
            try await confirmation("scheduled") { scheduled in
                let action = LandingPageAction(
                    borderRadius: 10,
                    scheduleExtender: nil,
                    allowListChecker: { url in
                        #expect("https://some-url" == url.absoluteString)
                        urlChecked()
                        return true
                    },
                    scheduler: { schedule in
                        #expect(schedule.data == .inAppMessage(expectedMessage))
                        #expect(schedule.triggers.count == 1)
                        #expect(schedule.triggers[0].type == EventAutomationTriggerType.activeSession.rawValue)
                        #expect(schedule.triggers[0].goal == 1.0)
                        #expect(schedule.bypassHoldoutGroups!)
                        #expect(schedule.productID == "landing_page")
                        #expect(schedule.queue == "landing_page")
                        #expect(schedule.priority == Int.min)
                        scheduled()
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
                #expect(result == nil)
            }
        }
    }

    @Test
    func testAppendSchema() async throws {
        let expectedMessage = InAppMessage(
            name: "Landing Page https://some-url",
            displayContent: .html(
                .init(
                    url: "https://some-url",
                    requiresConnectivity: false,
                    borderRadius: 10
                )
            ),
            source: .pushAction,
            isReportingEnabled: false,
            displayBehavior: .immediate
        )

        try await confirmation("url checked") { urlChecked in
            try await confirmation("scheduled") { scheduled in
                let action = LandingPageAction(
                    borderRadius: 10,
                    scheduleExtender: nil,
                    allowListChecker: { url in
                        #expect("https://some-url" == url.absoluteString)
                        urlChecked()
                        return true
                    },
                    scheduler: { schedule in
                        #expect(schedule.data == .inAppMessage(expectedMessage))
                        #expect(schedule.triggers.count == 1)
                        #expect(schedule.triggers[0].type == EventAutomationTriggerType.activeSession.rawValue)
                        #expect(schedule.triggers[0].goal == 1.0)
                        #expect(schedule.bypassHoldoutGroups!)
                        #expect(schedule.productID == "landing_page")
                        #expect(schedule.priority == Int.min)
                        scheduled()
                    }
                )

                let args = ActionArguments(value: "some-url", situation: .manualInvocation)
                let result = try await action.perform(arguments: args)
                #expect(result == nil)
            }
        }
    }

    @Test
    func testExtendSchedule() async throws {
        let expectedMessage = InAppMessage(
            name: "Landing Page https://some-url",
            displayContent: .html(
                .init(
                    url: "https://some-url",
                    requiresConnectivity: false,
                    borderRadius: 20
                )
            ),
            source: .pushAction,
            isReportingEnabled: false,
            displayBehavior: .immediate
        )

        try await confirmation("url checked") { urlChecked in
            try await confirmation("scheduled") { scheduled in
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
                        #expect("https://some-url" == url.absoluteString)
                        urlChecked()
                        return true
                    },
                    scheduler: { schedule in
                        #expect(schedule.data == .inAppMessage(expectedMessage))
                        #expect(schedule.triggers.count == 1)
                        #expect(schedule.triggers[0].type == EventAutomationTriggerType.activeSession.rawValue)
                        #expect(schedule.triggers[0].goal == 1.0)
                        #expect(schedule.bypassHoldoutGroups!)
                        #expect(schedule.productID == "landing_page")
                        #expect(schedule.priority == Int.min)
                        scheduled()
                    }
                )

                let args = ActionArguments(value: "some-url", situation: .manualInvocation)
                let result = try await action.perform(arguments: args)
                #expect(result == nil)
            }
        }
    }

    @Test
    func testRejectsURL() async throws {
        await confirmation("url checked") { confirmed in
            let action = LandingPageAction(
                borderRadius: 2,
                scheduleExtender: nil,
                allowListChecker: { url in
                    #expect("https://some-url" == url.absoluteString)
                    confirmed()
                    return false
                },
                scheduler: { schedule in
                    Issue.record("Should skip scheduling")
                }
            )

            let args = ActionArguments(value: "https://some-url", situation: .manualInvocation)

            do {
                _ = try await action.perform(arguments: args)
                Issue.record("should throw")
            } catch {}
        }
    }

    @Test
    func testReportingEnabled() async throws {
        let pushMetadata: AirshipJSON = ["_": "some-send-ID"]

        let expectedMessage = InAppMessage(
            name: "Landing Page https://some-url",
            displayContent: .html(
                .init(
                    url: "https://some-url",
                    requiresConnectivity: false,
                    borderRadius: 10
                )
            ),
            source: .pushAction,
            isReportingEnabled: true,
            displayBehavior: .immediate
        )

        try await confirmation("scheduled") { scheduled in
            let action = LandingPageAction(
                borderRadius: 10,
                scheduleExtender: nil,
                allowListChecker: { url in
                    return true
                },
                scheduler: { schedule in
                    #expect(schedule.data == .inAppMessage(expectedMessage))
                    #expect(schedule.triggers.count == 1)
                    #expect(schedule.triggers[0].type == EventAutomationTriggerType.activeSession.rawValue)
                    #expect(schedule.triggers[0].goal == 1.0)
                    #expect(schedule.bypassHoldoutGroups!)
                    #expect(schedule.productID == "landing_page")
                    #expect(schedule.priority == Int.min)
                    #expect(schedule.identifier == "some-send-ID")
                    #expect(schedule.sendMetadata == nil)
                    scheduled()
                }
            )

            let args = ActionArguments(
                value: "https://some-url",
                situation: .manualInvocation,
                metadata: [ActionArguments.pushPayloadJSONMetadataKey: pushMetadata]
            )

            let result = try await action.perform(arguments: args)
            #expect(result == nil)
        }
    }

    @Test
    func testSendMetadataPropagatedToSchedule() async throws {
        let pushMetadata: AirshipJSON = [
            "_": "some-send-ID",
            "com.urbanairship.metadata": "encoded-send-metadata"
        ]

        try await confirmation("scheduled") { scheduled in
            let action = LandingPageAction(
                borderRadius: 10,
                scheduleExtender: nil,
                allowListChecker: { _ in true },
                scheduler: { schedule in
                    #expect(schedule.sendMetadata == "encoded-send-metadata")
                    #expect(schedule.identifier == "some-send-ID")
                    scheduled()
                }
            )

            let args = ActionArguments(
                value: "https://some-url",
                situation: .manualInvocation,
                metadata: [ActionArguments.pushPayloadJSONMetadataKey: pushMetadata]
            )

            let result = try await action.perform(arguments: args)
            #expect(result == nil)
        }
    }

    @Test
    func testMessageSourceIsPushAction() async throws {
        try await confirmation("scheduled") { scheduled in
            let action = LandingPageAction(
                borderRadius: 10,
                scheduleExtender: nil,
                allowListChecker: { _ in true },
                scheduler: { schedule in
                    guard case .inAppMessage(let message) = schedule.data else {
                        Issue.record("Expected inAppMessage schedule data")
                        return
                    }
                    #expect(message.source == .pushAction)
                    scheduled()
                }
            )

            let args = ActionArguments(
                value: "https://some-url",
                situation: .manualInvocation
            )

            let result = try await action.perform(arguments: args)
            #expect(result == nil)
        }
    }
}
