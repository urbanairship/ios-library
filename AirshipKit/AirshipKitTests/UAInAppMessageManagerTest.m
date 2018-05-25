/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"

#import "UAirship+Internal.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageManager+Internal.h"
#import "UASchedule+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAPush+Internal.h"
#import "UAInAppMessageAudience.h"
#import "UALocation+Internal.h"
#import "UAActionRunner+Internal.h"
#import "UAInAppMessageAudienceChecks+Internal.h"

@interface UAInAppMessageManagerTest : UABaseTest
@property(nonatomic, strong) UAInAppMessageManager *manager;
@property(nonatomic, strong) id mockDelegate;
@property(nonatomic, strong) id mockAdapter;
@property(nonatomic, strong) id mockAutomationEngine;
@property(nonatomic, strong) UAInAppMessageScheduleInfo *scheduleInfo;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockActionRunner;
@end

@implementation UAInAppMessageManagerTest

- (void)setUp {
    [super setUp];

    self.mockDelegate = [self mockForProtocol:@protocol(UAInAppMessagingDelegate)];
    self.mockAdapter = [self mockForProtocol:@protocol(UAInAppMessageAdapterProtocol)];
    self.mockAutomationEngine = [self mockForClass:[UAAutomationEngine class]];
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"UAInAppMessageManagerTest."];
    [self.dataStore removeAll];
    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockActionRunner = [self mockForClass:[UAActionRunner class]];

    self.manager = [UAInAppMessageManager managerWithAutomationEngine:self.mockAutomationEngine
                                                    remoteDataManager:[self mockForClass:[UARemoteDataManager class]]
                                                            dataStore:self.dataStore
                                                                 push:self.mockPush];

    self.manager.delegate = self.mockDelegate;

    self.scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder * _Nonnull builder) {
        UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
            builder.identifier = @"test identifier";
            builder.actions = @{@"cool": @"story"};

            builder.displayContent = [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
                builder.placement = UAInAppMessageBannerPlacementTop;
                builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;

                UAInAppMessageTextInfo *heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                    builder.text = @"Here is a headline!";
                }];
                builder.heading = heading;

                UAInAppMessageTextInfo *buttonTex = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                    builder.text = @"Dismiss";
                }];

                UAInAppMessageButtonInfo *button = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
                    builder.label = buttonTex;
                    builder.identifier = @"button";
                }];

                builder.buttons = @[button];
            }];
            builder.audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
                builder.locationOptIn = @NO;
            }];
        }];

        builder.message = message;
    }];
}

- (void)tearDown {
    [self.mockDelegate stopMocking];
    [self.mockAdapter stopMocking];

    [super tearDown];
}

- (void)testIsScheduleReady {
    // Set factory for banner type
    UA_WEAKIFY(self)
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        UA_STRONGIFY(self)
        return self.mockAdapter;
    } forDisplayType:UAInAppMessageDisplayTypeBanner];

    XCTestExpectation *prepareCalled = [self expectationWithDescription:@"prepare should be called"];
    [[[self.mockAdapter expect] andDo:^(NSInvocation *invocation) {
        UA_STRONGIFY(self)
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:2];

        // Expect schedule conditions changed when prepare completes/prep block runs
        [[self.mockAutomationEngine expect] scheduleConditionsChanged];
        prepareBlock(UAInAppMessagePrepareResultSuccess);
        [prepareCalled fulfill];
    }] prepare:OCMOCK_ANY];

    [[self.mockDelegate expect] extendMessage:[OCMArg isKindOfClass:[UAInAppMessage class]]];

    UASchedule *schedule = [UASchedule scheduleWithIdentifier:@"test IAM schedule" info:self.scheduleInfo];
    XCTAssertFalse([self.manager isScheduleReadyToExecute:schedule]);

    [self waitForExpectationsWithTimeout:5 handler:nil];
    
    [self.mockAdapter verify];
    [self.mockDelegate verify];
    [self.mockAutomationEngine verify];
}

