/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#import <XCTest/XCTest.h>
#import "UAActionRegistrar+Internal.h"

@interface UAActionRegistrarTest : XCTestCase

@end

@implementation UAActionRegistrarTest
UAActionRegistrar *registrar;

- (void)setUp {
    [super setUp];

    registrar = [[UAActionRegistrar alloc] init];

    // Clear any default actions
    [registrar.reservedEntryNames removeAllObjects];
    [registrar.registeredActionEntries removeAllObjects];
}

- (void)tearDown {

    [super tearDown];
}

/**
 * Test registering an action
 */
- (void)testRegisterAction {
    UAAction *action = [[UAAction alloc] init];
    UAAction *anotherAction = [[UAAction alloc] init];

    UAActionPredicate predicate = ^(UAActionArguments *args) { return YES; };

    // Register an action
    BOOL result = [registrar registerAction:action names:@[@"name", @"alias", @"another-name"]];
    XCTAssertTrue(result, @"Action should register");
    [self validateActionIsRegistered:action names:@[@"name", @"alias", @"another-name"] predicate:nil];

    // Register an action under a conflicting name
    result = [registrar registerAction:anotherAction names:@[@"name", @"what"] predicate:predicate];
    XCTAssertTrue(result, @"Action should register");
    [self validateActionIsRegistered:anotherAction names:@[@"name", @"what"] predicate:predicate];

    // First entry should still be registered under 'alias' and 'another-name'
    [self validateActionIsRegistered:action names:@[@"alias", @"another-name"] predicate:nil];
}

/**
 * Test that registering a nil action, an empty name, or trying to register
 * a reserved name returns NO and does not register the action.
 */
- (void)testRegisterActionInvalid {
    UAAction *action = [[UAAction alloc] init];
    [registrar registerReservedAction:action name:@"reserved" predicate:nil];

    XCTAssertFalse([registrar registerAction:nil name:@"some-name"], @"Should not be able to register a nil action");
    XCTAssertFalse([registrar registerAction:action name:nil], @"Should not be able to register an entry under a nil name.");
    XCTAssertFalse([registrar registerAction:action name:@"reserved"], @"Should not be able to register a reserved action name.");
}

/**
 * Test registering a reserved action
 */
- (void)testRegisterReservedAction {
    UAAction *action = [[UAAction alloc] init];
    UAActionPredicate predicate = ^(UAActionArguments *args) { return YES; };

    [registrar registerReservedAction:action name:@"reserved" predicate:nil];
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:nil];

    [registrar registerReservedAction:action name:@"another-reserved" predicate:predicate];
    [self validateActionIsRegistered:action names:@[@"another-reserved"] predicate:predicate];

    XCTAssertFalse([registrar registerReservedAction:action name:@"reserved" predicate:nil], @"Should not be able to reregister a reserved action");
    XCTAssertEqual((NSUInteger)0, [registrar registeredEntries].count, @"Reserved actions should not be in the list of registered entries.");
}

/**
 * Test registryEntryForName: returns a registry entry whose name or alias matches
 */
- (void)testregistryEntryForName {
    UAAction *action = [[UAAction alloc] init];
    [registrar registerAction:action names:@[@"name", @"alias"]];

    XCTAssertNotNil([registrar registryEntryWithName:@"name"], "RegistryEntry is not returning entries for names");
    XCTAssertNotNil([registrar registryEntryWithName:@"alias"], "RegistryEntry is not returning entries for aliases");
    XCTAssertNil([registrar registryEntryWithName:@"blah"], "RegistryEntry is returning entries for unregistered names or aliases");
}

/**
 * Test addSituationOverride to an entry
 */
- (void)testSituationOverride {
    UAAction *action = [[UAAction alloc] init];
    [registrar registerAction:action names:@[@"name", @"alias"]];

    UAAction *situationOverrideAction = [[UAAction alloc] init];
    XCTAssertTrue([registrar addSituationOverride:UASituationForegroundPush forEntryWithName:@"alias" action:situationOverrideAction], @"Situation return YES on a valid, unreserved situation");

    UAActionRegistryEntry *entry = [registrar registryEntryWithName:@"name"];
    XCTAssertEqual(action, entry.action, @"Original action should be left unharmed");
    XCTAssertEqual(situationOverrideAction, [entry actionForSituation:UASituationForegroundPush], @"Action for the situation should be the situationOverrideAction");

    // Remove the situation override
    XCTAssertTrue([registrar addSituationOverride:UASituationForegroundPush forEntryWithName:@"name" action:nil], @"Situation return YES on a valid, unreserved situation");
    XCTAssertEqual(action, [entry actionForSituation:UASituationForegroundPush], @"Action for the situation should be the default action");
}

