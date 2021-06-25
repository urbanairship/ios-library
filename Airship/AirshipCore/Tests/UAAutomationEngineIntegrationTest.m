/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAAutomationEngine+Internal.h"
#import "UAirship+Internal.h"
#import "UARegionEvent.h"
#import "UACustomEvent.h"
#import "UAAutomationStore+Internal.h"
#import "UAJSONPredicate.h"
#import "UARuntimeConfig.h"
#import "UAScheduleDelay.h"
#import "UAScheduleData+Internal.h"
#import "UATestRuntimeConfig.h"
#import "UAActionSchedule.h"
#import "UAScheduleEdits+Internal.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

static NSString * const UAAutomationEngineDelayTaskID = @"UAAutomationEngine.delay";
static NSString * const UAAutomationEngineIntervalTaskID = @"UAAutomationEngine.interval";

@interface UAAutomationEngineIntegrationTest : UABaseTest
@property (nonatomic, strong) UAAutomationEngine *automationEngine;
@property (nonatomic, strong) UAAutomationStore *testStore;
@property (nonatomic, strong) id mockedApplication;
@property (nonatomic, strong) id mockAppStateTracker;
@property (nonatomic, strong) id mockDelegate;
@property (nonatomic, strong) id mockMetrics;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockTaskManager;
@property (nonatomic, strong) UATestNetworkMonitor *testNetworkMonitor;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UATestDispatcher *dispatcher;
@property (nonatomic, copy) void (^taskEnqueueBlock)(void);
@property (nonatomic, strong) UATestDate *testDate;
@property(nonatomic, copy) void (^launchHandler)(id<UATask>);
@end

#define UAAUTOMATIONENGINETESTS_SCHEDULE_LIMIT 100

@implementation UAAutomationEngineIntegrationTest
- (void)setUp {
    [super setUp];

    self.testDate = [[UATestDate alloc] initWithOffset:0 dateOverride:[NSDate date]];
    self.dispatcher = [[UATestDispatcher alloc] init];
    self.mockedApplication = [self mockForClass:[UIApplication class]];
    self.mockAppStateTracker = [self mockForClass:[UAAppStateTracker class]];

    self.mockDelegate = [self mockForProtocol:@protocol(UAAutomationEngineDelegate)];

    UARuntimeConfig *config = [UATestRuntimeConfig testConfig];
    self.testStore = [UAAutomationStore automationStoreWithConfig:config
                                                    scheduleLimit:UAAUTOMATIONENGINETESTS_SCHEDULE_LIMIT
                                                         inMemory:YES
                                                             date:self.testDate];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];

    self.mockTaskManager = [self mockForClass:[UATaskManager class]];

    // Capture the task launcher
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        self.launchHandler =  (__bridge void (^)(id<UATask>))arg;
    }] registerForTaskWithIDs:@[UAAutomationEngineDelayTaskID, UAAutomationEngineIntervalTaskID] dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];

    self.mockMetrics = [self mockForClass:[UAApplicationMetrics class]];
    [[[self.mockAirship stub] andReturn:self.mockMetrics] applicationMetrics];


    self.notificationCenter = [[NSNotificationCenter alloc] init];

    self.testNetworkMonitor = [[UATestNetworkMonitor alloc] init];


    self.automationEngine = [UAAutomationEngine automationEngineWithAutomationStore:self.testStore
                                                                    appStateTracker:self.mockAppStateTracker
                                                                        taskManager:self.mockTaskManager
                                                                     networkMonitor:self.testNetworkMonitor
                                                                 notificationCenter:self.notificationCenter
                                                                         dispatcher:self.dispatcher
                                                                        application:self.mockedApplication
                                                                               date:self.testDate];

    self.automationEngine.delegate = self.mockDelegate;
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
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{@"cool": @"story"}
                                                    builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testScheduleMultiple {
    UASchedule *scheduleOne = [UAActionSchedule scheduleWithActions:@{@"cool": @"story"}
                                                       builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];

    UASchedule *scheduleTwo = [UAActionSchedule scheduleWithActions:@{@"cool": @"story"}
                                                       builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];


    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled actions"];

    // test
    [self.automationEngine scheduleMultiple:@[scheduleOne, scheduleTwo]
                          completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [testExpectation fulfill];
    }];

    // verify
    [self waitForTestExpectations];
}

