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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>
#import "UAAutomation+Internal.h"
#import "UAirship.h"
#import "UAActionRegistry.h"
#import "UARegionEvent.h"
#import "UACustomEvent.h"
#import "UAAutomationStore+Internal.h"
#import "UAJSONPredicate.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAConfig.h"

@interface UAAutomationTests : XCTestCase
@property (nonatomic, strong) UAAutomation *automation;
@property (nonatomic, strong) UAActionRegistry *actionRegistry;
@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) UAPreferenceDataStore *preferenceDataStore;
@end

@implementation UAAutomationTests

- (void)setUp {
    [super setUp];

    UAConfig *config = [UAConfig config];
    config.productionAppKey = @"testAppKey";
    config.inProduction = YES;

    self.preferenceDataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"UAAutomationTests"];
    self.automation = [UAAutomation automationWithConfig:config dataStore:self.preferenceDataStore];

    [self.automation cancelAll];

    self.actionRegistry = [UAActionRegistry defaultRegistry];

    // Mock Airship
    self.mockedAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockedAirship stub] andReturn:self.mockedAirship] shared];
    [[[self.mockedAirship stub] andReturn:self.actionRegistry] actionRegistry];
}

- (void)tearDown {
    [self.mockedAirship stopMocking];
    [self.preferenceDataStore removeAll];
    [super tearDown];
}

