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

- (void)setUp {
    [super setUp];

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


- (void)testRegisterAction {
    UAActionRegistrar *registrar = [UAActionRegistrar shared];
    UAAction *action = [[UAAction alloc] init];
    UAAction *anotherAction = [[UAAction alloc] init];

    [registrar registerAction:action name:@"some-action"];
    [registrar registerAction:anotherAction name:@"some-other-action"];

    XCTAssertEqual((NSUInteger) 2, registrar.registeredActionEntries.count, @"Should have 2 action registry entries");
    [self validateActionIsRegistered:action name:@"some-action" predicate:nil];
    [self validateActionIsRegistered:anotherAction name:@"some-other-action" predicate:nil];

    //Register another acction as some-action
    UAAction *yetAnotherAction = [[UAAction alloc] init];
    [registrar registerAction:yetAnotherAction name:@"some-action"];

    // Still have only 2 entries
    XCTAssertEqual((NSUInteger) 2, registrar.registeredActionEntries.count, @"Should have 2 action registry entries");
    [self validateActionIsRegistered:yetAnotherAction name:@"some-action" predicate:nil];
    [self validateActionIsRegistered:anotherAction name:@"some-other-action" predicate:nil];
}

- (void)testRegisterActionWithPredicate {
    UAActionRegistrar *registrar = [UAActionRegistrar shared];
    UAAction *action = [[UAAction alloc] init];
    UAActionPredicate predicate = ^(UAActionArguments *args) { return NO; };

    [registrar registerAction:action name:@"some-action" predicate:predicate];

    XCTAssertEqual((NSUInteger) 1, registrar.registeredActionEntries.count, @"Should have 1 action registry entries");
    [self validateActionIsRegistered:action name:@"some-action" predicate:predicate];

    // Clear the predicate
    [registrar registerAction:action name:@"some-action" predicate:nil];

    XCTAssertEqual((NSUInteger) 1, registrar.registeredActionEntries.count, @"Should have 1 action registry entries");
    [self validateActionIsRegistered:action name:@"some-action" predicate:nil];
}


- (void)testRegisterNilAction {
    UAActionRegistrar *registrar = [UAActionRegistrar shared];
    [registrar registerAction:nil name:@"some-action"];

    XCTAssertEqual((NSUInteger) 0, registrar.registeredActionEntries.count, @"Registering a nil action should not add an action registry");

    // Register an action
    UAAction *action = [[UAAction alloc] init];
    [registrar registerAction:action name:@"some-action"];
    XCTAssertEqual((NSUInteger) 1, registrar.registeredActionEntries.count, @"Should have 1 action registry entries");

    // Clear the action by registering nil for the name
    [registrar registerAction:nil name:@"some-action"];
    XCTAssertEqual((NSUInteger) 0, registrar.registeredActionEntries.count, @"Registering a nil action should remove the action entry");
}

- (void)validateActionIsRegistered:(UAAction *)action
                              name:(NSString *)name
                         predicate:(UAActionPredicate)predicate {

    UAActionRegistryEntry *entry = [[UAActionRegistrar shared] registeryEntryForName:name];

    XCTAssertNotNil(entry, @"Action is not registered");
    XCTAssertEqualObjects(entry.action, action, @"Registered entry's action is not the right action");
    XCTAssertEqualObjects(entry.predicate, predicate, @"Registered entry's predicate is not the right predicate");
}

@end
