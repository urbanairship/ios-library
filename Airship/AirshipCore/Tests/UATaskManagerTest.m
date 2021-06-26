/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAAirshipBaseTest.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UATaskManagerTest : UABaseTest
@property (nonatomic, strong) UATaskManager *taskManager;
@property (nonatomic, strong) UATestDispatcher *testDispatcher;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) UATestNetworkMonitor *testNetworkMonitor;
@end


@implementation UATaskManagerTest

- (void)setUp {
    self.testDispatcher = [[UATestDispatcher alloc] init];
    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.mockApplication = [self mockForClass:[UIApplication class]];
    self.testNetworkMonitor = [[UATestNetworkMonitor alloc] init];

    self.taskManager = [[UATaskManager alloc] initWithApplication:self.mockApplication
                                               notificationCenter:self.notificationCenter
                                                       dispatcher:self.testDispatcher
                                                   networkMonitor:self.testNetworkMonitor];
}

- (void)testLaunch {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:OCMOCK_ANY];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)45)] backgroundTimeRemaining];

    XCTestExpectation *taskRan = [self expectationWithDescription:@"task ran"];
    [self.taskManager registerForTaskWithID:@"test" dispatcher:UADispatcher.main launchHandler:^(id<UATask>task) {
        XCTAssertEqual(@"test", task.taskID);
        XCTAssertEqual(UATaskConflictPolicyAppend, task.requestOptions.conflictPolicy);
        XCTAssertFalse(task.requestOptions.isNetworkRequired);
        XCTAssertEqualObjects(@{@"neat": @"story"}, task.requestOptions.extras);

        [[self.mockApplication expect] endBackgroundTask:30];
        [task taskCompleted];
        [self.mockApplication verify];
        [taskRan fulfill];
    }];

    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                                requiresNetwork:NO
                                                                                         extras:@{@"neat": @"story"}];

    [self.taskManager enqueueRequestWithID:@"test" options:requestOptions];
    [self waitForTestExpectations];
}

- (void)testRetry {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:OCMOCK_ANY];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)45)] backgroundTimeRemaining];

    __block NSUInteger attempts = 0;
    [self.taskManager registerForTaskWithID:@"test" dispatcher:self.testDispatcher launchHandler:^(id<UATask>task) {
        attempts++;
        [task taskFailed];
    }];

    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                                requiresNetwork:NO
                                                                                         extras:@{@"neat": @"story"}];
    [self.taskManager enqueueRequestWithID:@"test" options:requestOptions];


    NSArray *times = @[@(30), @(60), @(120), @(120)];

    NSUInteger expectedAttempts = 1;
    for (id time in times) {
        NSTimeInterval backOff = [time doubleValue];

        [self.testDispatcher advanceTime:backOff - 1];
        XCTAssertEqual(expectedAttempts, attempts);

        [self.testDispatcher advanceTime:1];
        expectedAttempts++;
        XCTAssertEqual(expectedAttempts, attempts);
    }
}


- (void)testExpire {
    __block void (^expire)(void) = nil;
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        expire = (void(^)(void))obj;
        return YES;
    }]];

    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)45)] backgroundTimeRemaining];

    XCTestExpectation *taskRan = [self expectationWithDescription:@"task ran"];
    XCTestExpectation *taskExpired = [self expectationWithDescription:@"task expired"];

    [self.taskManager registerForTaskWithID:@"test" dispatcher:UADispatcher.main launchHandler:^(id<UATask>task) {
        UA_WEAKIFY(task)
        task.expirationHandler = ^{
            UA_STRONGIFY(task)
            [[self.mockApplication expect] endBackgroundTask:30];
            [task taskCompleted];
            [self.mockApplication verify];
            [taskExpired fulfill];
        };

        [taskRan fulfill];
    }];

    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                                requiresNetwork:NO
                                                                                         extras:@{@"neat": @"story"}];

    [self.taskManager enqueueRequestWithID:@"test" options:requestOptions];
    [self waitForTestExpectations:@[taskRan]];

    expire();
    [self waitForTestExpectations:@[taskExpired]];
}

- (void)testEnqueueWithDelay {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:OCMOCK_ANY];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)45)] backgroundTimeRemaining];

    __block BOOL ran = NO;
    [self.taskManager registerForTaskWithID:@"test" dispatcher:self.testDispatcher launchHandler:^(id<UATask>task) {
        ran = YES;
        [task taskCompleted];
    }];

    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                                requiresNetwork:NO
                                                                                         extras:@{@"neat": @"story"}];
    [self.taskManager enqueueRequestWithID:@"test" options:requestOptions initialDelay:100];

    [self.testDispatcher advanceTime:30];
    XCTAssertFalse(ran);

    [self.testDispatcher advanceTime:70];
    XCTAssertTrue(ran);
}

- (void)testConflictPolicyReplace {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:OCMOCK_ANY];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)45)] backgroundTimeRemaining];

    __block BOOL ran = NO;
    [self.taskManager registerForTaskWithID:@"test" dispatcher:self.testDispatcher launchHandler:^(id<UATask>task) {
        XCTAssertEqual(task.requestOptions.extras[@"subtask"], @"second");
        ran = YES;
        [task taskCompleted];
    }];

    UATaskRequestOptions *firstOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyReplace
                                                                              requiresNetwork:NO
                                                                                       extras:@{@"subtask": @"first"}];
    [self.taskManager enqueueRequestWithID:@"test" options:firstOptions initialDelay:100];


    UATaskRequestOptions *secondOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyReplace
                                                                               requiresNetwork:NO
                                                                                        extras:@{@"subtask": @"second"}];
    [self.taskManager enqueueRequestWithID:@"test" options:secondOptions initialDelay:100];

    [self.testDispatcher advanceTime:100];
    XCTAssertTrue(ran);
}