- (void)testIsScheduleReadyCancelPrepareResult {
    // Set factory for banner type
    UA_WEAKIFY(self)
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        UA_STRONGIFY(self)
        return self.mockAdapter;
    } forDisplayType:UAInAppMessageDisplayTypeBanner];

    XCTestExpectation *prepareCalled = [self expectationWithDescription:@"prepare should be called"];
    [[[self.mockAdapter expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:2];
        prepareBlock(UAInAppMessagePrepareResultCancel);
        [prepareCalled fulfill];
    }] prepare:OCMOCK_ANY];

    [self.mockAutomationEngine cancelScheduleWithID:@"test IAM schedule"];

    UASchedule *schedule = [UASchedule scheduleWithIdentifier:@"test IAM schedule" info:self.scheduleInfo];
    XCTAssertFalse([self.manager isScheduleReadyToExecute:schedule]);

    [self waitForExpectationsWithTimeout:5 handler:nil];

    [self.mockAdapter verify];
    [self.mockAutomationEngine verify];
}

- (void)testIsScheduleReadyNoFactorySet {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [self.manager setFactoryBlock:nil forDisplayType:UAInAppMessageDisplayTypeBanner];
#pragma clang diagnostic pop
    
    [[[self mockAutomationEngine] expect] cancelScheduleWithID:@"test IAM schedule"];

    UASchedule *schedule = [UASchedule scheduleWithIdentifier:@"test IAM schedule" info:self.scheduleInfo];
    XCTAssertFalse([self.manager isScheduleReadyToExecute:schedule]);

    [self.mockAutomationEngine verify];
    [self.mockAdapter verify];
}

- (void)testIsScheduleReadyNilAdapter {
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        return nil;
    } forDisplayType:UAInAppMessageDisplayTypeBanner];

    [[[self mockAutomationEngine] expect] cancelScheduleWithID:@"test IAM schedule"];

    UASchedule *schedule = [UASchedule scheduleWithIdentifier:@"test IAM schedule" info:self.scheduleInfo];
    XCTAssertFalse([self.manager isScheduleReadyToExecute:schedule]);

    [self.mockAutomationEngine verify];
    [self.mockAdapter verify];
}

- (void)testAudienceCheckFailure {
    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"expected_id" info:self.scheduleInfo];

    //Set factory block with banner display type
    UA_WEAKIFY(self)
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        UA_STRONGIFY(self)
        return self.mockAdapter;
    } forDisplayType:UAInAppMessageDisplayTypeBanner];

    // Mock the checks to reject the audience
    id checks = [self mockForClass:[UAInAppMessageAudienceChecks class]];
    [[[checks expect] andReturnValue:@(NO)] checkDisplayAudienceConditions:self.scheduleInfo.message.audience];

    // should never display for display, as audience will fail first
    [[self.mockAdapter reject] display:OCMOCK_ANY];
    [[self.mockAdapter reject] prepare:OCMOCK_ANY];

    __block BOOL executeCompletionCalled = NO;

    // Execute schedule
    [self.manager isScheduleReadyToExecute:testSchedule];
    [self.manager executeSchedule:testSchedule completionHandler:^{
        executeCompletionCalled = YES;
    }];

    // Ensure the delegate calls the execute completion block
    XCTAssertTrue(executeCompletionCalled);
    [self.mockAdapter verify];
    [self.mockDelegate verify];
    [checks verify];
}

- (void)testExecuteSchedule {
    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"expected_id" info:self.scheduleInfo];

    //Set factory block with banner display type
    UA_WEAKIFY(self)
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        UA_STRONGIFY(self)
        return self.mockAdapter;
    } forDisplayType:UAInAppMessageDisplayTypeBanner];

    XCTestExpectation *prepareCalled = [self expectationWithDescription:@"prepare should be called"];
    [[[self.mockAdapter expect] andDo:^(NSInvocation *invocation) {
        UA_STRONGIFY(self)
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:2];

        // Expect schedule conditions changed when prepare completes/prep block runs
        [[self.mockAutomationEngine expect] scheduleConditionsChanged];
        prepareBlock(UAInAppMessagePrepareResultSuccess);
        [prepareCalled fulfill];
    }] prepare:OCMOCK_ANY];

    XCTestExpectation *displayBlockCalled = [self expectationWithDescription:@"display block should be called"];
    [[[self.mockAdapter expect] andDo:^(NSInvocation *invocation) {
        void (^displayBlock)(UAInAppMessageResolution *);
        [invocation getArgument:&displayBlock atIndex:2];

        displayBlock([UAInAppMessageResolution userDismissedResolution]);

        [displayBlockCalled fulfill];
    }] display:OCMOCK_ANY];

    [[self.mockActionRunner expect] runActionsWithActionValues:self.scheduleInfo.message.actions
                                                     situation:UASituationManualInvocation
                                                      metadata:nil
                                             completionHandler:OCMOCK_ANY];

    [[self.mockDelegate expect] messageWillBeDisplayed:self.scheduleInfo.message scheduleID:testSchedule.identifier];
    [[self.mockDelegate expect] messageFinishedDisplaying:self.scheduleInfo.message scheduleID:testSchedule.identifier resolution:OCMOCK_ANY];

    __block BOOL executeCompletionCalled = NO;

    // Execute schedule
    [self.manager isScheduleReadyToExecute:testSchedule];
    [self.manager executeSchedule:testSchedule completionHandler:^{
        executeCompletionCalled = YES;
    }];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    // Ensure the delegate calls the execute completion block
    XCTAssertTrue(executeCompletionCalled);
    [self.mockAdapter verify];
    [self.mockDelegate verify];
    [self.mockActionRunner verify];
}

