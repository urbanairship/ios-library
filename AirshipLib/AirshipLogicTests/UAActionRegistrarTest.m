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
@property(nonatomic, strong)NSMutableDictionary *originalRegistryEntries;
@property(nonatomic, strong)NSMutableDictionary *originalAliases;

@end

@implementation UAActionRegistrarTest
UAActionRegistrar *registrar;

- (void)setUp {
    [super setUp];

    registrar = [UAActionRegistrar shared];

    // Store current actions to restore later
    self.originalRegistryEntries = (NSMutableDictionary *)[UAActionRegistrar shared].registeredActionEntries;
    self.originalAliases = (NSMutableDictionary *)[UAActionRegistrar shared].aliases;

    // Start with a new action registry
    [UAActionRegistrar shared].registeredActionEntries = [NSMutableDictionary dictionary];
}

- (void)tearDown {
    // Restore previous action registries
    [UAActionRegistrar shared].registeredActionEntries = self.originalRegistryEntries;
    [UAActionRegistrar shared].aliases = self.originalAliases;

    [super tearDown];
}

/**
 * Test registering an action several different ways
 */
- (void)testRegisterAction {
}

/**
 * Test that registering a nil action clears the registration for the action
 */
- (void)testRegisterNilAction {

}


/**
 * Test registering an action with an name that conflicts with another action's name
 */
- (void)testRegisterActionConflictingName {
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

    UAActionRegistryEntry *entry = [[UAActionRegistrar shared] registryEntryWithName:@"name"];
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
    [registrar updatePredicate:noPredicate forEntryWithName:@"name"];
    [self validateActionIsRegistered:action names:@[@"name"] predicate:noPredicate];

    // Clear the predicate
    [registrar updatePredicate:nil forEntryWithName:@"name"];
    [self validateActionIsRegistered:action names:@[@"name"] predicate:nil];
}

/**
 * Test updatePredicate with invalid values
 */
- (void)testUpdatePredicateInvalid {

    XCTAssertFalse([registrar updatePredicate:nil forEntryWithName:@"name"], @"Update predicate should return NO if the registry for the name does not exist.");
    XCTAssertFalse([registrar updatePredicate:nil forEntryWithName:kUAIncomingPushActionRegistryName], @"Update predicate should return NO if the entry is reserved");
}

- (void)validateActionIsRegistered:(UAAction *)action
                              names:(NSArray *)names
                         predicate:(UAActionPredicate)predicate {

    UAActionRegistryEntry *entry = [[UAActionRegistrar shared] registryEntryWithName:[names firstObject]];

    XCTAssertNotNil(entry, @"Action is not registered");
    XCTAssertEqualObjects(entry.action, action, @"Registered entry's action is incorrect");
    XCTAssertEqualObjects(entry.predicate, predicate, @"Registered entry's predicate is incorrect");
    XCTAssertTrue([entry.names isEqualToArray:names], @"Registered entry's names are incorrect");
}

@end
