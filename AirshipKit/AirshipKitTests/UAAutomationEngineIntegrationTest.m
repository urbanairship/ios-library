/* Copyright Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAAutomationEngine+Internal.h"
#import "UAirship+Internal.h"
#import "UARegionEvent.h"
#import "UACustomEvent.h"
#import "UAAutomationStore+Internal.h"
#import "UAJSONPredicate.h"
#import "UAConfig.h"
#import "UAScheduleDelay.h"
#import "UAScheduleData+Internal.h"
#import "UAScheduleInfo+Internal.h"
#import "UAActionScheduleInfo.h"
#import "UAAutomation+Internal.h"
#import "UAApplicationMetrics+Internal.h"
#import "UATestDispatcher.h"
#import "UATestDate.h"

@interface UAAutomationEngineIntegrationTest : UABaseTest
@property (nonatomic, strong) UAAutomationEngine *automationEngine;
@property (nonatomic, strong) UAAutomationStore *testStore;
@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockDelegate;
@property (nonatomic, strong) id mockMetrics;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) UATimerScheduler *timerScheduler;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UATestDispatcher *dispatcher;
@property (nonatomic, copy) void (^timerSchedulerBlock)(NSTimer *);
@property (nonatomic, strong) UATestDate *testDate;
@end

#define UAAUTOMATIONENGINETESTS_SCHEDULE_LIMIT 100


@implementation UAAutomationEngineIntegrationTest
- (void)setUp {
    [super setUp];

    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];

    self.dispatcher = [UATestDispatcher testDispatcher];

    // Set up a mocked application
    self.mockedApplication = [self mockForClass:[UIApplication class]];

    self.mockDelegate = [self mockForProtocol:@protocol(UAAutomationEngineDelegate)];
    [[[self.mockDelegate stub] andCall:@selector(createScheduleInfoWithBuilder:) onObject:self] createScheduleInfoWithBuilder:OCMOCK_ANY];

    self.testStore = [UAAutomationStore automationStoreWithStoreName:@"UAAutomationEngine.test"
                                                       scheduleLimit:UAAUTOMATIONENGINETESTS_SCHEDULE_LIMIT
                                                            inMemory:YES
                                                                date:self.testDate];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];


    self.timerScheduler = [UATimerScheduler timerSchedulerWithSchedulerBlock:^(NSTimer *timer) {
        if (self.timerSchedulerBlock) {
            self.timerSchedulerBlock(timer);
        }
    }];

    self.mockMetrics = [self mockForClass:[UAApplicationMetrics class]];
    [[[self.mockAirship stub] andReturn:self.mockMetrics] applicationMetrics];


    self.notificationCenter = [[NSNotificationCenter alloc] init];

    self.automationEngine = [UAAutomationEngine automationEngineWithAutomationStore:self.testStore
                                                                     timerScheduler:self.timerScheduler
                                                                 notificationCenter:self.notificationCenter
                                                                         dispatcher:self.dispatcher
                                                                        application:self.mockedApplication
                                                                               date:self.testDate];

    self.automationEngine.delegate = self.mockDelegate;
    [self.automationEngine cancelAll];

    [self.automationEngine start];

    // wait for automation store to complete operations started during start
    [self.testStore waitForIdle];
}

- (void)tearDown {
    [self.automationEngine stop];
    [self.testStore shutDown];
    [self.testStore waitForIdle];

    self.automationEngine = nil;
    self.testStore = nil;

    [super tearDown];
}

- (void)testSchedule {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled action"];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        XCTAssertEqual(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testScheduleMultiple {
    // setup
    UAActionScheduleInfo *scheduleInfo1 = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];
    UAActionScheduleInfo *scheduleInfo2 = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:3];
        builder.actions = @{@"hey": @"there"};
        builder.triggers = @[foregroundTrigger];
    }];

    NSArray<UAActionScheduleInfo *> *submittedSchedules = @[scheduleInfo1,scheduleInfo2];

    XCTestExpectation *scheduledExpectation = [self expectationWithDescription:@"scheduled actions"];

    // test
    [self.automationEngine scheduleMultiple:submittedSchedules completionHandler:^(NSArray<UASchedule *> *schedules) {
        XCTAssertEqual(schedules.count, submittedSchedules.count);
        NSArray *infos = @[schedules[0].info, schedules[1].info];
        XCTAssertEqualObjects(infos, submittedSchedules);
        [scheduledExpectation fulfill];
    }];

    // verify
    [self waitForTestExpectations];
}

- (void)testScheduleInvalidActionInfo {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled action"];

    // Missing action
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        XCTAssertNil(schedule);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testScheduleOverLimit {
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger screenTriggerForScreenName:@"NEVERTRIGGERTHISNAME" count:10];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    // Schedule to the limit
    for (int i = 0; i < UAAutomationScheduleLimit; i++) {
        XCTestExpectation *testExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"scheduled action: %d", i]];

        [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
            XCTAssertEqualObjects(scheduleInfo, schedule.info);
            XCTAssertNotNil(schedule.identifier);
            [testExpectation fulfill];
        }];
    }

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled what"];

    // Try to schedule 1 more, verify it fails
    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        XCTAssertNil(schedule);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPriority {
    NSArray *testPriorityLevels = @[@5, @-2, @0, @-10];

    // Sort the test priority levels to give us the expected priority level
    NSSortDescriptor *ascending = [[NSSortDescriptor alloc] initWithKey:nil ascending:YES];
    NSArray *expectedPriorityLevel = [testPriorityLevels sortedArrayUsingDescriptors:@[ascending]];

    // Executed priority level will hold the actual action execution order
    NSMutableArray *executedPriorityLevel = [NSMutableArray array];

    NSMutableArray *runExpectations = [NSMutableArray array];
    for (int i = 0; i < testPriorityLevels.count; i++) {
        XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"Wait for priority-%@ to execute", testPriorityLevels[i]]];

        [runExpectations addObject:expectation];

        [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
            UASchedule *schedule = obj;
            return schedule.info.priority == [testPriorityLevels[i] intValue];
        }]];

        [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:3];
            void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
            handler(UAAutomationSchedulePrepareResultContinue);
        }] prepareSchedule:OCMOCK_ANY completionHandler:OCMOCK_ANY];

        [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
            [executedPriorityLevel addObject:testPriorityLevels[i]];
            [expectation fulfill];

        }] executeSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
            UASchedule *schedule = obj;
            return schedule.info.priority == [testPriorityLevels[i] intValue];
        }] completionHandler:OCMOCK_ANY];

        // Give all the schedules the same trigger
        UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];

        UAActionScheduleInfo *info = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder * _Nonnull builder) {
            builder.actions = @{@"cool": @"story"};
            builder.priority = [testPriorityLevels[i] integerValue];
            builder.triggers = @[trigger];
        }];

        [self.automationEngine schedule:info completionHandler:nil];
    }

    // Trigger the schedules with a foreground notification
    [self simulateForegroundTransition];

    [self waitForTestExpectations:runExpectations];

    XCTAssertEqualObjects(executedPriorityLevel, expectedPriorityLevel);
}

- (void)testGetGroups {

    NSMutableArray *expectedFooSchedules = [NSMutableArray arrayWithCapacity:10];

    // Schedule 10 under the group "foo"
    for (int i = 0; i < 10; i++) {
        XCTestExpectation *testExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"scheduled foo action: %d", i]];

        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
            builder.group = @"foo";
        }];

        [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
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

        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
            builder.group = @"bar";
        }];

        [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
            XCTAssertEqualObjects(scheduleInfo, schedule.info);
            XCTAssertNotNil(schedule.identifier);

            [expectedBarSchedules addObject:schedule];
            [testExpectation fulfill];
        }];
    }

    XCTestExpectation *fooGroupExpectation = [self expectationWithDescription:@"schedules foo fetched properly"];

    // Verify foo group
    [self.automationEngine getSchedulesWithGroup:@"foo" completionHandler:^(NSArray<UASchedule *> *result) {
        XCTAssertEqualObjects([NSSet setWithArray:expectedFooSchedules], [NSSet setWithArray:result]);
        [fooGroupExpectation fulfill];
    }];

    XCTestExpectation *barGroupExpectation = [self expectationWithDescription:@"schedules bar fetched properly"];

    // Verify bar group
    [self.automationEngine getSchedulesWithGroup:@"bar" completionHandler:^(NSArray<UASchedule *> *result) {
        XCTAssertEqualObjects([NSSet setWithArray:expectedBarSchedules], [NSSet setWithArray:result]);
        [barGroupExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetSchedule {
    __block NSString *scheduleIdentifier;

    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled actions"];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        XCTAssertEqualObjects(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);
        scheduleIdentifier = schedule.identifier;

        [scheduleExpectation fulfill];
    }];

    [self waitForTestExpectations];

    XCTestExpectation *fetchExpectation = [self expectationWithDescription:@"schedules fetched properly"];

    [self.automationEngine getScheduleWithID:scheduleIdentifier completionHandler:^(UASchedule *schedule) {
        XCTAssertEqualObjects(scheduleInfo, schedule.info);
        XCTAssertEqualObjects(scheduleIdentifier, schedule.identifier);
        [fetchExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetAllUnended {
    NSMutableArray *expectedSchedules = [NSMutableArray arrayWithCapacity:15];

    // Schedule some actions
    for (int i = 0; i < 10; i++) {
        XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled actions"];

        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
        }];

        [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
            XCTAssertEqual(scheduleInfo, schedule.info);
            XCTAssertNotNil(schedule.identifier);

            [expectedSchedules addObject:schedule];
            [testExpectation fulfill];
        }];
    }

    // schedule action with end date in the past - should not be returned later
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled actions"];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
        builder.end = [NSDate dateWithTimeIntervalSince1970:0];
    }];
    
    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        XCTAssertEqual(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);
        
        [testExpectation fulfill];
    }];

    testExpectation = [self expectationWithDescription:@"schedules fetched properly"];

    // Verify we are able to get the schedules
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqualObjects([NSSet setWithArray:expectedSchedules], [NSSet setWithArray:result]);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetAll {
    NSMutableArray *expectedSchedules = [NSMutableArray arrayWithCapacity:15];
    
    // Schedule some actions
    for (int i = 0; i < 10; i++) {
        XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled actions"];
        
        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
        }];
        
        [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
            XCTAssertEqual(scheduleInfo, schedule.info);
            XCTAssertNotNil(schedule.identifier);
            
            [expectedSchedules addObject:schedule];
            [testExpectation fulfill];
        }];
    }
    
    // schedule action with end date in the past - should be returned later
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled actions"];
    
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
        builder.end = [NSDate dateWithTimeIntervalSince1970:0];
    }];
    
    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        XCTAssertEqual(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);
        
        [expectedSchedules addObject:schedule];
        [testExpectation fulfill];
    }];
    
    testExpectation = [self expectationWithDescription:@"schedules fetched properly"];
    
    // Verify we are able to get the schedules
    [self.automationEngine getAllSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqualObjects([NSSet setWithArray:expectedSchedules], [NSSet setWithArray:result]);
        [testExpectation fulfill];
    }];
    
    [self waitForTestExpectations];
}

- (void)testCancelSchedule {
    __block NSString *scheduleIdentifier;

    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled actions"];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        XCTAssertEqualObjects(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);
        scheduleIdentifier = schedule.identifier;

        [scheduleExpectation fulfill];
    }];

    [self waitForTestExpectations];

    [self.automationEngine cancelScheduleWithID:scheduleIdentifier];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"schedules fetched"];

    // Verify schedule was canceled
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqual(0, result.count);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCancelGroup {

    // Schedule 10 under "foo"
    for (int i = 0; i < 10; i++) {
        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
            builder.group = @"foo";
        }];
        [self.automationEngine schedule:scheduleInfo completionHandler:nil];
    }

    // Schedule 15 under "bar"
    NSMutableArray *barSchedules = [NSMutableArray arrayWithCapacity:15];
    for (int i = 0; i < 15; i++) {
        UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.actions = @{@"oh": @"hi"};
            builder.triggers = @[foregroundTrigger];
            builder.group = @"bar";
        }];

        [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
            [barSchedules addObject:schedule];
        }];
    }

    // Cancel all the "foo" schedules
    [self.automationEngine cancelSchedulesWithGroup:@"foo"];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"schedules fetched"];

    // Verify the "bar" schedules are still active
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqualObjects([NSSet setWithArray:barSchedules], [NSSet setWithArray:result]);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCancelAll {

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:scheduleInfo completionHandler:nil];

    [self.automationEngine cancelAll];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"schedules fetched"];

    // Verify schedule was canceled
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqual(0, result.count);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetExpiredSchedules {
    __block NSString *scheduleIdentifier;

    NSDate *futureDate = [NSDate dateWithTimeInterval:100 sinceDate:self.testDate.now];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
        builder.group = @"foo";
        builder.end = futureDate;
    }];

    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled action"];

    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        XCTAssertEqual(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);

        scheduleIdentifier = schedule.identifier;
        [scheduleExpectation fulfill];
    }];

    // Make sure the actions are scheduled to grab the ID
    [self waitForTestExpectations];

    XCTestExpectation *availableExpectation = [self expectationWithDescription:@"fetched schedule"];

    // Verify schedule is available
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqual(1, result.count);
        [availableExpectation fulfill];
    }];

    // Make sure we verified the schedule being availble before mocking the date
    [self waitForTestExpectations];

    // Shift time to one second after the futureDate
    self.testDate.timeOffset = [futureDate timeIntervalSinceDate:self.testDate.now] + 1;

    // Verify getScheduleWithIdentifier:completionHandler: does not return the expired schedule
    XCTestExpectation *identifierExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automationEngine getScheduleWithID:scheduleIdentifier completionHandler:^(UASchedule *schedule) {
        XCTAssertNil(schedule);
        [identifierExpectation fulfill];
    }];

    // Verify getScheduleWithIdentifier:completionHandler: does not return the expired schedule
    XCTestExpectation *groupExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automationEngine getSchedulesWithGroup:@"foo" completionHandler:^(NSArray<UASchedule *> *result) {
        XCTAssertEqual(0, result.count);
        [groupExpectation fulfill];
    }];

    XCTestExpectation *allExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqual(0, result.count);
        [allExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testScheduleDeletesExpiredSchedules {
    NSDate *futureDate = [NSDate dateWithTimeInterval:100 sinceDate:self.testDate.now];

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
        builder.end = futureDate;
    }];

    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled action"];

    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        XCTAssertEqual(scheduleInfo, schedule.info);
        XCTAssertNotNil(schedule.identifier);
        [scheduleExpectation fulfill];
    }];

    // Make sure we verified the schedule being availble before mocking the date
    [self waitForTestExpectations];

    // Shift time to one second after the futureDate
    self.testDate.timeOffset = [futureDate timeIntervalSinceDate:self.testDate.now] + 1;

    // Schedule more actions
    scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.actions = @{@"oh": @"hi"};
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:scheduleInfo completionHandler:nil];

    // Verify we have the new schedule
    XCTestExpectation *allExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqual(1, result.count);
        [allExpectation fulfill];
    }];

    // Check that the schedule was deleted from the data store
    XCTestExpectation *fetchScheduleDataExpectation = [self expectationWithDescription:@"fetched schedule data"];

    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqual(1, result.count);
        [fetchScheduleDataExpectation fulfill];
    }];

    [self waitForTestExpectations];

}

- (void)testForeground {
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
    [self verifyTrigger:trigger triggerFireBlock:^{
        // simulate 2 foregrounds
        [self simulateForegroundTransition];
        [self simulateForegroundTransition];
    }];
}

- (void)testActiveSession {
    UAScheduleTrigger *trigger = [UAScheduleTrigger activeSessionTriggerWithCount:1];
    [self verifyTrigger:trigger triggerFireBlock:^{
        [self simulateForegroundTransition];
    }];
}

- (void)testActiveSessionLateSubscription {
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    UAScheduleTrigger *trigger = [UAScheduleTrigger activeSessionTriggerWithCount:1];
    [self verifyStateTrigger:trigger];
}

- (void)testVersion {
    [[[self.mockMetrics stub] andReturn:@"2.0"] currentAppVersion];
    [[[self.mockMetrics stub] andReturnValue:@(YES)] isAppVersionUpdated];

    UAScheduleTrigger *trigger = [UAScheduleTrigger versionTriggerWithConstraint:@"2.0+" count:1];
    [self verifyStateTrigger:trigger];
}

- (void)testBackground {
    UAScheduleTrigger *trigger = [UAScheduleTrigger backgroundTriggerWithCount:1];

    [self verifyTrigger:trigger triggerFireBlock:^{
        [self simulateBackgroundTransition];
    }];
}

- (void)testRegionEnter {
    UARegionEvent *regionAEnter = [UARegionEvent regionEventWithRegionID:@"regionA" source:@"test" boundaryEvent:UABoundaryEventEnter];
    UARegionEvent *regionBEnter = [UARegionEvent regionEventWithRegionID:@"regionB" source:@"test" boundaryEvent:UABoundaryEventEnter];

    UAScheduleTrigger *trigger = [UAScheduleTrigger regionEnterTriggerForRegionID:@"regionA" count:2];

    [self verifyTrigger:trigger triggerFireBlock:^{
        // Make sure regionB does not trigger the action
        [self emitEvent:regionBEnter];

        // Trigger the action with 2 regionA enter events
        [self emitEvent:regionAEnter];
        [self emitEvent:regionAEnter];
    }];
}


- (void)testRegionExit {
    UARegionEvent *regionAExit = [UARegionEvent regionEventWithRegionID:@"regionA" source:@"test" boundaryEvent:UABoundaryEventExit];
    UARegionEvent *regionBExit = [UARegionEvent regionEventWithRegionID:@"regionB" source:@"test" boundaryEvent:UABoundaryEventExit];

    UAScheduleTrigger *trigger = [UAScheduleTrigger regionExitTriggerForRegionID:@"regionA" count:2];

    [self verifyTrigger:trigger triggerFireBlock:^{
        // Make sure regionB does not trigger the action
        [self emitEvent:regionBExit];

        // Trigger the action with 2 regionA exit events
        [self emitEvent:regionAExit];
        [self emitEvent:regionAExit];
    }];
}

- (void)testScreen {
    UAScheduleTrigger *trigger = [UAScheduleTrigger screenTriggerForScreenName:@"screenA" count:2];

    [self verifyTrigger:trigger triggerFireBlock:^{
        // Make sure screenB does not trigger the action
        [self emitScreenTracked:@"screenB"];

        // Trigger the action with 2 screenA events
        [self emitScreenTracked:@"screenA"];
        [self emitScreenTracked:@"screenA"];
    }];
}

- (void)testCustomEventCount {
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase" value:@(100)];
    UACustomEvent *view = [UACustomEvent eventWithName:@"view" value:@(100)];

    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
    UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
    UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];

    UAScheduleTrigger *trigger = [UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1];

    [self verifyTrigger:trigger triggerFireBlock:^{
        // Make sure view does not trigger the action
        [self emitEvent:view];

        // Trigger the action with a purchase event
        [self emitEvent:purchase];
    }];
}

- (void)testCustomEventValue {
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase" value:@(55.55)];
    UACustomEvent *view = [UACustomEvent eventWithName:@"view" value:@(200)];


    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
    UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
    UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];

    UAScheduleTrigger *trigger = [UAScheduleTrigger customEventTriggerWithPredicate:predicate value:@(111.1)];

    [self verifyTrigger:trigger triggerFireBlock:^{
        // Make sure view does not trigger the action
        [self emitEvent:view];

        // Trigger the action with 2 purchase events
        [self emitEvent:purchase];
        [self emitEvent:purchase];
    }];
}

- (void)testMultipleScreenDelay {
    UAScheduleDelay *delay = [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder * builder) {
        builder.screens = @[@"test screen", @"another test screen", @"and another test screen"];
    }];

    [self verifyDelay:delay fulfillmentBlock:^{
        [self emitScreenTracked:@"test screen"];
    }];
}

- (void)testRegionDelay {
    UAScheduleDelay *delay = [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder * builder) {
        builder.regionID = @"region test";
    }];

    [self verifyDelay:delay fulfillmentBlock:^{
        UARegionEvent *regionEnter = [UARegionEvent regionEventWithRegionID:@"region test" source:@"test" boundaryEvent:UABoundaryEventEnter];
        [self emitEvent:regionEnter];
    }];
}

- (void)testForegroundDelay {
    UAScheduleDelay *delay = [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder * builder) {
        builder.appState = UAScheduleDelayAppStateForeground;
    }];

    [self verifyDelay:delay fulfillmentBlock:^{
        [self simulateForegroundTransition];
    }];
}

- (void)testBackgroundDelay {
    // Start with a foreground state
    [self.notificationCenter postNotificationName:UIApplicationWillEnterForegroundNotification
                                           object:nil];


    UAScheduleDelay *delay = [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder * builder) {
        builder.appState = UAScheduleDelayAppStateBackground;
    }];

    [self verifyDelay:delay fulfillmentBlock:^{
        [self.notificationCenter postNotificationName:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    }];
}

- (void)testSecondsDelay {
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    UAScheduleDelay *delay = [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder * builder) {
        builder.seconds = 1;
    }];

    self.timerSchedulerBlock = ^(NSTimer *timer) {
        [timer fire];
    };

    [self verifyDelay:delay fulfillmentBlock:^{}];
}

- (void)testCancellationTriggers {
    // Schedule the action
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        builder.actions = @{@"test action": @"test value"};

        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];

        // Add a delay for "test screen" that cancels on foreground
        builder.delay = [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder * builder) {
            builder.screens = @[@"test screen", @"another test screen"];
            builder.cancellationTriggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        }];
    }];

    XCTestExpectation *actionsScheduled = [self expectationWithDescription:@"actions scheduled"];

    __block NSString *identifier;
    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        identifier = schedule.identifier;
        [actionsScheduled fulfill];
    }];

    [self waitForTestExpectations];

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    // Verify the schedule data is pending execution
    XCTestExpectation *schedulePendingExecution = [self expectationWithDescription:@"pending execution"];

    [self.automationEngine.automationStore getSchedule:identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStatePreparingSchedule, [scheduleData.executionState intValue]);
        [schedulePendingExecution fulfill];
    }];

    [self waitForTestExpectations];

    // Cancel the pending execution by foregrounding the app
    [self simulateForegroundTransition];

    // Verify the schedule is no longer pending execution
    XCTestExpectation *scheduleNotPendingExecution = [self expectationWithDescription:@"not pending execution"];
    [self.automationEngine.automationStore getSchedule:identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStateIdle, [scheduleData.executionState intValue]);
        [scheduleNotPendingExecution fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testEdits {
    // Schedule the action
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        builder.actions = @{@"test action": @"test value"};
        builder.editGracePeriod = 1000;

        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];
    }];

    XCTestExpectation *actionsScheduled = [self expectationWithDescription:@"actions scheduled"];
    __block NSString *identifier;
    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        identifier = schedule.identifier;
        [actionsScheduled fulfill];
    }];

    [self waitForTestExpectations];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:identifier];
    }] completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:identifier];
    }]];

    // When executeSchedule is called on the mockDelegate call the callback
    XCTestExpectation *executeSchedule = [self expectationWithDescription:@"schedule is executing"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(void) = (__bridge void (^)(void))arg;
        handler();
        [executeSchedule fulfill];
    }] executeSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:identifier];
    }] completionHandler:OCMOCK_ANY];

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    [self waitForTestExpectations];

    XCTestExpectation *checkFinishedState = [self expectationWithDescription:@"not pending execution"];

    [self.automationEngine.automationStore getSchedule:identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStateFinished, [scheduleData.executionState intValue]);
        [checkFinishedState fulfill];
    }];

    [self waitForTestExpectations];

    UAActionScheduleEdits *edits = [UAActionScheduleEdits editsWithBuilderBlock:^(UAActionScheduleEditsBuilder *  builder) {
        builder.limit = @(2);
    }];


    XCTestExpectation *updated = [self expectationWithDescription:@"schedule updated"];
    [self.automationEngine editScheduleWithID:identifier edits:edits completionHandler:^(UASchedule *schedule) {
        XCTAssertNotNil(schedule);
        [updated fulfill];
    }];

    XCTestExpectation *checkIdleState = [self expectationWithDescription:@"not pending execution"];

    [self.automationEngine.automationStore getSchedule:identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStateIdle, [scheduleData.executionState intValue]);
        [checkIdleState fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepareResultCancel {
    [self verifyPrepareResult:UAAutomationSchedulePrepareResultCancel verifyWithCompletionHandler:^(UAScheduleData *data) {
        XCTAssertNil(data);
    }];
}

- (void)testPrepareResultSkip {
    [self verifyPrepareResult:UAAutomationSchedulePrepareResultSkip verifyWithCompletionHandler:^(UAScheduleData *data) {
        XCTAssertNotNil(data);
        XCTAssertEqual(0, [data.triggeredCount integerValue]);
    }];
}

- (void)testPrepareResultInvalidate {
    [self verifyPrepareResult:UAAutomationSchedulePrepareResultInvalidate verifyWithCompletionHandler:^(UAScheduleData *data) {
        XCTAssertNotNil(data);
        XCTAssertEqual(0, [data.triggeredCount integerValue]);
    }];
}

- (void)testPrepareResultPenalize {
    [self verifyPrepareResult:UAAutomationSchedulePrepareResultPenalize verifyWithCompletionHandler:^(UAScheduleData *data) {
        XCTAssertNotNil(data);
        XCTAssertEqual(1, [data.triggeredCount integerValue]);
        XCTAssertEqual(UAScheduleStatePaused, [data.executionState integerValue]);
    }];
}

- (void)verifyPrepareResult:(UAAutomationSchedulePrepareResult)prepareResult verifyWithCompletionHandler:(void (^)(UAScheduleData *))completionHandler {
    // Schedule the action
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        builder.actions = @{@"test action": @"test value"};
        builder.interval = 100000;
        builder.limit = 2;
        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];
    }];

    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {}];

    XCTestExpectation *infoScheduled = [self expectationWithDescription:@"info scheduled"];
    __block NSString *scheduleId;
    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        scheduleId = schedule.identifier;
        [infoScheduled fulfill];
    }];

    [self waitForTestExpectations];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    XCTestExpectation *prepared = [self expectationWithDescription:@"schedule is prepared"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(prepareResult);
        [prepared fulfill];
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:scheduleId];
    }] completionHandler:OCMOCK_ANY];

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    [self waitForTestExpectations];

    XCTestExpectation *checkFinishedState = [self expectationWithDescription:@"Checked schedule state"];

    [self.automationEngine.automationStore getSchedule:scheduleId completionHandler:^(UAScheduleData *scheduleData) {
        completionHandler(scheduleData);
        [checkFinishedState fulfill];
    }];

    [self waitForTestExpectations];
}


- (void)testInterval {
    // Schedule the action
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        builder.actions = @{@"test action": @"test value"};
        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];
        builder.interval = 100;
        builder.limit = 2;
    }];

    XCTestExpectation *infoScheduled = [self expectationWithDescription:@"info scheduled"];
    __block NSString *scheduleId;
    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        scheduleId = schedule.identifier;
        [infoScheduled fulfill];
    }];

    [self waitForTestExpectations];

    // When executeSchedule is called on the mockDelegate do this
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(void) = (__bridge void (^)(void))arg;
        handler();
    }] executeSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:scheduleId];
    }] completionHandler:OCMOCK_ANY];

    // When prepareSchedule is called on the mockDelegate do this
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:scheduleId];
    }] completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:scheduleId];
    }]];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    XCTestExpectation *timerScheduled = [self expectationWithDescription:@"timer scheduled"];
    __block NSTimer *timer;
    self.timerSchedulerBlock = ^(NSTimer *t) {
        timer = t;
        [timerScheduled fulfill];
    };

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    // Wait for the action to fire
    [self waitForTestExpectations];

    // Verify the schedule is paused
    XCTestExpectation *checkPauseState = [self expectationWithDescription:@"pause state"];
    [self.automationEngine.automationStore getSchedule:scheduleId completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStatePaused, [scheduleData.executionState intValue]);
        [checkPauseState fulfill];
    }];

    [self waitForTestExpectations];

    // Fire the timer
    [timer fire];

    // Verify we are back to idle
    XCTestExpectation *checkIdleState = [self expectationWithDescription:@"idle state"];
    [self.automationEngine.automationStore getSchedule:scheduleId completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStateIdle, [scheduleData.executionState intValue]);
        [checkIdleState fulfill];
    }];

    [self waitForTestExpectations];
}


/**
 * Helper method for simulating a full transition from the background to the active state.
 */