- (void)testScheduleInvalidActionInfo {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled action"];

    // Missing triggers
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{@"cool": @"story"}
                                                    builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
    }];

    [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testScheduleOverLimit {
    // Schedule to the limit
    for (int i = 0; i < UAAUTOMATIONENGINETESTS_SCHEDULE_LIMIT; i++) {
        UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{}
                                                        builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.triggers = @[foregroundTrigger];
        }];

        XCTestExpectation *testExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"scheduled: %d", i]];

        [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
            XCTAssertTrue(result);
            [testExpectation fulfill];
        }];
    }

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled failed"];

    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{}
                                                    builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
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
            return schedule.priority == [testPriorityLevels[i] intValue];
        }]];

        [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:4];
            void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
            handler(UAAutomationSchedulePrepareResultContinue);
        }] prepareSchedule:OCMOCK_ANY triggerContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

        [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
            [executedPriorityLevel addObject:testPriorityLevels[i]];
            [expectation fulfill];

        }] executeSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
            UASchedule *schedule = obj;
            return schedule.priority == [testPriorityLevels[i] intValue];
        }] completionHandler:OCMOCK_ANY];

        // Give all the schedules the same trigger
        UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];

        UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{}
                                                        builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
            builder.priority = [testPriorityLevels[i] integerValue];
            builder.triggers = @[trigger];
        }];


        [self.automationEngine schedule:schedule completionHandler:nil];
    }

    // Trigger the schedules with a foreground notification
    [self simulateForegroundTransition];

    [self waitForTestExpectations:runExpectations];

    XCTAssertEqualObjects(executedPriorityLevel, expectedPriorityLevel);
}