- (void)testScheduleActions {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled action"];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
        XCTAssertEqual(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);
        [testExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testScheduleInvalidActionInfo {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled action"];

    // Missing action
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
        XCTAssertNil(schedule);
        [testExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testScheduleOverLimit {
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    // Schedule to the limit
    for (int i = 0; i < UAAutomationScheduleLimit; i++) {
        XCTestExpectation *testExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"scheduled action: %d", i]];

        [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
            XCTAssertEqualObjects(scheduleInfo, schedule.info);
            XCTAssertNotNil(schedule.identifier);
            [testExpectation fulfill];
        }];
    }

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled what"];

    // Try to schedule 1 more, verifty it fails
    [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
        XCTAssertNil(schedule);
        NSLog(@"what");

        [testExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:55 handler:nil];
}

- (void)testGetGroups {

    NSMutableArray *expectedFooSchedules = [NSMutableArray arrayWithCapacity:10];

    // Schedule 10 under the group "foo"
    for (int i = 0; i < 10; i++) {
        XCTestExpectation *testExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"scheduled foo action: %d", i]];

        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
            builder.group = @"foo";
        }];

        [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
            XCTAssertEqualObjects(scheduleInfo, schedule.info);
            XCTAssertNotNil(schedule.identifier);

            [expectedFooSchedules addObject:schedule];
            [testExpectation fulfill];
        }];

    }

    NSMutableArray *expectedBarSchedules = [NSMutableArray arrayWithCapacity:15];

    // Schedule 15 under "bar"
    for (int i = 0; i < 15; i++) {
        XCTestExpectation *testExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"scheduled bar action: %d", i]];

        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
            builder.group = @"bar";
        }];

        [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
            XCTAssertEqualObjects(scheduleInfo, schedule.info);
            XCTAssertNotNil(schedule.identifier);

            [expectedBarSchedules addObject:schedule];
            [testExpectation fulfill];
        }];
    }

    XCTestExpectation *fooGroupExpectation = [self expectationWithDescription:@"schedules foo fetched properly"];

    // Verify foo group
    [self.automation getSchedulesWithGroup:@"foo" completionHandler:^(NSArray<UAActionSchedule *> *result) {
        XCTAssertEqualObjects(expectedFooSchedules, result);
        [fooGroupExpectation fulfill];
    }];

    XCTestExpectation *barGroupExpectation = [self expectationWithDescription:@"schedules bar fetched properly"];

    // Verify bar group
    [self.automation getSchedulesWithGroup:@"bar" completionHandler:^(NSArray<UAActionSchedule *> *result) {
        XCTAssertEqualObjects(expectedBarSchedules, result);
        [barGroupExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testGetSchedule {
    __block NSString *scheduleIdentifier;

    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled actions"];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
        XCTAssertEqualObjects(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);
        scheduleIdentifier = schedule.identifier;

        [scheduleExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTestExpectation *fetchExpectation = [self expectationWithDescription:@"schedules fetched properly"];

    [self.automation getScheduleWithIdentifier:scheduleIdentifier completionHandler:^(UAActionSchedule *schedule) {
        XCTAssertEqualObjects(scheduleInfo, schedule.info);
        XCTAssertEqualObjects(scheduleIdentifier, schedule.identifier);
        [fetchExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testGetAll {
    NSMutableArray *expectedSchedules = [NSMutableArray arrayWithCapacity:15];

    // Schedule some actions
    for (int i = 0; i < 10; i++) {
        XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled actions"];

        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
        }];

        [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
            XCTAssertEqual(scheduleInfo, schedule.info);
            XCTAssertNotNil(schedule.identifier);

            [expectedSchedules addObject:schedule];
            [testExpectation fulfill];
        }];
    }

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"schedules fetched properly"];

    // Verify we are able to get the schedules
    [self.automation getSchedules:^(NSArray<UAActionSchedule *> *result) {
        XCTAssertEqualObjects(expectedSchedules, result);
        [testExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testCancelSchedule {
    __block NSString *scheduleIdentifier;

    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled actions"];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
        XCTAssertEqualObjects(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);
        scheduleIdentifier = schedule.identifier;

        [scheduleExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    [self.automation cancelScheduleWithIdentifier:scheduleIdentifier];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"schedules fetched"];

    // Verify schedule was canceled
    [self.automation getSchedules:^(NSArray<UAActionSchedule *> *result) {
        XCTAssertEqual(0, result.count);
        [testExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testCancelGroup {

    // Schedule 10 under "foo"
    for (int i = 0; i < 10; i++) {
        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
            builder.group = @"foo";
        }];
        [self.automation scheduleActions:scheduleInfo completionHandler:nil];
    }

    // Schedule 15 under "bar"
    NSMutableArray *barSchedules = [NSMutableArray arrayWithCapacity:15];
    for (int i = 0; i < 15; i++) {
        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
            builder.group = @"bar";
        }];

        [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
            [barSchedules addObject:schedule];
        }];
    }

    // Cancel all the "foo" schedules
    [self.automation cancelSchedulesWithGroup:@"foo"];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"schedules fetched"];

    // Verify the "bar" schedules are still active
    [self.automation getSchedules:^(NSArray<UAActionSchedule *> *result) {
        XCTAssertEqualObjects(barSchedules, result);
        [testExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testCancelAll {

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automation scheduleActions:scheduleInfo completionHandler:nil];

    [self.automation cancelAll];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"schedules fetched"];

    // Verify schedule was canceled
    [self.automation getSchedules:^(NSArray<UAActionSchedule *> *result) {
        XCTAssertEqual(0, result.count);
        [testExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testGetExpiredSchedules {
    __block NSString *scheduleIdentifier;

    NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow:100];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
        builder.group = @"foo";
        builder.end = futureDate;
    }];

    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled action"];

    [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
        XCTAssertEqual(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);

        scheduleIdentifier = schedule.identifier;
        [scheduleExpectation fulfill];
    }];

    // Make sure the actions are scheduled to grab the ID
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTestExpectation *availableExpectation = [self expectationWithDescription:@"fetched schedule"];

    // Verify schedule is available
    [self.automation getSchedules:^(NSArray<UAActionSchedule *> *result) {
        XCTAssertEqual(1, result.count);
        [availableExpectation fulfill];
    }];

    // Make sure we verified the schedule being availble before mocking the date
    [self waitForExpectationsWithTimeout:5 handler:nil];

    // Mock the date to return the futureDate + 1 second for date
    id mockedDate = [OCMockObject niceMockForClass:[NSDate class]];
    [[[mockedDate stub] andReturn:[futureDate dateByAddingTimeInterval:1]] date];

    // Verify getScheduleWithIdentifier:completionHandler: does not return the expired schedule
    XCTestExpectation *identifierExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automation getScheduleWithIdentifier:scheduleIdentifier completionHandler:^(UAActionSchedule *schedule) {
        XCTAssertNil(schedule);
        [identifierExpectation fulfill];
    }];

    // Verify getScheduleWithIdentifier:completionHandler: does not return the expired schedule
    XCTestExpectation *groupExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automation getSchedulesWithGroup:@"foo" completionHandler:^(NSArray<UAActionSchedule *> *result) {
        XCTAssertEqual(0, result.count);
        [groupExpectation fulfill];
    }];

    XCTestExpectation *allExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automation getSchedules:^(NSArray<UAActionSchedule *> *result) {
        XCTAssertEqual(0, result.count);
        [allExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testScheduleDeletesExpiredSchedules {
    NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow:100];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
        builder.end = futureDate;
    }];

    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled action"];

    [self.automation scheduleActions:scheduleInfo completionHandler:^(UAActionSchedule *schedule) {
        XCTAssertEqual(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);
        [scheduleExpectation fulfill];
    }];

    // Make sure we verified the schedule being availble before mocking the date
    [self waitForExpectationsWithTimeout:5 handler:nil];

    // Mock the date to return the futureDate + 1 second for date
    id mockedDate = [OCMockObject niceMockForClass:[NSDate class]];
    [[[mockedDate stub] andReturn:[futureDate dateByAddingTimeInterval:1]] date];

    // Schedule more actions
    scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automation scheduleActions:scheduleInfo completionHandler:nil];

    // Verify we have the new schedule
    XCTestExpectation *allExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automation getSchedules:^(NSArray<UAActionSchedule *> *result) {
        XCTAssertEqual(1, result.count);
        [allExpectation fulfill];
    }];

    // Check that the schedule was deleted from the data store
    XCTestExpectation *fetchScheduleDataExpectation = [self expectationWithDescription:@"fetched schedule data"];
    [self.automation.automationStore fetchSchedulesWithPredicate:nil limit:1 completionHandler:^(NSArray<UAActionScheduleData *> *result) {
        XCTAssertEqual(1, result.count);
        [fetchScheduleDataExpectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

}

- (void)testForeground {
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
    [self verifyTrigger:trigger triggerFireBlock:^{
        // simulate 2 foregrounds
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification
                                                            object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification
                                                            object:nil];
    }];
}

- (void)testBackground {
    UAScheduleTrigger *trigger = [UAScheduleTrigger backgroundTriggerWithCount:1];
    [self verifyTrigger:trigger triggerFireBlock:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification
                                                            object:nil];
    }];
}

- (void)testRegionEnter {
    UARegionEvent *regionAEnter = [UARegionEvent regionEventWithRegionID:@"regionA" source:@"test" boundaryEvent:UABoundaryEventEnter];
    UARegionEvent *regionBEnter = [UARegionEvent regionEventWithRegionID:@"regionB" source:@"test" boundaryEvent:UABoundaryEventEnter];

    UAScheduleTrigger *trigger = [UAScheduleTrigger regionEnterTriggerForRegionID:@"regionA" count:2];

    [self verifyTrigger:trigger triggerFireBlock:^{
        // Make sure regionB does not trigger the action
        [self.automation regionEventAdded:regionBEnter];

        // Trigger the action with 2 regionA enter events
        [self.automation regionEventAdded:regionAEnter];
        [self.automation regionEventAdded:regionAEnter];
    }];
}


- (void)testRegionExit {
    UARegionEvent *regionAExit = [UARegionEvent regionEventWithRegionID:@"regionA" source:@"test" boundaryEvent:UABoundaryEventExit];
    UARegionEvent *regionBExit = [UARegionEvent regionEventWithRegionID:@"regionB" source:@"test" boundaryEvent:UABoundaryEventExit];

    UAScheduleTrigger *trigger = [UAScheduleTrigger regionExitTriggerForRegionID:@"regionA" count:2];

    [self verifyTrigger:trigger triggerFireBlock:^{
        // Make sure regionB does not trigger the action
        [self.automation regionEventAdded:regionBExit];

        // Trigger the action with 2 regionA exit events
        [self.automation regionEventAdded:regionAExit];
        [self.automation regionEventAdded:regionAExit];
    }];
}

- (void)testScreen {
    UAScheduleTrigger *trigger = [UAScheduleTrigger screenTriggerForScreenName:@"screenA" count:2];

    [self verifyTrigger:trigger triggerFireBlock:^{
        // Make sure screenB does not trigger the action
        [self.automation screenTracked:@"screenB"];

        // Trigger the action with 2 screenA events
        [self.automation screenTracked:@"screenA"];
        [self.automation screenTracked:@"screenA"];
    }];
}

- (void)testCustomEventCount {
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase" value:@(100)];
    UACustomEvent *view = [UACustomEvent eventWithName:@"view" value:@(100)];

    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
    UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher key:UACustomEventNameKey];
    UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];

    UAScheduleTrigger *trigger = [UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1];

    [self verifyTrigger:trigger triggerFireBlock:^{
        // Make sure view does not trigger the action
        [self.automation customEventAdded:view];

        // Trigger the action with a purchase event
        [self.automation customEventAdded:purchase];
    }];
}

- (void)testCustomEventValue {
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase" value:@(55.55)];
    UACustomEvent *view = [UACustomEvent eventWithName:@"view" value:@(200)];


    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
    UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher key:UACustomEventNameKey];
    UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];

    UAScheduleTrigger *trigger = [UAScheduleTrigger customEventTriggerWithPredicate:predicate value:@(111.1)];

    [self verifyTrigger:trigger triggerFireBlock:^{
        // Make sure view does not trigger the action
        [self.automation customEventAdded:view];

        // Trigger the action with 2 purchase events
        [self.automation customEventAdded:purchase];
        [self.automation customEventAdded:purchase];
    }];
}

