/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"

#import "UAirship+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UASchedule+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInAppMessageAudience.h"
#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAInAppMessageTagSelector+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UAComponent+Internal.h"
#import "UAInAppAutomation+Internal.h"
#import "UAInAppMessageCustomDisplayContent+Internal.h"

@interface UAInAppAutomationTest : UAAirshipBaseTest
@property(nonatomic, strong) UAInAppAutomation *inAppAutomation;
@property(nonatomic, strong) id mockAutomationEngine;
@property(nonatomic, strong) id mockTagGroupsLookupManager;
@property(nonatomic, strong) id mockRemoteDataClient;
@property(nonatomic, strong) id mockInAppMessageManager;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id<UAAutomationEngineDelegate> engineDelegate;
@end

@implementation UAInAppAutomationTest

- (void)setUp {
    [super setUp];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturnValue:@(YES)] isDataCollectionEnabled];
    [UAirship setSharedAirship:self.mockAirship];

    self.mockAutomationEngine = [self mockForClass:[UAAutomationEngine class]];
    self.mockTagGroupsLookupManager = [self mockForClass:[UATagGroupsLookupManager class]];
    self.mockRemoteDataClient = [self mockForClass:[UAInAppRemoteDataClient class]];
    self.mockInAppMessageManager = [self mockForClass:[UAInAppMessageManager class]];

    [[[self.mockAutomationEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        self.engineDelegate =  (__bridge id<UAAutomationEngineDelegate>)arg;
    }] setDelegate:OCMOCK_ANY];

    self.inAppAutomation = [UAInAppAutomation automationWithEngine:self.mockAutomationEngine
                                            tagGroupsLookupManager:self.mockTagGroupsLookupManager
                                                  remoteDataClient:self.mockRemoteDataClient
                                                         dataStore:self.dataStore
                                              inAppMesssageManager:self.mockInAppMessageManager];

    XCTAssertNotNil(self.engineDelegate);
}