- (void)testGetGroups {
    NSMutableArray *expectedFooSchedules = [NSMutableArray array];

    // Schedule 10 under the group "foo"
    for (int i = 0; i < 10; i++) {
        UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{}
                                                        builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.triggers = @[foregroundTrigger];
            builder.group = @"foo";
        }];

        [expectedFooSchedules addObject:schedule];
        [self.automationEngine schedule:schedule completionHandler:nil];
    }

    NSMutableArray *expectedBarSchedules = [NSMutableArray array];

    // Schedule 15 under "bar"
    for (int i = 0; i < 15; i++) {
        UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{}
                                                        builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.triggers = @[foregroundTrigger];
            builder.group = @"bar";
        }];

        [expectedBarSchedules addObject:schedule];
        [self.automationEngine schedule:schedule completionHandler:nil];
    }

    XCTestExpectation *fooGroupExpectation = [self expectationWithDescription:@"schedules foo fetched properly"];

    // Verify foo group
    [self.automationEngine getSchedulesWithGroup:@"foo"
                                            type:UAScheduleTypeActions
                               completionHandler:^(NSArray<UASchedule *> *result) {
        XCTAssertEqualObjects([NSSet setWithArray:expectedFooSchedules], [NSSet setWithArray:result]);
        [fooGroupExpectation fulfill];
    }];

    XCTestExpectation *barGroupExpectation = [self expectationWithDescription:@"schedules bar fetched properly"];

    // Verify bar group
    [self.automationEngine getSchedulesWithGroup:@"bar"
                                            type:UAScheduleTypeActions
                               completionHandler:^(NSArray<UASchedule *> *result) {
        XCTAssertEqualObjects([NSSet setWithArray:expectedBarSchedules], [NSSet setWithArray:result]);
        [barGroupExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetSchedule {
    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled actions"];

    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [scheduleExpectation fulfill];
    }];

    [self waitForTestExpectations];

    XCTestExpectation *fetchExpectation = [self expectationWithDescription:@"schedules fetched properly"];

    [self.automationEngine getScheduleWithID:schedule.identifier
                                        type:UAScheduleTypeActions
                           completionHandler:^(UASchedule *schedule) {
        XCTAssertEqualObjects(schedule, schedule);;
        [fetchExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetAllUnended {
    NSMutableArray *expectedSchedules = [NSMutableArray array];

    // Schedule some actions
    for (int i = 0; i < 10; i++) {
        UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.triggers = @[foregroundTrigger];
        }];
        [expectedSchedules addObject:schedule];
        [self.automationEngine schedule:schedule completionHandler:nil];
    }
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
        builder.end = [NSDate dateWithTimeIntervalSince1970:0];
    }];

    [self.automationEngine schedule:schedule completionHandler:nil];

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"schedules fetched properly"];
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqualObjects([NSSet setWithArray:expectedSchedules], [NSSet setWithArray:result]);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCancelSchedule {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:schedule completionHandler:nil];

    XCTestExpectation *cancelledExpectation = [self expectationWithDescription:@"schedule cancelled"];

    [self.automationEngine cancelScheduleWithID:schedule.identifier completionHandler:^(BOOL cancelled){
        XCTAssertTrue(cancelled);
        [cancelledExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCancelScheduleDoesNotExist {
    XCTestExpectation *cancelledExpectation = [self expectationWithDescription:@"schedule cancelled"];

    [self.automationEngine cancelScheduleWithID:@"does not exist" completionHandler:^(BOOL cancelled){
        XCTAssertFalse(cancelled);
        [cancelledExpectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCancelGroup {
    NSMutableArray *fooSchedules = [NSMutableArray array];

    // Schedule 10 under "foo"
    for (int i = 0; i < 10; i++) {
        UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.triggers = @[foregroundTrigger];
            builder.group = @"foo";
        }];

        [self.automationEngine schedule:schedule completionHandler:nil];
        [fooSchedules addObject:schedule];
    }

    // Schedule 15 under "bar"
    NSMutableArray *barSchedules = [NSMutableArray array];

    for (int i = 0; i < 15; i++) {
        UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
            UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
            builder.triggers = @[foregroundTrigger];
            builder.group = @"bar";
        }];

        [self.automationEngine schedule:schedule completionHandler:nil];
        [barSchedules addObject:schedule];
    }

    XCTestExpectation *schedulesCanceled = [self expectationWithDescription:@"schedules canceled"];
    [self.automationEngine cancelSchedulesWithGroup:@"foo" completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [schedulesCanceled fulfill];
    }];

    XCTestExpectation *schedulesFeteched = [self expectationWithDescription:@"schedules fetched"];

    // Verify the "bar" schedules are still active
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqualObjects([NSSet setWithArray:barSchedules], [NSSet setWithArray:result]);
        [schedulesFeteched fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetExpiredSchedules {
    NSDate *futureDate = [NSDate dateWithTimeInterval:100 sinceDate:self.testDate.now];

    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
        builder.group = @"foo";
        builder.end = futureDate;
    }];

    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled action"];

    [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [scheduleExpectation fulfill];
    }];

    [self waitForTestExpectations];

    XCTestExpectation *availableExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqual(1, result.count);
        [availableExpectation fulfill];
    }];

    // Make sure we verified the schedule being availble before mocking the date
    [self waitForTestExpectations];

    // Shift time to one second after the futureDate
    self.testDate.offset = [futureDate timeIntervalSinceDate:self.testDate.now] + 1;

    // Verify getScheduleWithIdentifier:completionHandler: does not return the expired schedule
    XCTestExpectation *groupExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automationEngine getSchedulesWithGroup:@"foo"
                                            type:UAScheduleTypeActions
                               completionHandler:^(NSArray<UASchedule *> *result) {
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

    UASchedule *expiry = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
        builder.end = futureDate;
    }];

    XCTestExpectation *scheduleExpectation = [self expectationWithDescription:@"scheduled action"];

    [self.automationEngine schedule:expiry completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [scheduleExpectation fulfill];
    }];

    // Make sure we verified the schedule being availble before mocking the date
    [self waitForTestExpectations];

    // Shift time to one second after the futureDate
    self.testDate.offset = [futureDate timeIntervalSinceDate:self.testDate.now] + 1;

    // Schedule more actions
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
    }];

    // Verify we have the new schedule
    XCTestExpectation *allExpectation = [self expectationWithDescription:@"fetched schedule"];
    [self.automationEngine getSchedules:^(NSArray<UASchedule *> *result) {
        XCTAssertEqual(1, result.count);
        XCTAssertTrue([result containsObject:schedule]);
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
        [[[self.mockAppStateTracker expect] andReturnValue:@(UAApplicationStateActive)] state];
        [self simulateForegroundTransition];
    }];
}

