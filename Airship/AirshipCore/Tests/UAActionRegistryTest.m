/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAActionRegistry+Internal.h"
#import "UAApplicationMetrics+Internal.h"
#import "UAirship+Internal.h"
#import "UAAddTagsAction.h"
#import "UATagsActionPredicate+Internal.h"
#import "UAActionRegistryEntry+Internal.h"
#import "UALandingPageAction+Internal.h"

@interface UAActionRegistryTest : UABaseTest
@property (nonatomic, strong) UAActionRegistry *registry;
@property (nonatomic, strong) id mockMetrics;
@property (nonatomic, strong) id mockAirship;

@end

@implementation UAActionRegistryTest


- (void)setUp {
    [super setUp];

    self.registry = [[UAActionRegistry alloc] init];

    // Clear any default actions
    [self.registry.registeredActionEntries removeAllObjects];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];

    self.mockMetrics = [self mockForClass:[UAApplicationMetrics class]];
    [[[self.mockAirship stub] andReturn:self.mockMetrics] applicationMetrics];
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
 * Test registering an action class
 */
- (void)testRegisterActionClass {

    Class actionClass = [UAAction class];
    Class anotherActionClass = [UAAddTagsAction class];

    id<UAActionPredicateProtocol> predicate = [[[UATagsActionPredicate class] alloc] init];

    BOOL (^predicateBlock)(UAActionArguments *) = ^BOOL(UAActionArguments *args) {
        return [predicate applyActionArguments:args];
    };

    // Register an action
    BOOL result = [self.registry registerActionClass:actionClass names:@[@"name", @"alias", @"another-name"]];
    XCTAssertTrue(result, @"Action should register");
    [self validateActionClassIsRegistered:actionClass names:@[@"name", @"alias", @"another-name"] predicate:nil];

    // Register an action under a conflicting name
    result = [self.registry registerActionClass:anotherActionClass names:@[@"name", @"what"] predicate:predicateBlock];
    XCTAssertTrue(result, @"Action should register");
    [self validateActionClassIsRegistered:anotherActionClass names:@[@"name", @"what"] predicate:predicateBlock];

    // First entry should still be registered under 'alias' and 'another-name'
    [self validateActionClassIsRegistered:actionClass names:@[@"alias", @"another-name"] predicate:nil];
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
    [self.registry addSituationOverride:UASituationForegroundPush forEntryWithName:@"alias" action:situationOverrideAction];

    UAActionRegistryEntry *entry = [self.registry registryEntryWithName:@"name"];
    XCTAssertEqualObjects(action, entry.action, @"Original action should be left unharmed");
    XCTAssertEqualObjects(situationOverrideAction, [entry actionForSituation:UASituationForegroundPush], @"Action for the situation should be the situationOverrideAction");

    // Remove the situation override
    [self.registry addSituationOverride:UASituationForegroundPush forEntryWithName:@"name" action:nil];
    XCTAssertEqualObjects(action, [entry actionForSituation:UASituationForegroundPush], @"Action for the situation should be the default action");
}

/**
 * Test addSituationOverride for invalid values
 */
- (void)testSituationOverrideInvalid {
    UAAction *situationOverrideAction = [[UAAction alloc] init];

    XCTAssertFalse([self.registry addSituationOverride:UASituationForegroundPush forEntryWithName:@"name" action:situationOverrideAction], @"Situation return NO if the registry for the name does not exist.");
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
    XCTAssertTrue([self.registry updatePredicate:noPredicate forEntryWithName:@"name"], @"Predicate should update on this action");
    [self validateActionIsRegistered:action names:@[@"name"] predicate:noPredicate];

    // Clear the predicate
    XCTAssertTrue([self.registry updatePredicate:nil forEntryWithName:@"name"], "Predicate should update on this action");
    [self validateActionIsRegistered:action names:@[@"name"] predicate:nil];
}

/**
 * Test updateAction with valid values
 */
- (void)testUpdateAction {
    UAAction *anotherAction = [[UAAction alloc] init];
    UAAction *action = [[UAAction alloc] init];

    [self.registry registerAction:action name:@"name"];

    XCTAssertTrue([self.registry updateAction:anotherAction forEntryWithName:@"name"], @"Should allow updating action.");
    [self validateActionIsRegistered:anotherAction names:@[@"name"] predicate:nil];
}

/**
 * Test updateActionClass
 */
- (void)testUpdateActionClass {
    Class actionClass = [UAAction class];
    Class anotherActionClass = [UAAddTagsAction class];

    [self.registry registerActionClass:actionClass name:@"name"];

    XCTAssertTrue([self.registry updateActionClass:anotherActionClass forEntryWithName:@"name"], @"Should allow updating action.");
    [self validateActionClassIsRegistered:anotherActionClass names:@[@"name"] predicate:nil];
}

/**
 * Test updateAction with invalid values
 */
- (void)testUpdateActionInvalid {
    UAAction *action = [[UAAction alloc] init];
    [self.registry registerAction:action name:@"name"];

    XCTAssertFalse([self.registry updateAction:action forEntryWithName:@"not-found"], @"Update action should return NO if the registry for the name does not exist.");
}

/**
 * Test updateActionClass with invalid values
 */