/**
 * Test addSituationOverride for invalid values
 */
- (void)testSituationOverrideInvalid {
    UAAction *situationOverrideAction = [[UAAction alloc] init];

    XCTAssertFalse([registrar addSituationOverride:UASituationForegroundPush forEntryWithName:@"name" action:situationOverrideAction], @"Situation return NO if the registry for the name does not exist.");
    XCTAssertFalse([registrar addSituationOverride:UASituationForegroundPush forEntryWithName:nil action:situationOverrideAction], @"Situation return NO if the name is nil.");
    XCTAssertFalse([registrar addSituationOverride:UASituationForegroundPush forEntryWithName:kUAIncomingPushActionRegistryName action:situationOverrideAction], @"Situation return NO if the action is reserved.");
}

/**
 * Test updatePredicate with valid values
 */
- (void)testUpdatePredicate {
    UAActionPredicate yesPredicate = ^(UAActionArguments *args) { return YES; };
    UAActionPredicate noPredicate = ^(UAActionArguments *args) { return NO; };

    UAAction *action = [[UAAction alloc] init];
    [registrar registerAction:action name:@"name" predicate:yesPredicate];

    [self validateActionIsRegistered:action names:@[@"name"] predicate:yesPredicate];

    // Update the predicate to noPredicate
    XCTAssertTrue([registrar updatePredicate:noPredicate forEntryWithName:@"name"], @"Predicate should update on this unreserved action");
    [self validateActionIsRegistered:action names:@[@"name"] predicate:noPredicate];

    // Clear the predicate
     XCTAssertTrue([registrar updatePredicate:nil forEntryWithName:@"name"], "Predicate should update on this unreserved action");
    [self validateActionIsRegistered:action names:@[@"name"] predicate:nil];
}

/**
 * Test updatePredicate with invalid values
 */
- (void)testUpdatePredicateInvalid {
    UAAction *action = [[UAAction alloc] init];
    UAActionPredicate predicate = ^(UAActionArguments *args) { return YES; };
    [registrar registerReservedAction:action name:@"reserved" predicate:predicate];

    XCTAssertFalse([registrar updatePredicate:nil forEntryWithName:@"name"], @"Update predicate should return NO if the registry for the name does not exist.");
    XCTAssertFalse([registrar updatePredicate:nil forEntryWithName:@"reserved"], @"Update predicate should return NO if the entry is reserved");
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:predicate];
}

/**
 * Test updateAction with valid values
 */
- (void)testUpdateAction {
    UAAction *anotherAction = [[UAAction alloc] init];
    UAAction *action = [[UAAction alloc] init];

    [registrar registerAction:action name:@"name"];

    XCTAssertTrue([registrar updateAction:anotherAction forEntryWithName:@"name"], @"Should allow updating action if its not reserved.");
    [self validateActionIsRegistered:anotherAction names:@[@"name"] predicate:nil];
}

/**
 * Test updateAction with invalid values
 */
- (void)testUpdateActionInvalid {
    UAAction *action = [[UAAction alloc] init];
    UAActionPredicate predicate = ^(UAActionArguments *args) { return YES; };
    [registrar registerReservedAction:action name:@"reserved" predicate:predicate];
    [registrar registerAction:action name:@"name"];

    XCTAssertFalse([registrar updateAction:nil forEntryWithName:@"not-found"], @"Update action should return NO if the registry for the name does not exist.");

    XCTAssertFalse([registrar updateAction:nil forEntryWithName:@"name"], @"Update action should return NO if the action is nil.");
    [self validateActionIsRegistered:action names:@[@"name"] predicate:nil];

    XCTAssertFalse([registrar updateAction:action forEntryWithName:@"reserved"], @"Update action should return NO if the entry is reserved");
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:predicate];
}

/**
 * Test addName with valid values
 */
- (void)testAddName {
    UAAction *action = [[UAAction alloc] init];

    [registrar registerAction:action name:@"name"];
    [registrar registerReservedAction:action name:@"reserved" predicate:nil];

    XCTAssertTrue([registrar addName:@"anotherName" forEntryWithName:@"name"], @"Should be able to add names to any entry.");
    XCTAssertTrue([registrar addName:@"yetAnotherName" forEntryWithName:@"anotherName"], @"Should be able to add names to any entry.");
    [self validateActionIsRegistered:action names:@[@"name", @"anotherName", @"yetAnotherName"] predicate:nil];

    // Check conflict
    XCTAssertTrue([registrar addName:@"reservedAlias" forEntryWithName:@"name"], @"Should be able to add a non original resereved name to another entry.");
    [self validateActionIsRegistered:action names:@[@"name", @"anotherName", @"yetAnotherName", @"reservedAlias"] predicate:nil];
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:nil];

    // Adding a name to an entry with a name already
    XCTAssertTrue([registrar addName:@"reservedAlias" forEntryWithName:@"reservedAlias"], @"Should be able to add a name to the entry who's name is the name you are adding.  Yeah.");
    [self validateActionIsRegistered:action names:@[@"name", @"anotherName", @"yetAnotherName", @"reservedAlias"] predicate:nil];
}