- (void)testBackgroundDelay {
    // Start with a foreground state
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];


    UAScheduleDelay *delay = [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder * builder) {
        builder.appState = UAScheduleDelayAppStateBackground;
    }];

    [self verifyDelay:delay fulfillmentBlock:^{
        [[[self.mockAppStateTracker expect] andReturnValue:@(UAApplicationStateBackground)] state];
        [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToBackground object:nil];
    }];
}

- (void)testSecondsDelay {
    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    UAScheduleDelay *delay = [UAScheduleDelay delayWithBuilderBlock:^(UAScheduleDelayBuilder * builder) {
        builder.seconds = 1;
    }];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UATaskRequestOptions *options = (__bridge UATaskRequestOptions *)arg;

        id mockTask = [self mockForProtocol:@protocol(UATask)];
        [[[mockTask stub] andReturn:UAAutomationEngineDelayTaskID] taskID];
        [[[mockTask stub] andReturn:[UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend
                                                                    requiresNetwork:NO
                                                                             extras:@{@"identifier" : options.extras[@"identifier"]}]] requestOptions];
        self.launchHandler(mockTask);

    }] enqueueRequestWithID:OCMOCK_ANY options:OCMOCK_ANY initialDelay:1.0];

    [self verifyDelay:delay fulfillmentBlock:^{}];
}

