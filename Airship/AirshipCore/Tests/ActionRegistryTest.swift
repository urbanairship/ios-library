/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class ActionRegistryTest: AirshipBaseTest {

    private var registry: ActionRegistry!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.registry = ActionRegistry()
    }

    @MainActor
    func testRegisterAction() async {
        let action = EmptyAction()

        registry.registerEntry(
            names: ["name", "alias", "another-name"],
            entry: ActionEntry(action: action)
        )

        await validateIsRegistered(
            action: action,
            names: ["name", "alias", "another-name"]
        )
    }

    @MainActor
    func testRegisterActionClosure() async {
        let action = EmptyAction()

        var called = 0
        registry.registerEntry(
            names: ["name", "alias", "another-name"]
        ) {
            called += 1
            return ActionEntry(action: action)
        }

        await validateIsRegistered(
            action: action,
            names: ["name", "alias", "another-name"]
        )

        XCTAssertEqual(called, 1)
    }

    @MainActor
    func testRegisterActionNameConflict() async {
        let action = EmptyAction()
        let anotherAction = EmptyAction()

        registry.registerEntry(
            names: ["name", "alias", "another-name"],
            entry: ActionEntry(action: action)
        )

        await validateIsRegistered(
            action: action,
            names: ["name", "alias", "another-name"]
        )

        registry.registerEntry(
            names: ["name", "what"],
            entry: ActionEntry(action: anotherAction)
        )


        await validateIsRegistered(
            action: anotherAction,
            names: ["name", "what"]
        )

        // First entry should still be registered under 'alias' and 'another-name'
        await validateIsRegistered(
            action: action,
            names: ["alias", "another-name"]
        )
    }

    @MainActor
    func testUpdateAction() async {
        let action = EmptyAction()
        let other = EmptyAction()

        registry.registerEntry(
            names: ["name", "alias", "another-name"],
            entry: ActionEntry(action: action)
        )

        registry.updateEntry(name: "alias", action: other)
        await validateIsRegistered(
            action: other,
            names: ["name", "alias", "another-name"]
        )
    }

    @MainActor
    func testUpdateActionForSituation() async {
        let action = EmptyAction()
        let other = EmptyAction()

        registry.registerEntry(
            names: ["name", "alias", "another-name"],
            entry: ActionEntry(action: action)
        )

        registry.updateEntry(name: "alias", situation: .manualInvocation, action: other)
        await validateIsRegistered(
            action: action,
            names: ["name", "alias", "another-name"]
        )

        let entry = registry.entry(name: "name")!
        XCTAssertTrue(other === entry.action(situation: .manualInvocation))
    }

    func validateIsRegistered (
        action: AirshipAction,
        names: [String]
    ) async {
        for name in names {
            let entry = await self.registry.entry(name: name)
            XCTAssertTrue(entry?.action === action)
        }
    }

}
