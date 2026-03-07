/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
import Foundation

@Suite struct PasteboardActionTest {

    private let testPasteboard: TestPasteboard = TestPasteboard()
    private let action: PasteboardAction!


    init() {
        self.action = PasteboardAction(pasteboard: self.testPasteboard)
    }

    @Test
    func testAcceptsArguments() async throws {
        let validStringValue = "pasteboard string"
        let validDictValue = ["text": "pasteboard string"]

        let validSituations = [
            ActionSituation.foregroundInteractiveButton,
            ActionSituation.launchedFromPush,
            ActionSituation.manualInvocation,
            ActionSituation.webViewInvocation,
            ActionSituation.automation,
            ActionSituation.backgroundInteractiveButton,
        ]

        let rejectedSituations = [
            ActionSituation.foregroundPush,
            ActionSituation.backgroundPush
        ]

        for situation in validSituations {
            let args = ActionArguments(
                string: validStringValue,
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            #expect(result, "Should accept valid situation: \(situation)")
        }

        for situation in validSituations {
            let args = ActionArguments(
                value: try AirshipJSON.wrap(validDictValue),
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            #expect(result, "Should accept valid dictionary value in situation: \(situation)")
        }

        for situation in validSituations {
            let args = ActionArguments(
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            #expect(!result, "Should reject empty arguments in situation: \(situation)")
        }

        for situation in rejectedSituations {
            let args = ActionArguments(
                string: validStringValue,
                situation: situation
            )
            let result = await self.action.accepts(arguments: args)
            #expect(!result, "Should reject invalid situation: \(situation)")
        }
    }
    
    @Test
    @MainActor
    func testPerformWithString() async throws {
        let value = "pasteboard_string"
        let arguments = ActionArguments(string: value)
        
        let result = try await self.action.perform(arguments: arguments)
        
        #expect(result == arguments.value)
        #expect(testPasteboard.lastCopyValue == value)
    }
    
    @Test
    @MainActor
    func testPerformWithDictionary() async throws {
        let value = "pasteboard string"
        let arguments = ActionArguments(value: try AirshipJSON.wrap(["text": value]))
        
        let result = try await self.action.perform(arguments: arguments)
        
        #expect(result == arguments.value)
        #expect(testPasteboard.lastCopyValue == value)
    }
}

fileprivate final class TestPasteboard: AirshipPasteboardProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _lastCopyValue: String?
    
    var lastCopyValue: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastCopyValue
    }

    func copy(value: String, expiry: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        _lastCopyValue = value
    }

    func copy(value: String) {
        lock.lock()
        defer { lock.unlock() }
        _lastCopyValue = value
    }
}
