/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"

#import "UAirship+Internal.h"
#import "UAInAppMessageAdapter.h"
#import "UAInAppMessageManager+Internal.h"
#import "UASchedule+Internal.h"

@interface UAInAppMessageManagerTest : UABaseTest
@property(nonatomic, strong) id mockAdapter;
@property(nonatomic, strong) id mockAutomationEngine;
@property(nonatomic, strong) UAInAppMessageScheduleInfo *scheduleInfo;

@end

@implementation UAInAppMessageManagerTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    self.mockAdapter = [self mockForProtocol:@protocol(UAInAppMessageAdapter)];
    self.mockAutomationEngine = [self mockForClass:[UAAutomationEngine class]];

    self.scheduleInfo = [UAInAppMessageScheduleInfo inAppMessageScheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder * _Nonnull builder) {
        UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
            builder.identifier = @"test identifier";
            builder.displayType = @"banner";
        }];

        builder.message = message;
    }];
}

- (void)tearDown {
    [self.mockAdapter stopMocking];

    [super tearDown];
}

- (void)testIsScheduleReady {
    UAInAppMessageManager *manager = [UAInAppMessageManager managerWithAutomationEngine:self.mockAutomationEngine];

    // Set factory for banner type
    [manager setFactoryBlock:^id<UAInAppMessageAdapter> _Nonnull(NSString *displayType) {
        return self.mockAdapter;
    } forDisplayType:@"banner"];

    // Expect prepare call when schedule conditions change
    [[self.mockAdapter expect] prepare:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^prepBlock)(void) = obj;
        // Expect schedule conditions changed when prepare completes/prep block runs
        [[self.mockAutomationEngine expect] scheduleConditionsChanged];

        prepBlock();
        return YES;
    }]];

    UASchedule *schedule = [UASchedule scheduleWithIdentifier:@"test IAM schedule" info:self.scheduleInfo];
    [manager isScheduleReadyToExecute:schedule];

    [self.mockAdapter verify];
    [self.mockAutomationEngine verify];
}

- (void)testIsScheduleReadyNoFactorySet {
    UAInAppMessageManager *manager = [UAInAppMessageManager managerWithAutomationEngine:self.mockAutomationEngine];

    // Expect prepare call when schedule conditions change
    [[self.mockAdapter reject] prepare:OCMOCK_ANY];

    UASchedule *schedule = [UASchedule scheduleWithIdentifier:@"test IAM schedule" info:self.scheduleInfo];
    [manager isScheduleReadyToExecute:schedule];

    [self.mockAutomationEngine verify];
    [self.mockAdapter verify];
}

- (void)testExecuteSchedule {
    UAInAppMessageManager *manager = [UAInAppMessageManager managerWithAutomationEngine:self.mockAutomationEngine];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"expected_id" info:self.scheduleInfo];

    //Set factory block with banner display type
    [manager setFactoryBlock:^id<UAInAppMessageAdapter> _Nonnull(NSString *displayType) {
        return self.mockAdapter;
    } forDisplayType:@"banner"];

    //Check Schedule to set current schedule ID
    [manager isScheduleReadyToExecute:testSchedule];

    XCTestExpectation *displayBlockCalled = [self expectationWithDescription:@"display block should be called"];

    // Expect delay on first executeSchedule call
    [[self.mockAdapter expect] display:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^displayBlock)(void) = obj;
        displayBlock();

        [displayBlockCalled fulfill];
        return YES;
    }]];

    __block BOOL executeCompletionCalled = NO;

    // Call to executeSchedule should execute display block
    [manager executeSchedule:testSchedule completionHandler:^{
        executeCompletionCalled = YES;
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    // Ensure the delegate calls the execute completion block
    XCTAssertTrue(executeCompletionCalled);
    [self.mockAdapter verify];
}

- (void)testDisplayLock {
    UAInAppMessageManager *manager = [UAInAppMessageManager managerWithAutomationEngine:self.mockAutomationEngine];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"expected_id" info:self.scheduleInfo];

    //Set factory block with banner display type
    [manager setFactoryBlock:^id<UAInAppMessageAdapter> _Nonnull(NSString *displayType) {
        return self.mockAdapter;
    } forDisplayType:@"banner"];

    //Check Schedule to set current schedule ID
    [manager isScheduleReadyToExecute:testSchedule];

    // Shorted the display interval to 1 second
    manager.displayInterval = 1;

    XCTestExpectation *displayBlockCalled = [self expectationWithDescription:@"display block should be called"];

    // Expect delay on first executeSchedule call
    [[self.mockAdapter expect] display:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^displayBlock)(void) = obj;
        displayBlock();

        // Schedule should not be ready immediately after display (2nd call to isScheduleReady)
        XCTAssertFalse([manager isScheduleReadyToExecute:testSchedule]);

        [displayBlockCalled fulfill];
        return YES;
    }]];

    // Call to executeSchedule should execute display block and lock display
    [manager executeSchedule:testSchedule completionHandler:^{}];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    // Expect update to schedule conditions changed on unlock
    [[self.mockAutomationEngine expect] scheduleConditionsChanged];

    // Wait for unlock interval
    XCTestExpectation *unlockInterval = [self expectationWithDescription:@"wait interval"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(manager.displayInterval+1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [unlockInterval fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:nil];

    // Expect prepare call when schedule conditions change
    [[self.mockAdapter expect] prepare:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^prepBlock)(void) = obj;
        // Expect schedule conditions changed when prepare completes/prep block runs
        [[self.mockAutomationEngine expect] scheduleConditionsChanged];

        // Run prep block
        prepBlock();

        // Schedule should be ready after prep block (4th call to isScheduleReady)
        XCTAssertTrue([manager isScheduleReadyToExecute:testSchedule]);

        return YES;
    }]];
    
    // Schedule should be return false but prepare once screen unlocks (3rd call to isScheduleReady)
    XCTAssertFalse([manager isScheduleReadyToExecute:testSchedule]);

    [self.mockAdapter verify];
    [self.mockAutomationEngine verify];
}

- (void)testCancelMessage {
    UAInAppMessageManager *manager = [UAInAppMessageManager managerWithAutomationEngine:self.mockAutomationEngine];

    [[self.mockAutomationEngine expect] cancelSchedulesWithGroup:self.scheduleInfo.message.identifier];

    [manager cancelMessageWithID:self.scheduleInfo.message.identifier];

    [self.mockAutomationEngine verify];
}

- (void)testCancelSchedule {
    UAInAppMessageManager *manager = [UAInAppMessageManager managerWithAutomationEngine:self.mockAutomationEngine];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"expected_id" info:self.scheduleInfo];

    [[self.mockAutomationEngine expect] cancelScheduleWithIdentifier:testSchedule.identifier];

    [manager cancelMessageWithScheduleID:testSchedule.identifier];

    [self.mockAutomationEngine verify];
}

@end