- (void)simulateForegroundTransition {
    [self.notificationCenter postNotificationName:UIApplicationDidEnterBackgroundNotification
                                           object:nil];

    [self.notificationCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                                           object:nil];
}

- (void)simulateBackgroundTransition {
    [self.notificationCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                                           object:nil];

    [self.notificationCenter postNotificationName:UIApplicationDidEnterBackgroundNotification
                                           object:nil];
}

- (void)verifyDelay:(UAScheduleDelay *)delay fulfillmentBlock:(void (^)(void))fulfillmentBlock {
    // Schedule the action
    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
        builder.actions = @{@"test action": @"test value"};

        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];

        builder.delay = delay;
    }];

    XCTestExpectation *infoScheduled = [self expectationWithDescription:@"info scheduled"];

    __block NSString *scheduleId;
    [self.automationEngine schedule:scheduleInfo completionHandler:^(UASchedule *schedule) {
        scheduleId = schedule.identifier;
        [infoScheduled fulfill];
    }];

    [self waitForTestExpectations];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:scheduleId];
    }]];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:scheduleId];
    }] completionHandler:OCMOCK_ANY];

    XCTestExpectation *executeSchedule = [self expectationWithDescription:@"schedule is executing"];
    __block bool scheduleExecuted = NO;

    // When executeSchedule is called on the mockDelegate do this
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(void) = (__bridge void (^)(void))arg;
        handler();
        scheduleExecuted = YES;
        [executeSchedule fulfill];
    }] executeSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:scheduleId];
    }] completionHandler:OCMOCK_ANY];

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    // Verify the action did not fire
    XCTAssertFalse(scheduleExecuted);

    // Fullfill the conditions
    fulfillmentBlock();

    // Wait for the action to fire
    [self waitForTestExpectations];

    // Verify the schedule is deleted
    XCTestExpectation *fetchExpectation = [self expectationWithDescription:@"schedule fetched"];
    [self.automationEngine getScheduleWithID:scheduleId completionHandler:^(UASchedule *schedule) {
        XCTAssertNil(schedule);
        [fetchExpectation fulfill];
    }];
    [self waitForTestExpectations];
}


