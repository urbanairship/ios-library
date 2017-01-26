/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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
#import <OCMock/OCMock.h>
#import "UAActionRegistry+Internal.h"
#import "UAApplicationMetrics+Internal.h"
#import "UAirship+Internal.h"

@interface UAActionRegistryTest : XCTestCase
@property (nonatomic, strong) UAActionRegistry *registry;
@property (nonatomic, strong) id mockMetrics;
@property (nonatomic, strong) id mockAirship;

@end

@implementation UAActionRegistryTest


- (void)setUp {
    [super setUp];

    self.registry = [[UAActionRegistry alloc] init];

    // Clear any default actions
    [self.registry.reservedEntryNames removeAllObjects];
    [self.registry.registeredActionEntries removeAllObjects];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];

    self.mockMetrics = [OCMockObject niceMockForClass:[UAApplicationMetrics class]];
    [[[self.mockAirship stub] andReturn:self.mockMetrics] applicationMetrics];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockMetrics stopMocking];

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
    BOOL result = [self.registry registerAction:action names:@[@"name", @"alias", @"another-name"]];
    XCTAssertTrue(result, @"Action should register");
    [self validateActionIsRegistered:action names:@[@"name", @"alias", @"another-name"] predicate:nil];

    // Register an action under a conflicting name
    result = [self.registry registerAction:anotherAction names:@[@"name", @"what"] predicate:predicate];
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
    [self.registry registerReservedAction:action name:@"reserved" predicate:nil];

    XCTAssertFalse([self.registry registerAction:action name:@"reserved"], @"Should not be able to register a reserved action name.");
}

/**
 * Test registering a reserved action
 */
- (void)testRegisterReservedAction {
    UAAction *action = [[UAAction alloc] init];
    UAActionPredicate predicate = ^(UAActionArguments *args) { return YES; };

    [self.registry registerReservedAction:action name:@"reserved" predicate:nil];
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:nil];

    [self.registry registerReservedAction:action name:@"another-reserved" predicate:predicate];
    [self validateActionIsRegistered:action names:@[@"another-reserved"] predicate:predicate];

    XCTAssertFalse([self.registry registerReservedAction:action name:@"reserved" predicate:nil], @"Should not be able to reregister a reserved action");
    XCTAssertEqual((NSUInteger)0, [self.registry registeredEntries].count, @"Reserved actions should not be in the list of registered entries.");
}

/**
 * Test registryEntryForName: returns a registry entry whose name or alias matches
 */
- (void)testregistryEntryForName {
    UAAction *action = [[UAAction alloc] init];
    [self.registry registerAction:action names:@[@"name", @"alias"]];

    XCTAssertNotNil([self.registry registryEntryWithName:@"name"], "RegistryEntry is not returning entries for names");
    XCTAssertNotNil([self.registry registryEntryWithName:@"alias"], "RegistryEntry is not returning entries for aliases");
    XCTAssertNil([self.registry registryEntryWithName:@"blah"], "RegistryEntry is returning entries for unregistered names or aliases");
}

/**
 * Test addSituationOverride to an entry
 */
- (void)testSituationOverride {
    UAAction *action = [[UAAction alloc] init];
    [self.registry registerAction:action names:@[@"name", @"alias"]];

    UAAction *situationOverrideAction = [[UAAction alloc] init];
    XCTAssertTrue([self.registry addSituationOverride:UASituationForegroundPush forEntryWithName:@"alias" action:situationOverrideAction], @"Situation return YES on a valid, unreserved situation");

    UAActionRegistryEntry *entry = [self.registry registryEntryWithName:@"name"];
    XCTAssertEqualObjects(action, entry.action, @"Original action should be left unharmed");
    XCTAssertEqualObjects(situationOverrideAction, [entry actionForSituation:UASituationForegroundPush], @"Action for the situation should be the situationOverrideAction");

    // Remove the situation override
    XCTAssertTrue([self.registry addSituationOverride:UASituationForegroundPush forEntryWithName:@"name" action:nil], @"Situation return YES on a valid, unreserved situation");
    XCTAssertEqualObjects(action, [entry actionForSituation:UASituationForegroundPush], @"Action for the situation should be the default action");
}

/**
 * Test addSituationOverride for invalid values
 */
- (void)testSituationOverrideInvalid {
    UAAction *situationOverrideAction = [[UAAction alloc] init];

    XCTAssertFalse([self.registry addSituationOverride:UASituationForegroundPush forEntryWithName:@"name" action:situationOverrideAction], @"Situation return NO if the registry for the name does not exist.");
    XCTAssertFalse([self.registry addSituationOverride:UASituationForegroundPush forEntryWithName:kUAIncomingInAppMessageActionDefaultRegistryName action:situationOverrideAction], @"Situation return NO if the action is reserved.");
}

