import Testing

@testable import AirshipCore

@MainActor
@Suite struct RateAppActionTest {
    private let testAppRater = TestAppRater()
    private let configItunesID = AirshipAtomicValue<String?>(nil)
    private let action: RateAppAction

    init() async throws {
        let configItunesID = self.configItunesID
        self.action = RateAppAction(
            appRater: self.testAppRater
        ) {
            return configItunesID.value
        }
    }

    @Test
    func testShowPrompt() async throws {
        let args: [String: Any] = [
            "show_link_prompt": true,
            "itunes_id": "test id",
        ]

        let result = try await action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(args),
                situation: .manualInvocation
            )
        )
        #expect(result == nil)
        #expect(testAppRater.showPromptCalled)
        #expect(testAppRater.openStoreItunesID == nil)
    }

    @Test
    func testOpenAppStore() async throws {
        let args: [String: Any] = [
            "itunes_id": "test id"
        ]

        let result = try await action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(args),
                situation: .manualInvocation
            )
        )
        #expect(result == nil)
        #expect(!(testAppRater.showPromptCalled))
        #expect("test id" == testAppRater.openStoreItunesID)
    }

    @Test
    func testOpenAppStoreFallbackItunesID() async throws {
        configItunesID.value = "config iTunes ID"
        let args: [String: Any] = [:]

        let result = try await action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(args),
                situation: .manualInvocation
            )
        )
        #expect(result == nil)
        #expect(!(testAppRater.showPromptCalled))
        #expect(configItunesID.value == testAppRater.openStoreItunesID)
    }

    @Test
    func testNilConfig() async throws {
        configItunesID.value = "config iTunes ID"

        let result = try await action.perform(arguments:
            ActionArguments(
                value: AirshipJSON.null,
                situation: .manualInvocation
            )
        )
        #expect(result == nil)
        #expect(!(testAppRater.showPromptCalled))
        #expect(configItunesID.value == testAppRater.openStoreItunesID)
    }

    @Test
    func testNoItunesID() async throws {
        configItunesID.value = nil

        do {
            _ = try await action.perform(arguments:
                ActionArguments(
                    value: AirshipJSON.null,
                    situation: .manualInvocation
                )
            )
            Issue.record("should throw")
        } catch {}

        #expect(!(testAppRater.showPromptCalled))
        #expect(testAppRater.openStoreItunesID == nil)
    }

    @Test
    func testInvalidArgs() async throws {
        configItunesID.value = "config id"
        do {
            _ = try await action.perform(arguments:
                ActionArguments(
                    string: "invalid"
                )
            )
            Issue.record("should throw")
        } catch {}
        #expect(!(testAppRater.showPromptCalled))
        #expect(testAppRater.openStoreItunesID == nil)
    }

    @Test
    func testAcceptsArguments() async throws {
        let validSituations: [ActionSituation] = [
            .manualInvocation,
            .automation,
            .foregroundPush,
            .foregroundInteractiveButton,
            .webViewInvocation,
            .launchedFromPush,
        ]

        for situation in validSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(result)
        }
    }

    @Test
    func testRejectsArguments() async throws {
        let invalidSituations: [ActionSituation] = [
            .backgroundPush,
            .backgroundInteractiveButton,
        ]

        for situation in invalidSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(!(result))
        }
    }


    fileprivate class TestAppRater: AppRaterProtocol, @unchecked Sendable {
        var showPromptCalled = false
        var openStoreItunesID: String? = nil

        func openStore(itunesID: String) async throws {
            openStoreItunesID = itunesID
        }

        func showPrompt() throws {
            showPromptCalled = true
        }
    }
}