- (void)testConflictPolicyKeep {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:OCMOCK_ANY];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)45)] backgroundTimeRemaining];

    __block BOOL ran = NO;
    [self.taskManager registerForTaskWithID:@"test" dispatcher:self.testDispatcher launchHandler:^(id<UATask>task) {
        XCTAssertEqual(task.requestOptions.extras[@"subtask"], @"first");
        ran = YES;
        [task taskCompleted];
    }];

    UATaskRequestOptions *firstOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyReplace
                                                                              requiresNetwork:NO
                                                                                       extras:@{@"subtask": @"first"}];
    [self.taskManager enqueueRequestWithID:@"test" options:firstOptions initialDelay:100];


    UATaskRequestOptions *secondOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyKeep
                                                                               requiresNetwork:NO
                                                                                        extras:@{@"subtask": @"second"}];
    [self.taskManager enqueueRequestWithID:@"test" options:secondOptions initialDelay:100];

    [self.testDispatcher advanceTime:100];
    XCTAssertTrue(ran);
}

- (void)testConflictPolicyAppend {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:OCMOCK_ANY];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)45)] backgroundTimeRemaining];

    NSMutableSet *subtasks = [NSMutableSet set];
    [self.taskManager registerForTaskWithID:@"test" dispatcher:self.testDispatcher launchHandler:^(id<UATask>task) {
        [subtasks addObject:task.requestOptions.extras[@"subtask"]];
        [task taskCompleted];
    }];

    UATaskRequestOptions *firstOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyReplace
                                                                              requiresNetwork:NO
                                                                                       extras:@{@"subtask": @"first"}];
    [self.taskManager enqueueRequestWithID:@"test" options:firstOptions initialDelay:100];


    UATaskRequestOptions *secondOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                               requiresNetwork:NO
                                                                                        extras:@{@"subtask": @"second"}];
    [self.taskManager enqueueRequestWithID:@"test" options:secondOptions initialDelay:100];

    [self.testDispatcher advanceTime:100];
    XCTAssertEqual(2, subtasks.count);
    XCTAssertTrue([subtasks containsObject:@"first"]);
    XCTAssertTrue([subtasks containsObject:@"second"]);
}

- (void)testRequiresNetwork {
    self.testNetworkMonitor.isConnectedOverride = NO;
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:OCMOCK_ANY];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)45)] backgroundTimeRemaining];

    __block BOOL ran = NO;
    [self.taskManager registerForTaskWithID:@"test" dispatcher:self.testDispatcher launchHandler:^(id<UATask>task) {
        XCTAssertFalse(ran);
        ran = YES;
        [task taskCompleted];
    }];

    UATaskRequestOptions *options = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyReplace
                                                                         requiresNetwork:YES
                                                                                  extras:nil];
    [self.taskManager enqueueRequestWithID:@"test" options:options];

    XCTAssertFalse(ran);
    self.testNetworkMonitor.isConnectedOverride = YES;
    XCTAssertTrue(ran);
}

- (void)testNotEnoughBackgroundTime {
    __block NSTimeInterval backgroundRemainingTime = 29;
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:OCMOCK_ANY];
    [[[self.mockApplication stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&backgroundRemainingTime];
    }] backgroundTimeRemaining];

    __block BOOL ran = NO;
    [self.taskManager registerForTaskWithID:@"test" dispatcher:self.testDispatcher launchHandler:^(id<UATask>task) {
        XCTAssertFalse(ran);
        ran = YES;
        [task taskCompleted];
    }];

    UATaskRequestOptions *options = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyReplace
                                                                         requiresNetwork:NO
                                                                                  extras:nil];
    [self.taskManager enqueueRequestWithID:@"test" options:options];

    XCTAssertFalse(ran);
    backgroundRemainingTime = 30;
    [self.notificationCenter postNotificationName:UAAppStateTracker.didBecomeActiveNotification object:nil];
    XCTAssertTrue(ran);
}

- (void)testInvalidBackgroundTask {
    __block UIBackgroundTaskIdentifier backgroundTask = UIBackgroundTaskInvalid;
    [[[self.mockApplication stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:(void *)&backgroundTask];
    }]  beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:OCMOCK_ANY];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)45)] backgroundTimeRemaining];

    __block BOOL ran = NO;
    [self.taskManager registerForTaskWithID:@"test" dispatcher:self.testDispatcher launchHandler:^(id<UATask>task) {
        XCTAssertFalse(ran);
        ran = YES;
        [task taskCompleted];
    }];

    UATaskRequestOptions *options = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyReplace
                                                                         requiresNetwork:NO
                                                                                  extras:nil];
    [self.taskManager enqueueRequestWithID:@"test" options:options];

    XCTAssertFalse(ran);
    backgroundTask = 30;
    [self.notificationCenter postNotificationName:UAAppStateTracker.didBecomeActiveNotification object:nil];
    XCTAssertTrue(ran);
}

- (void)testRetryingRetriesOnBackground {
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithName:OCMOCK_ANY expirationHandler:OCMOCK_ANY];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)45)] backgroundTimeRemaining];

    __block NSUInteger attempts = 0;
    [self.taskManager registerForTaskWithID:@"test" dispatcher:self.testDispatcher launchHandler:^(id<UATask>task) {
        attempts++;
        [task taskFailed];
    }];

    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                                requiresNetwork:NO
                                                                                         extras:nil];
    [self.taskManager enqueueRequestWithID:@"test" options:requestOptions];
    XCTAssertEqual(1, attempts);

    [self.notificationCenter postNotificationName:UAAppStateTracker.didEnterBackgroundNotification object:nil];
    XCTAssertEqual(2, attempts);
}

@end