- (void)testCancellationTriggers {
    // Schedule the action
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
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

    [self.automationEngine schedule:schedule completionHandler:nil];

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    // Verify the schedule data is pending execution
    XCTestExpectation *schedulePendingExecution = [self expectationWithDescription:@"pending execution"];

    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStatePreparingSchedule, [scheduleData.executionState intValue]);

        // This is expected behavior when the grace period is unset
        XCTAssertEqualWithAccuracy([scheduleData.end timeIntervalSinceNow], [[NSDate distantFuture] timeIntervalSinceNow], 0.01);
        [schedulePendingExecution fulfill];
    }];

    [self waitForTestExpectations];

    // Cancel the pending execution by foregrounding the app
    [self simulateForegroundTransition];

    // Verify the schedule is no longer pending execution
    XCTestExpectation *scheduleNotPendingExecution = [self expectationWithDescription:@"not pending execution"];
    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStateIdle, [scheduleData.executionState intValue]);
        [scheduleNotPendingExecution fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testEditsNoGracePeriod {
    // Schedule the action
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];
    }];


    [self.automationEngine schedule:schedule completionHandler:nil];


    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] triggerContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
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
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] completionHandler:OCMOCK_ANY];

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    [self waitForTestExpectations];

    XCTestExpectation *checkFinishedState = [self expectationWithDescription:@"not pending execution"];

    // Once a schedule without grace period is executed, it should be deleted
    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNil(scheduleData);
        [checkFinishedState fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testEdits {
    // Schedule the action
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        // One minute
        builder.editGracePeriod = 60 * 60;

        // One minute from now
        builder.end = [NSDate dateWithTimeInterval:60 * 60  sinceDate:self.testDate.now];

        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];
    }];


    [self.automationEngine schedule:schedule completionHandler:nil];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] triggerContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
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
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] completionHandler:OCMOCK_ANY];

    // move ahead 1:30
    self.testDate.offset = 60 * 60 * 1.5;

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    [self waitForTestExpectations];

    XCTestExpectation *checkFinishedState = [self expectationWithDescription:@"not pending execution"];

    [self.automationEngine getScheduleWithID:schedule.identifier type:UAScheduleTypeActions completionHandler:^(UASchedule * _Nullable schedule) {
        XCTAssertNotNil(schedule);
    }];

    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStateFinished, [scheduleData.executionState intValue]);
        [checkFinishedState fulfill];
    }];

    [self waitForTestExpectations];

    UAScheduleEdits *edits = [UAScheduleEdits editsWithBuilderBlock:^(UAScheduleEditsBuilder *builder) {
        builder.limit = @(2);
        builder.campaigns = @{@"neat": @"campaign"};
        builder.frequencyConstraintIDs = @[@"woot"];
    }];

    XCTestExpectation *updated = [self expectationWithDescription:@"schedule updated"];
    [self.automationEngine editScheduleWithID:schedule.identifier edits:edits completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [updated fulfill];
    }];

    XCTestExpectation *checkIdleState = [self expectationWithDescription:@"not pending execution"];

    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStateIdle, [scheduleData.executionState intValue]);
        XCTAssertEqualObjects(@{@"neat": @"campaign"}, scheduleData.campaigns);
        XCTAssertEqualObjects(@[@"woot"], scheduleData.frequencyConstraintIDs);
        [checkIdleState fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testEditsPastGracePeriod {
    // Schedule the action
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        // One minute
        builder.editGracePeriod = 60 * 60;

        // One minute from now
        builder.end = [NSDate dateWithTimeInterval:60 * 60  sinceDate:self.testDate.now];

        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];
    }];


    [self.automationEngine schedule:schedule completionHandler:nil];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] triggerContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
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
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] completionHandler:OCMOCK_ANY];

    // move ahead 2:30
    self.testDate.offset = 60 * 60 * 2.5;

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    [self waitForTestExpectations];

    XCTestExpectation *checkFinishedState = [self expectationWithDescription:@"not pending execution"];

    // Force a clean
    [self.automationEngine getScheduleWithID:schedule.identifier type:UAScheduleTypeActions completionHandler:^(UASchedule * _Nullable schedule) {
        XCTAssertNil(schedule);
        [checkFinishedState fulfill];
    }];

    [self waitForTestExpectations];

    UAScheduleEdits *edits = [UAScheduleEdits editsWithBuilderBlock:^(UAScheduleEditsBuilder *builder) {
        builder.limit = @(2);
    }];

    XCTestExpectation *updated = [self expectationWithDescription:@"schedule updated"];
    [self.automationEngine editScheduleWithID:schedule.identifier edits:edits completionHandler:^(BOOL result) {
        XCTAssertFalse(result);
        [updated fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testInterrupted {
    // Schedule the action
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];
        builder.limit = 2;
    }];

    [self.automationEngine schedule:schedule completionHandler:nil];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] triggerContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }]];

    // When executeSchedule is called on the delegate
    XCTestExpectation *executeSchedule = [self expectationWithDescription:@"schedule is executing"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        [executeSchedule fulfill];
    }] executeSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] completionHandler:OCMOCK_ANY];

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    [self waitForTestExpectations];

    XCTestExpectation *checkExecutingState = [self expectationWithDescription:@"executing"];
    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStateExecuting, [scheduleData.executionState intValue]);
        [checkExecutingState fulfill];
    }];

    [self waitForTestExpectations];

    XCTestExpectation *interruptedCalled = [self expectationWithDescription:@"interruptedCalled"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        [interruptedCalled fulfill];
    }] onExecutionInterrupted:schedule];

    [self.automationEngine stop];
    [self.automationEngine start];

    [self waitForTestExpectations];
    [self.mockDelegate verify];
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
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.interval = 100000;
        builder.limit = 2;
        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];
    }];

    [self.automationEngine schedule:schedule completionHandler:nil];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    XCTestExpectation *prepared = [self expectationWithDescription:@"schedule is prepared"];
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(prepareResult);
        [prepared fulfill];
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] triggerContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    [self waitForTestExpectations];

    XCTestExpectation *checkFinishedState = [self expectationWithDescription:@"Checked schedule state"];

    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData *scheduleData) {
        completionHandler(scheduleData);
        [checkFinishedState fulfill];
    }];

    [self waitForTestExpectations];
}