- (void)testDisplayLock {
    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"expected_id" info:self.scheduleInfo];

    //Set factory block with banner display type
    UA_WEAKIFY(self)
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        UA_STRONGIFY(self)
        return self.mockAdapter;
    } forDisplayType:UAInAppMessageDisplayTypeBanner];

    XCTestExpectation *prepareCalled = [self expectationWithDescription:@"prepare should be called"];
    [[[self.mockAdapter expect] andDo:^(NSInvocation *invocation) {
        UA_STRONGIFY(self)
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:2];

        // Expect schedule conditions changed when prepare completes/prep block runs
        [[self.mockAutomationEngine expect] scheduleConditionsChanged];
        prepareBlock(UAInAppMessagePrepareResultSuccess);
        [prepareCalled fulfill];
    }] prepare:OCMOCK_ANY];

    //Check Schedule to set current schedule ID
    XCTAssertFalse([self.manager isScheduleReadyToExecute:testSchedule]);

    // Shorten the display interval to 1 second
    self.manager.displayInterval = 1;

    XCTestExpectation *displayBlockCalled = [self expectationWithDescription:@"display block should be called"];

    [[[self.mockAdapter expect] andDo:^(NSInvocation *invocation) {
        void (^displayBlock)(UAInAppMessageResolution *);
        [invocation getArgument:&displayBlock atIndex:2];

        displayBlock([UAInAppMessageResolution messageClickResolution]);

        // Schedule should not be ready immediately after display (2nd call to isScheduleReady)
        XCTAssertFalse([self.manager isScheduleReadyToExecute:testSchedule]);

        [displayBlockCalled fulfill];
    }] display:OCMOCK_ANY];

    // Call to executeSchedule should execute display block and lock display
    [self.manager executeSchedule:testSchedule completionHandler:^{}];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    // Expect update to schedule conditions changed on unlock
    [[self.mockAutomationEngine expect] scheduleConditionsChanged];

    // Wait for unlock interval
    XCTestExpectation *unlockInterval = [self expectationWithDescription:@"wait interval"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.manager.displayInterval+1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [unlockInterval fulfill];
    });
    [self waitForExpectationsWithTimeout:5 handler:nil];


    // Schedule should be return false but prepare once screen unlocks (3rd call to isScheduleReady)
    XCTAssertFalse([self.manager isScheduleReadyToExecute:testSchedule]);

    [self.mockAdapter verify];
    [self.mockAutomationEngine verify];
}

- (void)testPauseDisplay {
    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"expected_id" info:self.scheduleInfo];

    //Set factory block with banner display type
    UA_WEAKIFY(self)
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        UA_STRONGIFY(self)
        return self.mockAdapter;
    } forDisplayType:UAInAppMessageDisplayTypeBanner];

    // Add block to send a successful prepare result and expect schedule conditions change
    XCTestExpectation *prepareCalled = [self expectationWithDescription:@"prepare should be called"];
    [[[self.mockAdapter expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:2];

        prepareBlock(UAInAppMessagePrepareResultSuccess);
        [prepareCalled fulfill];
    }] prepare:OCMOCK_ANY];

    //Check Schedule to set current schedule ID
    XCTAssertFalse([self.manager isScheduleReadyToExecute:testSchedule]);
    // Wait for prepare to finish
    [self waitForExpectationsWithTimeout:1 handler:nil];

    // Mock isReadyToDisplay to YES
    [[[self.mockAdapter stub] andReturnValue:OCMOCK_VALUE(YES)] isReadyToDisplay];

    // Pause the manager
    self.manager.paused = NO;

    // Should display when paused == NO
    XCTAssertTrue([self.manager isScheduleReadyToExecute:testSchedule]);

    // Pause the manager
    self.manager.paused = YES;

    // Should not display when paused
    XCTAssertFalse([self.manager isScheduleReadyToExecute:testSchedule]);

    // Expect schedule conditions when paused to unpaused transition occurs
    [[self.mockAutomationEngine expect] scheduleConditionsChanged];
    // Unpause the manager from being previously paused
    self.manager.paused = NO;

    [self.mockAdapter verify];
    [self.mockAutomationEngine verify];
}

