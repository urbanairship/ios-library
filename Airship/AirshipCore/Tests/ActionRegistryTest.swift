/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class ActionRegistryTest: AirshipBaseTest {
    
    var registry: ActionRegistry?
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.registry = ActionRegistry()
    }

    /// Test registering an action
    func testRegisterAction() {
        let action = EmptyAction()
        let anotherAction = EmptyAction()

        let predicate = {(args: ActionArguments) -> Bool in
            return true
        }

        // Register an action
        var result = registry?.register(
            action,
            names: ["name", "alias", "another-name"])
        XCTAssertTrue(result!, "Action should register")
        XCTAssertNotNil(result)
        validateIsRegistered(
            action: action,
            names: ["name", "alias", "another-name"])

        // Register an action under a conflicting name
        result = registry?.register(
            anotherAction,
            names: ["name", "what"],
            predicate: predicate)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Action should register")
        validateIsRegistered(
            action: anotherAction,
            names: ["name", "what"],
            predicate: predicate)

        // First entry should still be registered under 'alias' and 'another-name'
        validateIsRegistered(
            action: action,
            names: ["alias", "another-name"])
    }

    /// Test registering an action class
    func testRegisterActionClass() {

        let actionClass = EmptyAction.self
        let anotherActionClass = AddTagsAction.self

        let predicate = TagsActionPredicate.self.init()

        let predicateBlock: ((ActionArguments) -> Bool)? = { args in
            return predicate.apply(args)
        }

        // Register an action
        var result = registry?.register(
            actionClass,
            names: ["name", "alias", "another-name"])
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Action should register")
        validateIsRegistered(
            actionClass: actionClass,
            names: ["name", "alias", "another-name"])

        // Register an action under a conflicting name
        result = self.registry?.register(
            anotherActionClass,
            names: ["name", "what"],
            predicate: predicateBlock)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Action should register")
        validateIsRegistered(
            actionClass: anotherActionClass,
            names: ["name", "what"],
            predicate: predicateBlock)

        // First entry should still be registered under 'alias' and 'another-name'
        validateIsRegistered(
            actionClass: actionClass,
            names: ["alias", "another-name"])
    }

    /// Test registryEntryForName: returns a registry entry whose name or alias matches
    func testregistryEntryForName() {
        let action = EmptyAction()
        self.registry?.register(
            action,
            names: ["name", "alias"])

        XCTAssertNotNil(self.registry?.registryEntry("name"), "RegistryEntry is not returning entries for names")
        XCTAssertNotNil(self.registry?.registryEntry("alias"), "RegistryEntry is not returning entries for aliases")
        XCTAssertNil(self.registry?.registryEntry("blah"), "RegistryEntry is returning entries for unregistered names or aliases")
    }

    /// Test addSituationOverride to an entry
    func testSituationOverride() {
        let action = EmptyAction()
        self.registry?.register(
            action,
            names: ["name", "alias"])

        let situationOverrideAction = EmptyAction()
        self.registry?.addSituationOverride(
            .foregroundPush,
            forEntryWithName: "alias",
            action: situationOverrideAction)

        let entry = self.registry?.registryEntry("name")
        XCTAssertNotNil(entry)
        XCTAssertEqual(action, entry!.action as! EmptyAction)
        XCTAssertEqual(situationOverrideAction, entry!.action(situation: .foregroundPush) as! EmptyAction)

        // Remove the situation override
        self.registry?.addSituationOverride(
            .foregroundPush,
            forEntryWithName: "name",
            action: nil)
        XCTAssertNotNil(entry)
        XCTAssertEqual(action, entry!.action(situation: .foregroundPush) as! EmptyAction)
    }

    /// Test addSituationOverride for invalid values
    func testSituationOverrideInvalid() {
        let situationOverrideAction = EmptyAction()

        let result = self.registry?.addSituationOverride(
            .foregroundPush,
            forEntryWithName: "name",
            action: situationOverrideAction)
        XCTAssertNotNil(result)
        XCTAssertFalse(result!, "Situation return NO if the registry for the name does not exist.")
    }

    /// Test updatePredicate with valid values
    func testUpdatePredicate() {
        let yesPredicate = { (args: ActionArguments) -> Bool in
            return true
        }
        let noPredicate = { (args: ActionArguments) -> Bool in
            return false
        }

        let action = EmptyAction()
        self.registry?.register(
            action,
            name: "name",
            predicate: yesPredicate)

        validateIsRegistered(
            action: action,
            names: ["name"],
            predicate: yesPredicate)

        // Update the predicate to noPredicate
        var result = self.registry?.update(
            noPredicate,
            forEntryWithName: "name")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Predicate should update on this action")
        validateIsRegistered(
            action: action,
            names: ["name"],
            predicate: noPredicate)

        // Clear the predicate
        result = self.registry?.update(
            nil,
            forEntryWithName: "name")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Predicate should update on this action")
        validateIsRegistered(
            action: action,
            names: ["name"])
    }

    /// Test updateAction with valid values
    func testUpdateAction() {
        let action = EmptyAction()
        let anotherAction = EmptyAction()
        
        self.registry?.register(
            action,
            name: "name")

        let result = self.registry?.update(
            anotherAction,
            forEntryWithName: "name")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Should allow updating action.")
        validateIsRegistered(
            action: anotherAction,
            names: ["name"])
    }

    /// Test updateActionClass
    func testUpdateActionClass() {
        let actionClass = EmptyAction.self
        let anotherActionClass = AddTagsAction.self

        self.registry?.register(
            actionClass,
            name: "name")

        let result = self.registry?.update(
            anotherActionClass,
            forEntryWithName: "name")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Should allow updating action.")
        validateIsRegistered(
            actionClass: anotherActionClass,
            names: ["name"])
    }

    /// Test updateAction with invalid values
    func testUpdateActionInvalid() {
        let action = EmptyAction()
        self.registry?.register(
            action,
            name: "name")

        let result = self.registry?.update(
            action,
            forEntryWithName: "not-found")
        XCTAssertNotNil(result)
        XCTAssertFalse(result!, "Update action should return NO if the registry for the name does not exist.")
    }

    /// Test updateActionClass with invalid values
    func testUpdateActionClassInvalid() {
        let actionClass = EmptyAction.self
        self.registry?.register(
            actionClass,
            name: "name")

        let result = self.registry?.update(
            actionClass,
            forEntryWithName: "not-found")
        XCTAssertNotNil(result)
        XCTAssertFalse(result!, "Update action should return NO if the registry for the name does not exist.")
    }

    /// Test addName with valid values
    func testAddName() {
        let action = EmptyAction()

        self.registry?.register(
            action,
            name: "name")
        var result = self.registry?.addName(
            "anotherName",
            forEntryWithName: "name")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Should be able to add names to any entry.")
        
        result = self.registry?.addName(
            "yetAnotherName",
            forEntryWithName: "anotherName")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Should be able to add names to any entry.")
        validateIsRegistered(
            action: action,
            names: ["name", "anotherName", "yetAnotherName"])
    }
    
    /**
     * Test addName with valid values
     */
    func testAddNameLazyLoad() {
        let actionClass = EmptyAction.self
        self.registry?.register(
            actionClass,
            name: "name")

        var result = self.registry?.addName(
            "anotherName",
            forEntryWithName: "name")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Should be able to add names to any entry.")
        
        result = self.registry?.addName(
            "yetAnotherName",
            forEntryWithName: "anotherName")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!, "Should be able to add names to any entry.")
        validateIsRegistered(
            actionClass: actionClass,
            names: ["name", "anotherName", "yetAnotherName"])
    }

    /**
     * Test removeName with valid values
     */
    func testRemoveName() {
        
        let actionClass = EmptyAction.self

        self.registry?.register(
            actionClass,
            names:["name", "anotherName"])

        self.registry?.removeName("name")
        validateIsRegistered(
            actionClass: actionClass,
            names:["anotherName"])
    }

    /**
     * Test removeEntry with valid values
     */
    func testRemoveEntry() {
        let action = EmptyAction()
        self.registry?.register(
            action,
            names:["name", "anotherName"])

        self.registry?.removeEntry("name")
        XCTAssertEqual(0, self.registry?.registeredEntries.count, "The entry should be dropped.")
    }

    /**
     * Test removeEntry with valid values on a lazy loading action
     */
    func testRemoveEntryLazyLoad() {
        self.registry?.register(
            EmptyAction.self,
            names:["name", "anotherName"])

        self.registry?.removeEntry("name")
        XCTAssertEqual(0, self.registry?.registeredEntries.count, "The entry should be dropped.")
    }

    /**
     * Test registeredEntries
     */
    func testRegisteredEntries() {
        let action = EmptyAction()
        self.registry?.register(
            action,
            names:["name", "anotherName"])
        XCTAssertEqual(1, self.registry?.registeredEntries.count, "Duplicate names should be ignored.");
    }

    /**
     * Test registeredEntries lazy loading actions
     */
    func testRegisteredEntriesLazyLoad() {
        self.registry?.register(
            EmptyAction.self,
            names:["name", "anotherName"])
        XCTAssertEqual(1, self.registry?.registeredEntries.count, "Duplicate names should be ignored.");
    }
    
    func testRegisterInvalidActionClass() {
        let result = self.registry?.register(
            NSObject.self,
            name:"myInvalidActionClass")
        XCTAssertNotNil(result)
        XCTAssertFalse(result!)
    }

    func validateIsRegistered (
        actionClass: AnyClass,
        names: [String],
        predicate: UAActionPredicate? = nil
    ) {
        let entry = self.registry?.registryEntry(names.first!)
        XCTAssertNotNil(entry, "Action is not registered")
        XCTAssertNotNil(entry!.action, "Action should lazy load")
        if predicate != nil {
            XCTAssertNotNil(entry!.predicate)
        }
        XCTAssertEqual(entry!.names, names, "Registered entry's names are incorrect")
    }

    func validateIsRegistered (
        action: EmptyAction,
        names: [String],
        predicate: UAActionPredicate? = nil
    ) {

        let entry = self.registry?.registryEntry(names.first!)

        XCTAssertNotNil(entry!, "Action is not registered")
        XCTAssertEqual(entry!.action as! EmptyAction, action, "Registered entry's action is incorrect")
        if predicate != nil {
            XCTAssertNotNil(entry!.predicate);
        }
        XCTAssertEqual(entry?.names, names, "Registered entry's names are incorrect")
    }
    
}