- (void)verifyStateTrigger:(UAScheduleTrigger *)trigger {
    NSString *uuid = [NSUUID UUID].UUIDString;
    UAActionScheduleInfo *info = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder * _Nonnull builder) {
        builder.actions = @{@"cool": @"story"};
        builder.triggers = @[trigger];
        builder.group = uuid;
    }];

    XCTestExpectation *scheduled = [self expectationWithDescription:@"scheduled"];
    XCTestExpectation *prepared = [self expectationWithDescription:@"schedule prepared"];
    XCTestExpectation *executed = [self expectationWithDescription:@"schedule executed"];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
        [prepared fulfill];
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.info.group isEqualToString:uuid];
    }] completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.info.group isEqualToString:uuid];
    }]];

    // When executeSchedule is called on the mockDelegate do this
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(void) = (__bridge void (^)(void))arg;
        handler();
        [executed fulfill];
    }] executeSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.info.group isEqualToString:uuid];
    }] completionHandler:OCMOCK_ANY];

    // Schedule
    [self.automationEngine schedule:info completionHandler:^(UASchedule *schedule) {
        [scheduled fulfill];
    }];

    // Wait for schedule
    [self waitForTestExpectations:@[scheduled]];

    // Wait for prepared
    [self waitForTestExpectations:@[prepared]];

    // Wait for execution
    [self waitForTestExpectations:@[executed]];
}