- (void)testCheckEmptyAudience {
    UAInAppMessageAudience *emptyAudience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {
    }];

    XCTestExpectation *checkFinished = [self expectationWithDescription:@"check audience finished"];
    [self.inAppAutomation checkAudience:emptyAudience completionHandler:^(BOOL inAudience, NSError * _Nullable error) {
        XCTAssertTrue(inAudience);
        XCTAssertNil(error);
        [checkFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCheckTagGroupAudience {
    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {
        builder.tagSelector = [UAInAppMessageTagSelector tag:@"neat" group:@"group"];
    }];

    UATagGroups *tagResponse = [UATagGroups tagGroupsWithTags:@{@"group" : @[@"neat"]}];
    [[[self.mockTagGroupsLookupManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^completionHandler)(UATagGroups * _Nullable tagGroups, NSError *error);
        completionHandler = (__bridge void(^)(UATagGroups * _Nullable tagGroups, NSError *error))arg;
        completionHandler(tagResponse, nil);
    }] getTagGroups:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    XCTestExpectation *checkFinished = [self expectationWithDescription:@"check audience finished"];
    [self.inAppAutomation checkAudience:audience completionHandler:^(BOOL inAudience, NSError * _Nullable error) {
        XCTAssertTrue(inAudience);
        XCTAssertNil(error);
        [checkFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCheckTagGroupAudienceError {
    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {
        builder.tagSelector = [UAInAppMessageTagSelector tag:@"neat" group:@"group"];
    }];

    NSError *error = [NSError errorWithDomain:@"com.urbanairship.test" code:1 userInfo:nil];
    [[[self.mockTagGroupsLookupManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^completionHandler)(UATagGroups * _Nullable tagGroups, NSError *error);
        completionHandler = (__bridge void(^)(UATagGroups * _Nullable tagGroups, NSError *error))arg;
        completionHandler(nil, error);    }] getTagGroups:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    XCTestExpectation *checkFinished = [self expectationWithDescription:@"check audience finished"];
    [self.inAppAutomation checkAudience:audience completionHandler:^(BOOL inAudience, NSError * _Nullable error) {
        XCTAssertFalse(inAudience);
        XCTAssertNotNil(error);
        [checkFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCheckTagGroupAudienceNotInAudience {
    UAInAppMessageAudience *audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {
        builder.tagSelector = [UAInAppMessageTagSelector tag:@"neat" group:@"group"];
    }];

    UATagGroups *tagResponse = [UATagGroups tagGroupsWithTags:@{@"group" : @[]}];
    [[[self.mockTagGroupsLookupManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^completionHandler)(UATagGroups * _Nullable tagGroups, NSError *error);
        completionHandler = (__bridge void(^)(UATagGroups * _Nullable tagGroups, NSError *error))arg;
        completionHandler(tagResponse, nil);
    }] getTagGroups:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *checkFinished = [self expectationWithDescription:@"check audience finished"];
    [self.inAppAutomation checkAudience:audience completionHandler:^(BOOL inAudience, NSError * _Nullable error) {
        XCTAssertFalse(inAudience);
        XCTAssertNil(error);
        [checkFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepare {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isScheduleUpToDate:testSchedule];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [[self.mockInAppMessageManager expect] prepareMessage:scheduleInfo.message
                                               scheduleID:@"schedule ID"
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    [self.engineDelegate prepareSchedule:testSchedule completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppMessageManager verify];
}

- (void)testPrepareScheduleInvalid {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(NO)] isScheduleUpToDate:testSchedule];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void (^block)(void);
        [invocation getArgument:&block atIndex:2];
        block();
    }] notifyOnUpdate:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:testSchedule completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultInvalidate, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}


- (void)testPrepareAudienceCheckFailureDefaultMissBehavior {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
            builder.audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {
                builder.notificationsOptIn = @(YES);
            }];
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isScheduleUpToDate:testSchedule];

    // Mock the checks to reject the audience
    id checks = [self mockForClass:[UAInAppMessageAudienceChecks class]];
    [[[checks expect] andReturnValue:@(NO)] checkDisplayAudienceConditions:scheduleInfo.message.audience tagGroups:nil];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:testSchedule completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [checks verify];
}

- (void)testPrepareAudienceCheckFailureMissBehaviorCancel {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
            builder.audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {
                builder.notificationsOptIn = @(YES);
                builder.missBehavior = UAInAppMessageAudienceMissBehaviorCancel;
            }];
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isScheduleUpToDate:testSchedule];

    // Mock the checks to reject the audience
    id checks = [self mockForClass:[UAInAppMessageAudienceChecks class]];
    [[[checks expect] andReturnValue:@(NO)] checkDisplayAudienceConditions:scheduleInfo.message.audience tagGroups:nil];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:testSchedule completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultCancel, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [checks verify];
}

- (void)testPrepareAudienceCheckFailureMissBehaviorSkip {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
            builder.audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {
                builder.notificationsOptIn = @(YES);
                builder.missBehavior = UAInAppMessageAudienceMissBehaviorSkip;
            }];
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isScheduleUpToDate:testSchedule];

    // Mock the checks to reject the audience
    id checks = [self mockForClass:[UAInAppMessageAudienceChecks class]];
    [[[checks expect] andReturnValue:@(NO)] checkDisplayAudienceConditions:scheduleInfo.message.audience tagGroups:nil];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:testSchedule completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [checks verify];
}

- (void)testPrepareAudienceCheckFailureMissBehaviorPenalize {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
            builder.audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {
                builder.notificationsOptIn = @(YES);
                builder.missBehavior = UAInAppMessageAudienceMissBehaviorPenalize;
            }];
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isScheduleUpToDate:testSchedule];

    // Mock the checks to reject the audience
    id checks = [self mockForClass:[UAInAppMessageAudienceChecks class]];
    [[[checks expect] andReturnValue:@(NO)] checkDisplayAudienceConditions:scheduleInfo.message.audience tagGroups:nil];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:testSchedule completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [checks verify];
}

- (void)testIsReady {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isScheduleUpToDate:testSchedule];

    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:testSchedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);
}

- (void)testIsNotReady {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isScheduleUpToDate:testSchedule];

    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultNotReady)] isReadyToDisplay:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:testSchedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultNotReady, result);
}

- (void)testIsReadyInvalid {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(NO)] isScheduleUpToDate:testSchedule];
    [[self.mockInAppMessageManager expect] scheduleExecutionAborted:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:testSchedule];
    XCTAssertEqual(UAAutomationScheduleReadyResultInvalidate, result);
    [self.mockInAppMessageManager verify];
}

- (void)testIsReadyPaused {
    self.inAppAutomation.paused = YES;

    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isScheduleUpToDate:testSchedule];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:testSchedule];
    XCTAssertEqual(UAAutomationScheduleReadyResultNotReady, result);
}