- (void)testInterval {
    // Schedule the action
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];
        builder.interval = 100;
        builder.limit = 2;
        builder.identifier = @"test";
    }];

    [self.automationEngine schedule:schedule completionHandler:nil];

    // When executeSchedule is called on the mockDelegate do this
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(void) = (__bridge void (^)(void))arg;
        handler();
    }] executeSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return [schedule.identifier isEqualToString:schedule.identifier];
    }] completionHandler:OCMOCK_ANY];

    // When prepareSchedule is called on the mockDelegate do this
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] triggerContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }]];

    [[[self.mockedApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    XCTestExpectation *taskScheduled = [self expectationWithDescription:@"task scheduled"];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        [taskScheduled fulfill];
    }] enqueueRequestWithID:OCMOCK_ANY options:OCMOCK_ANY initialDelay:100];

    // Trigger the scheduled actions
    UACustomEvent *purchase = [UACustomEvent eventWithName:@"purchase"];
    [self emitEvent:purchase];

    // Wait for the action to fire
    [self waitForTestExpectations];

    // Verify the schedule is paused
    XCTestExpectation *checkPauseState = [self expectationWithDescription:@"pause state"];
    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStatePaused, [scheduleData.executionState intValue]);
        [checkPauseState fulfill];
    }];

    [self waitForTestExpectations];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAAutomationEngineIntervalTaskID] taskID];
    [[[mockTask stub] andReturn:[UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend
                                                                requiresNetwork:NO
                                                                         extras:@{@"identifier" : @"test"}]] requestOptions];
    // Launch the task
    self.launchHandler(mockTask);

    // Verify we are back to idle
    XCTestExpectation *checkIdleState = [self expectationWithDescription:@"idle state"];
    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData *scheduleData) {
        XCTAssertNotNil(scheduleData);
        XCTAssertEqual(UAScheduleStateIdle, [scheduleData.executionState intValue]);
        [checkIdleState fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testNetworkConnectivityResumed {
    // Simulate initial connectivity callback on init
    self.testNetworkMonitor.isConnectedOverride = NO;

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled action"];

    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{@"cool": @"story"}
                                                    builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];

    // Set state to waiting schedule conditions;
    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData * data) {
        data.executionState = @(UAScheduleStateWaitingScheduleConditions);
    }];

    // Have the delegate signal that the schedule is ready to execute
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(UAAutomationScheduleReadyResultContinue)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *s = obj;
        return  [schedule.identifier isEqualToString:s.identifier];
    }]];

    // Fire connectivity change callback
    self.testNetworkMonitor.isConnectedOverride = YES;

    // Schedule should be executing
    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData * data) {
        XCTAssertEqualObjects(data.executionState, @(UAScheduleStateExecuting));
    }];
}

- (void)testNetworkConnectivityFirstCallback {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"scheduled action"];

    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{@"cool": @"story"}
                                                    builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        UAScheduleTrigger *foregroundTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];
        builder.triggers = @[foregroundTrigger];
    }];

    [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [testExpectation fulfill];
    }];

    [self waitForTestExpectations];

    // Set state to waiting schedule conditions;
    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData * data) {
        data.executionState = @(UAScheduleStateWaitingScheduleConditions);
    }];

    // Have the delegate signal that the schedule is ready to execute
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(UAAutomationScheduleReadyResultContinue)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *s = obj;
        return  [schedule.identifier isEqualToString:s.identifier];
    }]];

    // Fire connectivity change callback
    self.testNetworkMonitor.isConnectedOverride = YES;

    // Schedule should still be waiting conditions
    [self.automationEngine.automationStore getSchedule:schedule.identifier completionHandler:^(UAScheduleData * data) {
        XCTAssertEqualObjects(data.executionState, @(UAScheduleStateWaitingScheduleConditions));
    }];
}