/**
 * Helper method to verify different trigger events
 * @param trigger The trigger to test
 * @param triggerFireBlock Block that generates enough events to fire the trigger.
 */
- (void)verifyTrigger:(UAScheduleTrigger *)trigger triggerFireBlock:(void (^)(void))triggerFireBlock {
    // test pause and resume by pausing now and resuming as late as possible
    [self.automationEngine pause];

    // Create a start date in the future
    NSDate *startDate = [NSDate dateWithTimeInterval:100 sinceDate:self.testDate.now];

    UAActionScheduleInfo *info = [UAActionScheduleInfo scheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder * _Nonnull builder) {
        builder.actions = @{@"cool": @"story"};
        builder.triggers = @[trigger];
        builder.start = startDate;
    }];

    __block NSString *scheduleId;
    XCTestExpectation *scheduled = [self expectationWithDescription:@"scheduled"];
    [self.automationEngine schedule:info completionHandler:^(UASchedule *schedule) {
        scheduleId = schedule.identifier;
        [scheduled fulfill];
    }];

    [self waitForTestExpectations];
    XCTAssertNotNil(scheduleId);

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:scheduleId];
    }] completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:scheduleId];
    }]];

    // When executeSchedule is called on the mockDelegate do this
    XCTestExpectation *executeSchedule = [self expectationWithDescription:@"schedule is executing"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(void) = (__bridge void (^)(void))arg;
        handler();
        [executeSchedule fulfill];
    }] executeSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:scheduleId];
    }] completionHandler:OCMOCK_ANY];

    // Trigger the action, should not trigger any actions
    triggerFireBlock();

    // Shift time to one second after the start date
    self.testDate.timeOffset = [startDate timeIntervalSinceDate:self.testDate.now] + 1;

    [self.automationEngine resume];

    // Trigger the actions now that its past the start
    triggerFireBlock();

    [self waitForTestExpectations];

    // Verify the schedule is deleted
    XCTestExpectation *fetchExpectation = [self expectationWithDescription:@"schedule fetched"];
    [self.automationEngine getScheduleWithID:scheduleId completionHandler:^(UASchedule *schedule) {
        [fetchExpectation fulfill];
    }];
    [self waitForTestExpectations];
}

- (void)emitEvent:(UAEvent *)event {
    if ([event isKindOfClass:[UACustomEvent class]]) {
        [self.notificationCenter postNotificationName:UACustomEventAdded
                                               object:self
                                             userInfo:@{UAEventKey: event}];
    }

    if ([event isKindOfClass:[UARegionEvent class]]) {
        [self.notificationCenter postNotificationName:UARegionEventAdded
                                               object:self
                                             userInfo:@{UAEventKey: event}];
    }
}

- (void)emitScreenTracked:(NSString *)screen {
    [self.notificationCenter postNotificationName:UAScreenTracked
                                           object:self
                                         userInfo:screen == nil ? @{} : @{UAScreenKey: screen}];
}

- (UAScheduleInfo *)createScheduleInfoWithBuilder:(UAScheduleInfoBuilder *)builder {
    return [[UAActionScheduleInfo alloc] initWithBuilder:builder];
}

@end