/**
 * Test updatePredicate with valid values
 */
- (void)testUpdatePredicate {
    UAActionPredicate yesPredicate = ^(UAActionArguments *args) { return YES; };
    UAActionPredicate noPredicate = ^(UAActionArguments *args) { return NO; };

    UAAction *action = [[UAAction alloc] init];
    [self.registry registerAction:action name:@"name" predicate:yesPredicate];

    [self validateActionIsRegistered:action names:@[@"name"] predicate:yesPredicate];

    // Update the predicate to noPredicate
    XCTAssertTrue([self.registry updatePredicate:noPredicate forEntryWithName:@"name"], @"Predicate should update on this unreserved action");
    [self validateActionIsRegistered:action names:@[@"name"] predicate:noPredicate];

    // Clear the predicate
     XCTAssertTrue([self.registry updatePredicate:nil forEntryWithName:@"name"], "Predicate should update on this unreserved action");
    [self validateActionIsRegistered:action names:@[@"name"] predicate:nil];
}

/**
 * Test updatePredicate with invalid values
 */
- (void)testUpdatePredicateInvalid {
    UAAction *action = [[UAAction alloc] init];
    UAActionPredicate predicate = ^(UAActionArguments *args) { return YES; };
    [self.registry registerReservedAction:action name:@"reserved" predicate:predicate];

    XCTAssertFalse([self.registry updatePredicate:nil forEntryWithName:@"name"], @"Update predicate should return NO if the registry for the name does not exist.");
    XCTAssertFalse([self.registry updatePredicate:nil forEntryWithName:@"reserved"], @"Update predicate should return NO if the entry is reserved");
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:predicate];
}

/**
 * Test updateAction with valid values
 */
- (void)testUpdateAction {
    UAAction *anotherAction = [[UAAction alloc] init];
    UAAction *action = [[UAAction alloc] init];

    [self.registry registerAction:action name:@"name"];

    XCTAssertTrue([self.registry updateAction:anotherAction forEntryWithName:@"name"], @"Should allow updating action if its not reserved.");
    [self validateActionIsRegistered:anotherAction names:@[@"name"] predicate:nil];
}

/**
 * Test updateAction with invalid values
 */
- (void)testUpdateActionInvalid {
    UAAction *action = [[UAAction alloc] init];
    UAActionPredicate predicate = ^(UAActionArguments *args) { return YES; };
    [self.registry registerReservedAction:action name:@"reserved" predicate:predicate];
    [self.registry registerAction:action name:@"name"];

    XCTAssertFalse([self.registry updateAction:action forEntryWithName:@"not-found"], @"Update action should return NO if the registry for the name does not exist.");

    XCTAssertFalse([self.registry updateAction:action forEntryWithName:@"reserved"], @"Update action should return NO if the entry is reserved");
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:predicate];
}

/**
 * Test addName with valid values
 */
- (void)testAddName {
    UAAction *action = [[UAAction alloc] init];

    [self.registry registerAction:action name:@"name"];
    [self.registry registerReservedAction:action name:@"reserved" predicate:nil];

    XCTAssertTrue([self.registry addName:@"anotherName" forEntryWithName:@"name"], @"Should be able to add names to any entry.");
    XCTAssertTrue([self.registry addName:@"yetAnotherName" forEntryWithName:@"anotherName"], @"Should be able to add names to any entry.");
    [self validateActionIsRegistered:action names:@[@"name", @"anotherName", @"yetAnotherName"] predicate:nil];

    // Check conflict
    XCTAssertTrue([self.registry addName:@"reservedAlias" forEntryWithName:@"name"], @"Should be able to add a non original resereved name to another entry.");
    [self validateActionIsRegistered:action names:@[@"name", @"anotherName", @"yetAnotherName", @"reservedAlias"] predicate:nil];
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:nil];

    // Adding a name to an entry with a name already
    XCTAssertTrue([self.registry addName:@"reservedAlias" forEntryWithName:@"reservedAlias"], @"Should be able to add a name to the entry who's name is the name you are adding.  Yeah.");
    [self validateActionIsRegistered:action names:@[@"name", @"anotherName", @"yetAnotherName", @"reservedAlias"] predicate:nil];
}

/**
 * Test addName invalid values
 */
- (void)testAddNameInvalid {
    UAAction *action = [[UAAction alloc] init];
    [self.registry registerReservedAction:action name:@"reserved" predicate:nil];
    [self.registry registerReservedAction:action name:@"anotherReserved" predicate:nil];

    XCTAssertFalse([self.registry addName:@"anotherReserved" forEntryWithName:@"reserved"], @"Should not be able to add a reserved name to another entry.");
    XCTAssertFalse([self.registry addName:@"someName" forEntryWithName:@"not found"], @"Should not be able to add a name to a not found entry.");
    XCTAssertFalse([self.registry addName:@"randomName" forEntryWithName:@"reserved"], @"Should not be able to add a name to a reserved entry.");

}