- (void)testExecute {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder *builder) {
        builder.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
            builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
            builder.identifier = @"message ID";
        }];
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
    }];

    UASchedule *testSchedule = [UASchedule scheduleWithIdentifier:@"schedule ID"
                                                             info:scheduleInfo
                                                         metadata:@{@"cool": @"story"}];

    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isRemoteSchedule:testSchedule];
    [[[self.mockRemoteDataClient stub] andReturnValue:@(YES)] isScheduleUpToDate:testSchedule];

    [[self.mockInAppMessageManager expect] displayMessageWithScheduleID:@"schedule ID" completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(void) = obj;
        completionBlock();
        return YES;
    }]];

    XCTestExpectation *executeFinished = [self expectationWithDescription:@"execute finished"];
    [self.engineDelegate executeSchedule:testSchedule completionHandler:^{
        [executeFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppMessageManager verify];
}


- (void)testCancelMessagesWithID {
    [[self.mockAutomationEngine expect] cancelSchedulesWithGroup:@"some ID" completionHandler:nil];

    [self.inAppAutomation cancelMessagesWithID:@"some ID"];
    [self.mockAutomationEngine verify];
}

- (void)testCancelMessagesWithIDCompletionHandler {
    UASchedule *schedule = [UASchedule scheduleWithIdentifier:@"foo" info:[UAScheduleInfo new] metadata:@{}];
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSArray *) = (__bridge void (^)(NSArray *))arg;
        completionHandler(@[schedule]);
    }] cancelSchedulesWithGroup:@"some ID" completionHandler:OCMOCK_ANY];

    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation cancelMessagesWithID:@"some ID" completionHandler:^(NSArray<UASchedule *> * _Nonnull schedules) {
        XCTAssertEqualObjects(schedules, @[schedule]);
        [blockInvoked fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testCancelSchedule {
    [[self.mockAutomationEngine expect] cancelScheduleWithID:@"some ID" completionHandler:nil];

    [self.inAppAutomation cancelScheduleWithID:@"some ID"];
    [self.mockAutomationEngine verify];
}

- (void)testCancelScheduleWithCompletionHandler {
    UASchedule *schedule = [UASchedule scheduleWithIdentifier:@"some ID" info:[UAScheduleInfo new] metadata:@{}];

    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UASchedule * _Nullable) = (__bridge void(^)(UASchedule * _Nullable))arg;
        completionHandler(schedule);
    }] cancelScheduleWithID:@"some ID" completionHandler:OCMOCK_ANY];

    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation cancelScheduleWithID:@"some ID" completionHandler:^(UASchedule *cancelled) {
        XCTAssertEqualObjects(cancelled, schedule);
        [blockInvoked fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testScheduleMessagesWithScheduleInfo {
    // setup
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder * _Nonnull builder) {
        UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
            builder.identifier = @"some identifier";
        }];

        builder.message = message;
    }];

    UAInAppMessageScheduleInfo *anotherScheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder * _Nonnull builder) {
        UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
            builder.identifier = @"some other identifier";
        }];

        builder.message = message;
    }];

    NSArray<UAInAppMessageScheduleInfo *> *submittedScheduleInfos = @[scheduleInfo, anotherScheduleInfo];

    // expectations
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(NSArray *) = (__bridge void (^)(NSArray *))arg;

        if (completionHandler) {
            completionHandler(@[]);
        }
    }] scheduleMultiple:[OCMArg checkWithBlock:^BOOL(NSArray<UAInAppMessageScheduleInfo *> *scheduleInfos) {
        return [scheduleInfos isEqualToArray:submittedScheduleInfos];
    }] metadata:@{} completionHandler:OCMOCK_ANY];

    // test
    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation scheduleMessagesWithScheduleInfo:submittedScheduleInfos metadata:@{} completionHandler:^(NSArray<UASchedule *> *schedules) {
        [blockInvoked fulfill];
    }];

    // verify
    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testComponentEnabled {
    XCTAssertTrue(self.inAppAutomation.componentEnabled);

    // test disable
    [[self.mockAutomationEngine expect] pause];
    self.inAppAutomation.componentEnabled = NO;

    // verify
    XCTAssertFalse(self.inAppAutomation.componentEnabled);
    [self.mockAutomationEngine verify];

    // test enable
    [[self.mockAutomationEngine expect] resume];
    self.inAppAutomation.componentEnabled = YES;

    // verify
    XCTAssertTrue(self.inAppAutomation.componentEnabled);
    [self.mockAutomationEngine verify];
}

- (void)testEnable {
    XCTAssertTrue(self.inAppAutomation.isEnabled);

    // test disable
    [[self.mockAutomationEngine expect] pause];
    self.inAppAutomation.enabled = NO;

    // verify
    XCTAssertFalse(self.inAppAutomation.isEnabled);
    [self.mockAutomationEngine verify];

    // test enable
    [[self.mockAutomationEngine expect] resume];
    self.inAppAutomation.enabled = YES;

    // verify
    XCTAssertTrue(self.inAppAutomation.isEnabled);
    [self.mockAutomationEngine verify];
}

@end