/**
 * Helper method for simulating a full transition from the background to the active state.
 */
- (void)simulateForegroundTransition {
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
}

- (void)simulateBackgroundTransition {
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToBackground object:nil];
}

- (void)verifyDelay:(UAScheduleDelay *)delay fulfillmentBlock:(void (^)(void))fulfillmentBlock {
    // Schedule the action
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"purchase"];
        UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
        UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];
        builder.triggers = @[[UAScheduleTrigger customEventTriggerWithPredicate:predicate count:1]];

        builder.delay = delay;
    }];

    [self.automationEngine schedule:schedule completionHandler:nil];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }]];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] triggerContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

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
        return  [schedule.identifier isEqualToString:schedule.identifier];
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
    [self.automationEngine getScheduleWithID:schedule.identifier
                                        type:UAScheduleTypeActions
                           completionHandler:^(UASchedule *schedule) {
        XCTAssertNil(schedule);
        [fetchExpectation fulfill];
    }];

    [self waitForTestExpectations];
}


- (void)verifyStateTrigger:(UAScheduleTrigger *)trigger {
    NSString *uuid = [NSUUID UUID].UUIDString;
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[trigger];
        builder.group = uuid;
    }];

    XCTestExpectation *scheduled = [self expectationWithDescription:@"scheduled"];
    XCTestExpectation *prepared = [self expectationWithDescription:@"schedule prepared"];
    XCTestExpectation *executed = [self expectationWithDescription:@"schedule executed"];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
        [prepared fulfill];
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.group isEqualToString:uuid];
    }] triggerContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.group isEqualToString:uuid];
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
        return  [schedule.group isEqualToString:uuid];
    }] completionHandler:OCMOCK_ANY];

    // Schedule
    [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
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

    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[trigger];
        builder.start = startDate;
    }];

    XCTestExpectation *scheduled = [self expectationWithDescription:@"scheduled"];
    [self.automationEngine schedule:schedule completionHandler:^(BOOL result) {
        [scheduled fulfill];
    }];

    [self waitForTestExpectations];

    // When prepareSchedule:completionHandler is called on the mockDelegate call the callback
    [[[self.mockDelegate expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UAAutomationSchedulePrepareResult) = (__bridge void (^)(UAAutomationSchedulePrepareResult))arg;
        handler(UAAutomationSchedulePrepareResultContinue);
    }] prepareSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] triggerContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // When isScheduleReadyToExecute is called on the mockDelegate do this
    [[[self.mockDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] isScheduleReadyToExecute:[OCMArg checkWithBlock:^BOOL(id obj) {
        UASchedule *schedule = obj;
        return  [schedule.identifier isEqualToString:schedule.identifier];
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
        return  [schedule.identifier isEqualToString:schedule.identifier];
    }] completionHandler:OCMOCK_ANY];

    // Trigger the action, should not trigger any actions
    triggerFireBlock();

    // Shift time to one second after the start date
    self.testDate.offset = [startDate timeIntervalSinceDate:self.testDate.now] + 1;

    [self.automationEngine resume];

    // Trigger the actions now that its past the start
    triggerFireBlock();

    [self waitForTestExpectations];

    // Verify the schedule is deleted
    XCTestExpectation *fetchExpectation = [self expectationWithDescription:@"schedule fetched"];
    [self.automationEngine getScheduleWithID:schedule.identifier
                                        type:UAScheduleTypeActions
                           completionHandler:^(UASchedule *schedule) {
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

@end