- (void)testUpdateActionClassInvalid {
    Class actionClass = [UAAction class];
    [self.registry registerActionClass:actionClass name:@"name"];

    XCTAssertFalse([self.registry updateActionClass:actionClass forEntryWithName:@"not-found"], @"Update action should return NO if the registry for the name does not exist.");
}

/**
 * Test addName with valid values
 */
- (void)testAddName {
    UAAction *action = [[UAAction alloc] init];

    [self.registry registerAction:action name:@"name"];

    XCTAssertTrue([self.registry addName:@"anotherName" forEntryWithName:@"name"], @"Should be able to add names to any entry.");
    XCTAssertTrue([self.registry addName:@"yetAnotherName" forEntryWithName:@"anotherName"], @"Should be able to add names to any entry.");
    [self validateActionIsRegistered:action names:@[@"name", @"anotherName", @"yetAnotherName"] predicate:nil];
}

/**
 * Test addName with valid values
 */
- (void)testAddNameLazyLoad {
    Class actionClass = [UAAction class];

    [self.registry registerActionClass:actionClass name:@"name"];

    XCTAssertTrue([self.registry addName:@"anotherName" forEntryWithName:@"name"], @"Should be able to add names to any entry.");
    XCTAssertTrue([self.registry addName:@"yetAnotherName" forEntryWithName:@"anotherName"], @"Should be able to add names to any entry.");
    [self validateActionClassIsRegistered:actionClass names:@[@"name", @"anotherName", @"yetAnotherName"] predicate:nil];
}

/**
 * Test removeName with valid values
 */
- (void)testRemoveName {
    Class actionClass = [UAAction class];

    [self.registry registerActionClass:actionClass names:@[@"name", @"anotherName"]];

    XCTAssertTrue([self.registry removeName:@"name"], @"Should be able to remove a name.");
    [self validateActionClassIsRegistered:actionClass names:@[@"anotherName"] predicate:nil];

    XCTAssertTrue([self.registry removeName:@"anotherName"], @"Should be able to remove a name.");
    XCTAssertTrue([self.registry removeName:@"notFound"], @"Removing a name that does not exist should return YES.");
}

/**
 * Test removeEntry with valid values
 */
- (void)testRemoveEntry {
    UAAction *action = [[UAAction alloc] init];

    [self.registry registerAction:action names:@[@"name", @"anotherName"]];

    XCTAssertTrue([self.registry removeEntryWithName:@"name"], @"Should be able to remove an entry.");
    XCTAssertEqual((NSUInteger) 0, [self.registry.registeredEntries count], @"The entry should be dropped.");

    XCTAssertTrue([self.registry removeName:@"notFound"], @"Removing a name that does not exist should return YES.");
}

/**
 * Test removeEntry with valid values on a lazy loading action
 */
- (void)testRemoveEntryLazyLoad {
    [self.registry registerActionClass:[UAAction class] names:@[@"name", @"anotherName"]];

    XCTAssertTrue([self.registry removeEntryWithName:@"name"], @"Should be able to remove an entry.");
    XCTAssertEqual((NSUInteger) 0, [self.registry.registeredEntries count], @"The entry should be dropped.");

    XCTAssertTrue([self.registry removeName:@"notFound"], @"Removing a name that does not exist should return YES.");
}

/**
 * Test registeredEntries
 */
- (void)testRegisteredEntries {
    UAAction *action = [[UAAction alloc] init];
    [self.registry registerAction:action names:@[@"name", @"anotherName"]];
    XCTAssertEqual((NSUInteger)1, [self.registry.registeredEntries count], @"Duplicate names should be ignored.");
}

/**
 * Test registeredEntries lazy loading actions
 */
- (void)testRegisteredEntriesLazyLoad {
    [self.registry registerActionClass:[UAAction class] names:@[@"name", @"anotherName"]];
    XCTAssertEqual((NSUInteger)1, [self.registry.registeredEntries count], @"Duplicate names should be ignored.");
}


- (void)validateActionIsRegistered:(UAAction *)action
                             names:(NSArray *)names
                         predicate:(UAActionPredicate)predicate {

    UAActionRegistryEntry *entry = [self.registry registryEntryWithName:[names firstObject]];

    XCTAssertNotNil(entry, @"Action is not registered");
    XCTAssertEqual(entry.action, action, @"Registered entry's action is incorrect");
    XCTAssertEqual(entry.predicate, predicate, @"Registered entry's predicate is incorrect");
    XCTAssertTrue([entry.names isEqualToArray:names], @"Registered entry's names are incorrect");
}

- (void)validateActionClassIsRegistered:(Class)actionClass
                                  names:(NSArray *)names
                              predicate:(UAActionPredicate)predicate {

    UAActionRegistryEntry *entry = [self.registry registryEntryWithName:[names firstObject]];

    XCTAssertNotNil(entry, @"Action is not registered");
    XCTAssertNotNil(entry.action, @"Action should lazy load");
    XCTAssertEqual(entry.actionClass, actionClass, @"Registered entry's action class is incorrect");
    XCTAssertEqual(entry.predicate, predicate, @"Registered entry's predicate is incorrect");
    XCTAssertTrue([entry.names isEqualToArray:names], @"Registered entry's names are incorrect");
}

- (void)testRegisterInvalidActionClass {
    XCTAssertFalse([self.registry registerActionClass:[NSObject class] name:@"myInvalidActionClass"]);
}


@end