/**
 * Test addName invalid values
 */
- (void)testAddNameInvalid {
    UAAction *action = [[UAAction alloc] init];
    [registrar registerReservedAction:action name:@"reserved" predicate:nil];
    [registrar registerReservedAction:action name:@"anotherReserved" predicate:nil];

    XCTAssertFalse([registrar addName:@"anotherReserved" forEntryWithName:@"reserved"], @"Should not be able to add a reserved name to another entry.");
    XCTAssertFalse([registrar addName:@"someName" forEntryWithName:@"not found"], @"Should not be able to add a name to a not found entry.");
    XCTAssertFalse([registrar addName:@"randomName" forEntryWithName:@"reserved"], @"Should not be able to add a name to a reserved entry.");

}

/**
 * Test removeName with valid values
 */
- (void)testRemoveName {
    UAAction *action = [[UAAction alloc] init];

    [registrar registerAction:action names:@[@"name", @"anotherName"]];

    XCTAssertTrue([registrar removeName:@"name"], @"Should be able to remove a non reserved name.");
    [self validateActionIsRegistered:action names:@[@"anotherName"] predicate:nil];

    XCTAssertTrue([registrar removeName:@"anotherName"], @"Should be able to remove a non reserved name.");
    XCTAssertEqual((NSUInteger) 0, [registrar.reservedEntryNames count], @"If no names reference an entry, it should be dropped.");

    [registrar registerReservedAction:action name:@"reserved" predicate:nil];
    [registrar addName:@"reservedAlias" forEntryWithName:@"reserved"];

    XCTAssertTrue([registrar removeName:@"reservedAlias"], @"Should be able to remove the name that was added to a reserved action.");
    XCTAssertTrue([registrar removeName:@"notFound"], @"Removing a name that does not exist should return YES.");
}

/**
 * Test removeName invalid values
 */
- (void)testRemoveNameInvalid {
    UAAction *action = [[UAAction alloc] init];
    [registrar registerReservedAction:action name:@"reserved" predicate:nil];

    XCTAssertFalse([registrar removeName:@"reserved"], @"Should not be able to remove a reserved name.");
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:nil];
}

/**
 * Test removeEntry with valid values
 */
- (void)testRemoveEntry {
    UAAction *action = [[UAAction alloc] init];

    [registrar registerAction:action names:@[@"name", @"anotherName"]];

    XCTAssertTrue([registrar removeEntryWithName:@"name"], @"Should be able to remove a non reserved entry.");
    XCTAssertEqual((NSUInteger) 0, [registrar.reservedEntryNames count], @"The entry should be dropped.");

    XCTAssertTrue([registrar removeName:@"notFound"], @"Removing a name that does not exist should return YES.");
}

/**
 * Test removeEntry invalid values
 */
- (void)testRemoveEntryInvalid {
    UAAction *action = [[UAAction alloc] init];
    [registrar registerReservedAction:action name:@"reserved" predicate:nil];

    XCTAssertFalse([registrar removeEntryWithName:@"reserved"], @"Should not be able to remove a reserved entry.");
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:nil];
}


/**
 * Test registeredEntries
 */
- (void)testRegisteredEntries {
    UAAction *action = [[UAAction alloc] init];
    [registrar registerAction:action names:@[@"name", @"anotherName"]];
    XCTAssertEqual((NSUInteger)1, [registrar.registeredEntries count], @"Duplicate names should be ignored.");

    [registrar registerReservedAction:action name:@"reserved" predicate:nil];
    XCTAssertEqual((NSUInteger)1, [registrar.registeredEntries count], @"Reserved entries should be ignored");
}

- (void)validateActionIsRegistered:(UAAction *)action
                              names:(NSArray *)names
                         predicate:(UAActionPredicate)predicate {

    UAActionRegistryEntry *entry = [registrar registryEntryWithName:[names firstObject]];

    XCTAssertNotNil(entry, @"Action is not registered");
    XCTAssertEqualObjects(entry.action, action, @"Registered entry's action is incorrect");
    XCTAssertEqualObjects(entry.predicate, predicate, @"Registered entry's predicate is incorrect");
    XCTAssertTrue([entry.names isEqualToArray:names], @"Registered entry's names are incorrect");
}

@end