- (void)testCancelMessage {
    UAInAppMessageManager *manager = [UAInAppMessageManager managerWithAutomationEngine:self.mockAutomationEngine
                                                                      remoteDataManager:[self mockForClass:[UARemoteDataManager class]]
                                                                              dataStore:self.dataStore
                                                                                   push:self.mockPush];

    [[self.mockAutomationEngine expect] cancelSchedulesWithGroup:self.scheduleInfo.message.identifier];

    [manager cancelMessagesWithID:self.scheduleInfo.message.identifier];

    [self.mockAutomationEngine verify];
}

- (void)testCancelSchedule {
    UAInAppMessageManager *manager = [UAInAppMessageManager managerWithAutomationEngine:self.mockAutomationEngine
                                                                              remoteDataManager:[self mockForClass:[UARemoteDataManager class]]
                                                                              dataStore:self.dataStore
                                                                                   push:self.mockPush];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"expected_id" info:self.scheduleInfo];

    [[self.mockAutomationEngine expect] cancelScheduleWithID:testSchedule.identifier];

    [manager cancelScheduleWithID:testSchedule.identifier];

    [self.mockAutomationEngine verify];
}

- (void)testComponentEnabled {
    XCTAssertTrue(self.manager.componentEnabled);

    // test disable
    [[self.mockAutomationEngine expect] pause];
    self.manager.componentEnabled = NO;

    // verify
    XCTAssertFalse(self.manager.componentEnabled);
    [self.mockAutomationEngine verify];

    // test enable
    [[self.mockAutomationEngine expect] resume];
    self.manager.componentEnabled = YES;

    // verify
    XCTAssertTrue(self.manager.componentEnabled);
    [self.mockAutomationEngine verify];
}

- (void)testEnable {
    XCTAssertTrue(self.manager.isEnabled);

    // test disable
    [[self.mockAutomationEngine expect] pause];
    self.manager.enabled = NO;

    // verify
    XCTAssertFalse(self.manager.isEnabled);
    [self.mockAutomationEngine verify];

    // test enable
    [[self.mockAutomationEngine expect] resume];
    self.manager.enabled = YES;

    // verify
    XCTAssertTrue(self.manager.isEnabled);
    [self.mockAutomationEngine verify];
}

- (void)testScheduleMessagesWithScheduleInfo {
    // setup
    UAInAppMessageScheduleInfo *anotherScheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder * _Nonnull builder) {
        UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
            builder.identifier = @"another test identifier";
        }];
        
        builder.message = message;
    }];
    NSArray<UAInAppMessageScheduleInfo *> *submittedScheduleInfos = @[self.scheduleInfo,anotherScheduleInfo];
    
    // expectations
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray *) = (__bridge void (^)(NSArray *))arg;
        
        if (completionHandler) {
            completionHandler(@[]);
        }
    }] scheduleMultiple:[OCMArg checkWithBlock:^BOOL(NSArray<UAInAppMessageScheduleInfo *> *scheduleInfos) {
        return [scheduleInfos isEqualToArray:submittedScheduleInfos];
    }] completionHandler:OCMOCK_ANY];
    
    // test
    __block BOOL completionHandlerCalled = NO;
    [self.manager scheduleMessagesWithScheduleInfo:submittedScheduleInfos completionHandler:^(NSArray<UASchedule *> *schedules) {
        completionHandlerCalled = YES;

    }];
    
    // verify
    XCTAssertTrue(completionHandlerCalled);
    [self.mockAutomationEngine verify];
}

@end