/**
 * Test removeName with valid values
 */
- (void)testRemoveName {
    UAAction *action = [[UAAction alloc] init];

    [self.registry registerAction:action names:@[@"name", @"anotherName"]];

    XCTAssertTrue([self.registry removeName:@"name"], @"Should be able to remove a non reserved name.");
    [self validateActionIsRegistered:action names:@[@"anotherName"] predicate:nil];

    XCTAssertTrue([self.registry removeName:@"anotherName"], @"Should be able to remove a non reserved name.");
    XCTAssertEqual((NSUInteger) 0, [self.registry.reservedEntryNames count], @"If no names reference an entry, it should be dropped.");

    [self.registry registerReservedAction:action name:@"reserved" predicate:nil];
    [self.registry addName:@"reservedAlias" forEntryWithName:@"reserved"];

    XCTAssertTrue([self.registry removeName:@"reservedAlias"], @"Should be able to remove the name that was added to a reserved action.");
    XCTAssertTrue([self.registry removeName:@"notFound"], @"Removing a name that does not exist should return YES.");
}

/**
 * Test removeName invalid values
 */
- (void)testRemoveNameInvalid {
    UAAction *action = [[UAAction alloc] init];
    [self.registry registerReservedAction:action name:@"reserved" predicate:nil];

    XCTAssertFalse([self.registry removeName:@"reserved"], @"Should not be able to remove a reserved name.");
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:nil];
}

/**
 * Test removeEntry with valid values
 */
- (void)testRemoveEntry {
    UAAction *action = [[UAAction alloc] init];

    [self.registry registerAction:action names:@[@"name", @"anotherName"]];

    XCTAssertTrue([self.registry removeEntryWithName:@"name"], @"Should be able to remove a non reserved entry.");
    XCTAssertEqual((NSUInteger) 0, [self.registry.registeredEntries count], @"The entry should be dropped.");

    XCTAssertTrue([self.registry removeName:@"notFound"], @"Removing a name that does not exist should return YES.");
}

/**
 * Test removeEntry invalid values
 */
- (void)testRemoveEntryInvalid {
    UAAction *action = [[UAAction alloc] init];
    [self.registry registerReservedAction:action name:@"reserved" predicate:nil];

    XCTAssertFalse([self.registry removeEntryWithName:@"reserved"], @"Should not be able to remove a reserved entry.");
    [self validateActionIsRegistered:action names:@[@"reserved"] predicate:nil];
}


/**
 * Test registeredEntries
 */
- (void)testRegisteredEntries {
    UAAction *action = [[UAAction alloc] init];
    [self.registry registerAction:action names:@[@"name", @"anotherName"]];
    XCTAssertEqual((NSUInteger)1, [self.registry.registeredEntries count], @"Duplicate names should be ignored.");

    [self.registry registerReservedAction:action name:@"reserved" predicate:nil];
    XCTAssertEqual((NSUInteger)1, [self.registry.registeredEntries count], @"Reserved entries should be ignored");
}

- (void)validateActionIsRegistered:(UAAction *)action
                              names:(NSArray *)names
                         predicate:(UAActionPredicate)predicate {

    UAActionRegistryEntry *entry = [self.registry registryEntryWithName:[names firstObject]];

    XCTAssertNotNil(entry, @"Action is not registered");
    XCTAssertEqualObjects(entry.action, action, @"Registered entry's action is incorrect");
    XCTAssertEqualObjects(entry.predicate, predicate, @"Registered entry's predicate is incorrect");
    XCTAssertTrue([entry.names isEqualToArray:names], @"Registered entry's names are incorrect");
}

/**
 * Test landing page default predicate
 */
- (void)testLandingPageDefaultPredicate {

    __block NSDate *date;
    [[[self.mockMetrics stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&date];
    }] lastApplicationOpenDate];


    [self.registry registerDefaultActions];
    UAActionRegistryEntry *entry = [self.registry registryEntryWithName:kUALandingPageActionDefaultRegistryName];

    XCTAssertNotNil(entry, "Landing page should be registered by default");
    XCTAssertNotNil(entry.predicate, "Landing page should have a default predicate");


    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"some-value"
                                                      withSituation:UASituationBackgroundPush];

    XCTAssertFalse(entry.predicate(args), "Should not accept background push if the app has never been opened before");


    date = [NSDate dateWithTimeIntervalSince1970:0];
    XCTAssertFalse(entry.predicate(args), "Should not accept background push if the app has not been opened since 1970");

    date = [NSDate date];
    XCTAssertTrue(entry.predicate(args), "Should accept background push if the app has been opened recently");
}

@end