/**
 * Helper method to verify different trigger events
 * @param trigger The trigger to test
 * @param triggerFireBlock Block that generates enough events to fire the trigger.
 */
- (void)verifyTrigger:(UAScheduleTrigger *)trigger triggerFireBlock:(void (^)())triggerFireBlock {
    // Create the action
    __block BOOL actionRan;
    XCTestExpectation *actionRunExpectation = [self expectationWithDescription:@"action ran"];
    UAAction *action = [UAAction actionWithBlock:^(UAActionArguments *arguments, UAActionCompletionHandler completionHandler) {
        XCTAssertEqualObjects(arguments.value, @"test value");
        XCTAssertEqual(arguments.situation, UASituationAutomation);

        // Verify the action only runs once
        XCTAssertFalse(actionRan);
        actionRan = YES;

        [actionRunExpectation fulfill];
        completionHandler([UAActionResult emptyResult]);
    }];

    // Register the action
    [self.actionRegistry registerAction:action name:@"test action"];

    // Create a start date in the future
    NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:1000];

    // Schedule the action
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        builder.actions = @{@"test action": @"test value"};
        builder.triggers = @[trigger];
        builder.start = startDate;
    }];
    [self.automation scheduleActions:scheduleInfo completionHandler:nil];

    // Trigger the action, should not trigger any actions
    triggerFireBlock();

    // Mock the date to return the futureDate + 1 second for date
    id mockedDate = [OCMockObject niceMockForClass:[NSDate class]];
    [[[mockedDate stub] andReturn:[startDate dateByAddingTimeInterval:1]] date];

    // Trigger the actions now that its past the start
    triggerFireBlock();

    [self waitForExpectationsWithTimeout:5 handler:nil];
}
@end
