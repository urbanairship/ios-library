/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"

#import "UAInAppMessageManager+Internal.h"
#import "UASchedule+Internal.h"
#import "UAScheduleAudience.h"
#import "UATagSelector+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UAComponent.h"
#import "UAInAppAutomation+Internal.h"
#import "UAInAppMessageCustomDisplayContent+Internal.h"
#import "UADeferredSchedule+Internal.h"
#import "AirshipTests-Swift.h"
#import "UARetriable+Internal.h"
#import "UAScheduleTriggerContext+Internal.h"

@import AirshipCore;
@import AirshipAutomationSwift;

@interface UAInAppAutomationTest : UAAirshipBaseTest
@property(nonatomic, strong) UAInAppAutomation *inAppAutomation;
@property(nonatomic, strong) id mockAutomationEngine;
@property(nonatomic, strong) id mockRemoteDataClient;
@property(nonatomic, strong) id mockInAppMessageManager;
@property(nonatomic, strong) id mockChannel;
@property(nonatomic, strong) id mockInAppCoreSwiftBridge;
@property(nonatomic, strong) id mockAudience;

@property(nonatomic, strong) UATestAirshipInstance *airship;
@property(nonatomic, strong) id mockFrequencyLimitManager;
@property(nonatomic, strong) UAPrivacyManager *privacyManager;
@property(nonatomic, strong) id<UAAutomationEngineDelegate> engineDelegate;
@property(nonatomic, assign) BOOL audienceMatch;

@end

@interface UAInAppAutomation()
- (void)prepareDeferredSchedule:(UASchedule *)schedule
                       audience:(nonnull UAInAppAudience *)audience
                 triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
               experimentResult:(nullable UAExperimentResult *)experimentResult
               retriableHandler:(UARetriableCompletionHandler) retriableHandler
              completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler;
@end

@implementation UAInAppAutomationTest

- (void)setUp {
    [super setUp];


    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];

    self.mockAutomationEngine = [self mockForClass:[UAAutomationEngine class]];
    self.mockInAppCoreSwiftBridge = [self mockForClass:[UAInAppCoreSwiftBridge class]];
    self.mockRemoteDataClient = [self mockForClass:[UAInAppRemoteDataClient class]];
    self.mockInAppMessageManager = [self mockForClass:[UAInAppMessageManager class]];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockFrequencyLimitManager = [self mockForProtocol:@protocol(UAFrequencyLimitManagerProtocol)];

    self.mockAudience = [self mockForClass:[UAInAppAudience class]];

    self.audienceMatch = YES;
    [[[self.mockAudience stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void(^callback)(BOOL, NSError *) =  (__bridge void (^)(BOOL, NSError *))arg;
        callback(self.audienceMatch, nil);
    }] evaluateAudienceWithCompletionHandler:OCMOCK_ANY];

    (void)[[[self.mockInAppCoreSwiftBridge stub] andReturn:self.mockAudience] audienceWithSelectorJSON:OCMOCK_ANY isNewUserEvaluationDate:OCMOCK_ANY contactID:OCMOCK_ANY error:[OCMArg setTo:nil]];

    [[[self.mockAutomationEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        self.engineDelegate =  (__bridge id<UAAutomationEngineDelegate>)arg;
    }] setDelegate:OCMOCK_ANY];

    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.components = @[self.mockChannel];
    self.airship.privacyManager = self.privacyManager;
    [self.airship makeShared];


    self.inAppAutomation = [UAInAppAutomation automationWithConfig:self.config
                                                  automationEngine:self.mockAutomationEngine
                                              inAppCoreSwiftBridge:self.mockInAppCoreSwiftBridge
                                                  remoteDataClient:self.mockRemoteDataClient
                                                         dataStore:self.dataStore
                                               inAppMessageManager:self.mockInAppMessageManager
                                                           channel:self.mockChannel
                                             frequencyLimitManager:self.mockFrequencyLimitManager
                                                    privacyManager:self.privacyManager];

    XCTAssertNotNil(self.engineDelegate);
}

- (void)testAutoPauseEnabled {
    UAConfig *config = [[UAConfig alloc] init];
    config.inProduction = NO;
    config.site = UACloudSiteUS;
    config.developmentAppKey = @"test-app-key";
    config.developmentAppSecret = @"test-app-secret";
    config.autoPauseInAppAutomationOnLaunch = YES;

    UARuntimeConfig *runtimeConfig = [[UARuntimeConfig alloc] initWithConfig:config dataStore:self.dataStore];

    self.inAppAutomation = [UAInAppAutomation automationWithConfig:runtimeConfig
                                                  automationEngine:self.mockAutomationEngine
                                              inAppCoreSwiftBridge:self.mockInAppCoreSwiftBridge
                                                  remoteDataClient:self.mockRemoteDataClient
                                                         dataStore:self.dataStore
                                               inAppMessageManager:self.mockInAppMessageManager
                                                           channel:self.mockChannel
                                             frequencyLimitManager:self.mockFrequencyLimitManager
                                                    privacyManager:self.privacyManager];

    XCTAssertTrue(self.inAppAutomation.isPaused);
}

- (void)testAutoPauseDisabled {
    UAConfig *config = [[UAConfig alloc] init];
    config.inProduction = NO;
    config.site = UACloudSiteUS;
    config.developmentAppKey = @"test-app-key";
    config.developmentAppSecret = @"test-app-secret";
    config.autoPauseInAppAutomationOnLaunch = NO;
    UARuntimeConfig *runtimeConfig = [[UARuntimeConfig alloc] initWithConfig:config dataStore:self.dataStore];

    self.inAppAutomation = [UAInAppAutomation automationWithConfig:runtimeConfig
                                                  automationEngine:self.mockAutomationEngine
                                              inAppCoreSwiftBridge:self.mockInAppCoreSwiftBridge
                                                  remoteDataClient:self.mockRemoteDataClient
                                                         dataStore:self.dataStore
                                               inAppMessageManager:self.mockInAppMessageManager
                                                           channel:self.mockChannel
                                             frequencyLimitManager:self.mockFrequencyLimitManager
                                                    privacyManager:self.privacyManager];

    XCTAssertFalse(self.inAppAutomation.isPaused);
}


- (void)testCheckEmptyAudience {
    UAScheduleAudience *emptyAudience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
    }];

    
    [[[self.mockAudience expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void(^callback)(BOOL, NSError *) =  (__bridge void (^)(BOOL, NSError *))arg;
        callback(YES, nil);
    }] evaluateAudienceWithCompletionHandler:OCMOCK_ANY];

    XCTestExpectation *checkFinished = [self expectationWithDescription:@"check audience finished"];
    [self.inAppAutomation checkAudience:emptyAudience completionHandler:^(BOOL inAudience, NSError * _Nullable error) {
        XCTAssertTrue(inAudience);
        XCTAssertNil(error);
        [checkFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepareMessage {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.reportingContext = @{@"some": @"reporting context"};
        builder.bypassHoldoutGroups = YES;
        builder.frequencyConstraintIDs = @
        [@"barConstraint", @"fooConstraint"];
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:@[@"barConstraint", @"fooConstraint"] completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{@"some": @"reporting context"}
                                         experimentResult:OCMOCK_ANY
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testPrepareMessageUnderLimit {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andReturnValue:@NO] isOverLimit];
    [[[mockChecker stub] andReturnValue:@YES] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{}
                                         experimentResult:OCMOCK_ANY
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockFrequencyLimitManager verify];
    [self.mockInAppMessageManager verify];
}

- (void)testPrepareMessageOverLimit {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andReturnValue:@YES] isOverLimit];
    [[[mockChecker stub] andReturnValue:@NO] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[self.mockInAppMessageManager reject] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:nil
                                         experimentResult:OCMOCK_ANY
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockFrequencyLimitManager verify];
    [self.mockInAppMessageManager verify];
}

- (void)testPrepareActions {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepareActionsUnderLimit {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andReturnValue:@NO] isOverLimit];
    [[[mockChecker stub] andReturnValue:@YES] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockFrequencyLimitManager verify];
}

- (void)testPrepareActionsOverLimit {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andReturnValue:@YES] isOverLimit];
    [[[mockChecker stub] andReturnValue:@NO] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockFrequencyLimitManager verify];
}

- (void)testPrepareDeferred {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger
                                                                                             event:@"some event"];
    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:YES];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[trigger];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.bypassHoldoutGroups = YES;
    }];

    NSDictionary *deferredResult = @{
        @"audience_match": @YES,
        @"type": @"in_app_message",
        @"message": message.toJSON
    };

    [[self.mockInAppCoreSwiftBridge stub] resolveDeferredWithUrl: deferred.URL
                                                       channelID: @"channel ID"
                                                       audience: self.mockAudience
                                                       triggerType: triggerContext.trigger.typeName
                                                       triggerEvent: triggerContext.event
                                                       triggerGoal: triggerContext.trigger.goal.doubleValue
                                                       completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppDeferredResult *) = obj;

        id mockResult = [self mockForClass:[UAInAppDeferredResult class]];
        [[[mockResult stub] andReturnValue:@YES] isSuccess];
        [[[mockResult stub] andReturnValue:@NO] timedOut];
        [[[mockResult stub] andReturnValue:@0] backOff];
        [[[mockResult stub] andReturn:deferredResult] responseBody];

        completionBlock(mockResult);
        return YES;
    }]];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockInAppMessageManager expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAInAppMessagePrepareResult);
        [invocation getArgument:&block atIndex:7];
        block(UAInAppMessagePrepareResultSuccess);
    }] prepareMessage:message scheduleID:@"schedule ID"
     campaigns:@{@"some": @"campaigns object"}
     reportingContext:@{}
     experimentResult:OCMOCK_ANY
     completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:triggerContext
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppCoreSwiftBridge verify];
    [self.mockInAppMessageManager verify];
}

- (void)testPrepareDeferredUnderLimit {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger
                                                                                             event:@"some event"];
    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:YES];


    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[trigger];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockInAppMessageManager expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAInAppMessagePrepareResult);
        [invocation getArgument:&block atIndex:7];
        block(UAInAppMessagePrepareResultSuccess);
    }] prepareMessage:message scheduleID:@"schedule ID" campaigns:@{@"some": @"campaigns object"} reportingContext:@{} experimentResult:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andReturnValue:@NO] isOverLimit];
    [[[mockChecker stub] andReturnValue:@YES] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    NSDictionary *deferredResult = @{
        @"audience_match": @YES,
        @"type": @"in_app_message",
        @"message": message.toJSON
    };

    [[self.mockInAppCoreSwiftBridge stub] resolveDeferredWithUrl: deferred.URL
                                                       channelID: @"channel ID"
                                                       audience: self.mockAudience
                                                       triggerType: triggerContext.trigger.typeName
                                                       triggerEvent: triggerContext.event
                                                       triggerGoal: triggerContext.trigger.goal.doubleValue
                                                       completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppDeferredResult *) = obj;

        id mockResult = [self mockForClass:[UAInAppDeferredResult class]];
        [[[mockResult stub] andReturnValue:@YES] isSuccess];
        [[[mockResult stub] andReturnValue:@NO] timedOut];
        [[[mockResult stub] andReturnValue:@0] backOff];
        [[[mockResult stub] andReturn:deferredResult] responseBody];

        completionBlock(mockResult);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:triggerContext
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppCoreSwiftBridge verify];
    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testPrepareDeferredOverLimit {
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];

    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger
                                                                                             event:@"some event"];
    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:YES];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[trigger];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager reject] prepareMessage:OCMOCK_ANY
                                               scheduleID:OCMOCK_ANY
                                                campaigns:OCMOCK_ANY
                                         reportingContext:OCMOCK_ANY
                                         experimentResult:OCMOCK_ANY
                                        completionHandler:OCMOCK_ANY];

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andReturnValue:@YES] isOverLimit];
    [[[mockChecker stub] andReturnValue:@NO] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[self.mockInAppCoreSwiftBridge reject] resolveDeferredWithUrl: OCMOCK_ANY
                                                         channelID: OCMOCK_ANY
                                                          audience: OCMOCK_ANY
                                                       triggerType: OCMOCK_ANY
                                                      triggerEvent: OCMOCK_ANY
                                                       triggerGoal: trigger.goal.doubleValue
                                                 completionHandler: OCMOCK_ANY];


    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:triggerContext
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppCoreSwiftBridge verify];
    [self.mockInAppMessageManager verify];
}

- (void)testPrepareDeferredTimedOut {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];
    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[self.mockInAppCoreSwiftBridge stub] resolveDeferredWithUrl: deferred.URL
                                                       channelID: @"channel ID"
                                                       audience: self.mockAudience
                                                       triggerType: nil
                                                       triggerEvent: nil
                                                       triggerGoal: 0
                                                       completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppDeferredResult *) = obj;

        id mockResult = [self mockForClass:[UAInAppDeferredResult class]];
        [[[mockResult stub] andReturnValue:@NO] isSuccess];
        [[[mockResult stub] andReturnValue:@YES] timedOut];
        completionBlock(mockResult);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:nil
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppCoreSwiftBridge verify];
}

- (void)testPrepareDeferredCodeBackOffZero {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];

    [[self.mockInAppCoreSwiftBridge stub] resolveDeferredWithUrl: deferred.URL
                                                       channelID: @"channel ID"
                                                       audience: self.mockAudience
                                                       triggerType: nil
                                                       triggerEvent: nil
                                                       triggerGoal: 0
                                                       completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppDeferredResult *) = obj;

        id mockResult = [self mockForClass:[UAInAppDeferredResult class]];
        [[[mockResult stub] andReturnValue:@NO] isSuccess];
        [[[mockResult stub] andReturnValue:@NO] timedOut];
        [[[mockResult stub] andReturnValue:@0] backOff];
        completionBlock(mockResult);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.inAppAutomation prepareDeferredSchedule:schedule audience:self.mockAudience triggerContext:nil experimentResult:nil retriableHandler:^(UARetriableResult result, NSTimeInterval time) {
        XCTAssertEqual(result, UARetriableResultRetryWithBackoffReset);
        XCTAssertEqual(time, 0);
        [prepareFinished fulfill];
    } completionHandler:^(UAAutomationSchedulePrepareResult result) {}];


    [self waitForTestExpectations];
    [self.mockInAppCoreSwiftBridge verify];
}

- (void)testPrepareDeferredCodeBackOff {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];

    [[self.mockInAppCoreSwiftBridge stub] resolveDeferredWithUrl: deferred.URL
                                                       channelID: @"channel ID"
                                                       audience: self.mockAudience
                                                       triggerType: nil
                                                       triggerEvent: nil
                                                       triggerGoal: 0
                                                       completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppDeferredResult *) = obj;

        id mockResult = [self mockForClass:[UAInAppDeferredResult class]];
        [[[mockResult stub] andReturnValue:@NO] isSuccess];
        [[[mockResult stub] andReturnValue:@NO] timedOut];
        [[[mockResult stub] andReturnValue:@100] backOff];
        completionBlock(mockResult);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.inAppAutomation prepareDeferredSchedule:schedule audience:self.mockAudience triggerContext:nil experimentResult:nil retriableHandler:^(UARetriableResult result, NSTimeInterval time) {
        XCTAssertEqual(result, UARetriableResultRetryAfter);
        XCTAssertEqual(time, 100);
        [prepareFinished fulfill];
    } completionHandler:^(UAAutomationSchedulePrepareResult result) {}];

    [self waitForTestExpectations];
    [self.mockInAppCoreSwiftBridge verify];
}


- (void)testPrepareDeferredCodeBackOffNoBackoff {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];

    [[self.mockInAppCoreSwiftBridge stub] resolveDeferredWithUrl: deferred.URL
                                                       channelID: @"channel ID"
                                                       audience: self.mockAudience
                                                       triggerType: nil
                                                       triggerEvent: nil
                                                       triggerGoal: 0
                                                       completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppDeferredResult *) = obj;

        id mockResult = [self mockForClass:[UAInAppDeferredResult class]];
        [[[mockResult stub] andReturnValue:@NO] isSuccess];
        [[[mockResult stub] andReturnValue:@NO] timedOut];
        [[[mockResult stub] andReturnValue:@-1] backOff];
        completionBlock(mockResult);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.inAppAutomation prepareDeferredSchedule:schedule audience:self.mockAudience triggerContext:nil experimentResult:nil retriableHandler:^(UARetriableResult result, NSTimeInterval time) {
        XCTAssertEqual(result, UARetriableResultRetry);
        XCTAssertEqual(time, 0);
        [prepareFinished fulfill];
    } completionHandler:^(UAAutomationSchedulePrepareResult result) {}];

    [self waitForTestExpectations];
    [self.mockInAppCoreSwiftBridge verify];
}

- (void)testPrepareDeferredAudienceMiss {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
            builder.missBehavior = UAScheduleAudienceMissBehaviorSkip;
        }];
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];



    NSDictionary *deferredResult = @{
        @"audience_match": @NO
    };

    [[self.mockInAppCoreSwiftBridge stub] resolveDeferredWithUrl: deferred.URL
                                                       channelID: @"channel ID"
                                                       audience: self.mockAudience
                                                       triggerType: nil
                                                       triggerEvent: nil
                                                       triggerGoal: 0
                                                       completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppDeferredResult *) = obj;

        id mockResult = [self mockForClass:[UAInAppDeferredResult class]];
        [[[mockResult stub] andReturnValue:@YES] isSuccess];
        [[[mockResult stub] andReturnValue:@NO] timedOut];
        [[[mockResult stub] andReturnValue:@0] backOff];
        [[[mockResult stub] andReturn:deferredResult] responseBody];

        completionBlock(mockResult);
        return YES;
    }]];


    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:nil
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppCoreSwiftBridge verify];
}

- (void)testPrepareDeferredNoMessage {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];
    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
            builder.missBehavior = UAScheduleAudienceMissBehaviorSkip;
        }];
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    NSDictionary *deferredResult = @{
        @"audience_match": @YES
    };

    [[self.mockInAppCoreSwiftBridge stub] resolveDeferredWithUrl: deferred.URL
                                                       channelID: @"channel ID"
                                                       audience: self.mockAudience
                                                       triggerType: nil
                                                       triggerEvent: nil
                                                       triggerGoal: 0
                                                       completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppDeferredResult *) = obj;

        id mockResult = [self mockForClass:[UAInAppDeferredResult class]];
        [[[mockResult stub] andReturnValue:@YES] isSuccess];
        [[[mockResult stub] andReturnValue:@NO] timedOut];
        [[[mockResult stub] andReturnValue:@0] backOff];
        [[[mockResult stub] andReturn:deferredResult] responseBody];

        completionBlock(mockResult);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:nil
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppCoreSwiftBridge verify];
}

- (void)testPrepareScheduleInvalid {
    UASchedule *schedule = [[UASchedule alloc] init];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] bestEffortRefresh:schedule completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultInvalidate, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepareAudienceCheckFailureDefaultMissBehavior {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
            builder.notificationsOptIn = @(YES);
        }];
        builder.bypassHoldoutGroups = YES;
        builder.isNewUserEvaluationDate = [NSDate date];
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    self.audienceMatch = NO;

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepareAudienceCheckFailureMissBehaviorCancel {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
            builder.notificationsOptIn = @(YES);
            builder.missBehavior = UAScheduleAudienceMissBehaviorCancel;
        }];
        builder.bypassHoldoutGroups = YES;
        builder.isNewUserEvaluationDate = [NSDate now];
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    self.audienceMatch = NO;

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultCancel, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepareAudienceCheckFailureMissBehaviorSkip {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
            builder.notificationsOptIn = @(YES);
            builder.missBehavior = UAScheduleAudienceMissBehaviorSkip;
        }];
        builder.bypassHoldoutGroups = YES;
        builder.isNewUserEvaluationDate = [NSDate now];
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.audienceMatch = NO;

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepareAudienceCheckFailureMissBehaviorPenalize {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
            builder.notificationsOptIn = @(YES);
            builder.missBehavior = UAScheduleAudienceMissBehaviorPenalize;
        }];
        builder.bypassHoldoutGroups = YES;
        builder.isNewUserEvaluationDate = [NSDate now];
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.audienceMatch = NO;

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testIsActionsReady {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];


    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);
}

- (void)testIsActionsReadyUnderLimit {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];


    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andReturnValue:@NO] isOverLimit];
    [[[mockChecker stub] andReturnValue:@YES] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);
    [self.mockFrequencyLimitManager verify];
}

- (void)testIsActionsReadyOverLimit {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block BOOL overLimit = NO;
    __block BOOL checkAndIncrement = YES;

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andDo:^(NSInvocation *invocation) {
        NSValue *result = [NSNumber numberWithBool:overLimit];
        [invocation setReturnValue:&result];
    }] isOverLimit];
    [[[mockChecker stub] andDo:^(NSInvocation *invocation) {
        NSValue *result = [NSNumber numberWithBool:checkAndIncrement];
        [invocation setReturnValue:&result];
    }] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    // Put checker over the limit
    overLimit = YES;
    checkAndIncrement = NO;
    
    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultSkip, result);
    [self.mockFrequencyLimitManager verify];
}

- (void)testIsMessageReady {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];


    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);
}

- (void)testIsMessageReadyDeferred {
    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:[UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                                                 retriableOnTimeout:YES]
                                                           builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];


    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);
}

- (void)testIsMessageNotReady {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];


    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultNotReady)] isReadyToDisplay:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultNotReady, result);
}

- (void)testIsMessageNotReadyDeferred {
    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:[UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                                                 retriableOnTimeout:YES]
                                                           builderBlock:^(UAScheduleBuilder * builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultNotReady)] isReadyToDisplay:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultNotReady, result);
}

- (void)testIsMessageReadyInvalid {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] isScheduleUpToDate:schedule completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] scheduleExecutionAborted:schedule.identifier];

    XCTestExpectation *precheckFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate isScheduleReadyPrecheck:schedule completionHandler:^(UAAutomationScheduleReadyResult result) {
        XCTAssertEqual(UAAutomationScheduleReadyResultInvalidate, result);
        [precheckFinished fulfill];
    }];

    [self waitForTestExpectations];

    [self.engineDelegate isScheduleReadyToExecute:schedule];
    [self.mockInAppMessageManager verify];
}

- (void)testIsReadyPaused {
    self.inAppAutomation.paused = YES;

    UASchedule *schedule = [[UASchedule alloc] init];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];
    XCTAssertEqual(UAAutomationScheduleReadyResultNotReady, result);
}

- (void)testIsMessageReadyUnderLimit {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.reportingContext = @{@"something": @"something"};
        builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andReturnValue:@NO] isOverLimit];
    [[[mockChecker stub] andReturnValue:@YES] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{@"something": @"something"}
                                         experimentResult:OCMOCK_ANY
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);

    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testIsMessageReadyOverLimit {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.bypassHoldoutGroups = YES;builder.bypassHoldoutGroups = YES;
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    __block BOOL overLimit = NO;
    __block BOOL checkAndIncrement = YES;

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andDo:^(NSInvocation *invocation) {
        NSValue *result = [NSNumber numberWithBool:overLimit];
        [invocation setReturnValue:&result];
    }] isOverLimit];
    [[[mockChecker stub] andDo:^(NSInvocation *invocation) {
        NSValue *result = [NSNumber numberWithBool:checkAndIncrement];
        [invocation setReturnValue:&result];
    }] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{}
                                         experimentResult:OCMOCK_ANY
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    // Put checker over the limit
    overLimit = YES;
    checkAndIncrement = NO;

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultSkip, result);

    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testIsMessageReadyUnderLimitDeferred {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                retriableOnTimeout:YES];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:[UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                                                 retriableOnTimeout:YES]
                                                           builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.bypassHoldoutGroups = YES;
    }];


    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger
                                                                                             event:@"some event"];


    NSDictionary *deferredResult = @{
        @"audience_match": @YES,
        @"type": @"in_app_message",
        @"message": message.toJSON
    };

    [[self.mockInAppCoreSwiftBridge stub] resolveDeferredWithUrl: deferred.URL
                                                       channelID: @"channel ID"
                                                       audience: self.mockAudience
                                                       triggerType: triggerContext.trigger.typeName
                                                       triggerEvent: triggerContext.event
                                                       triggerGoal: triggerContext.trigger.goal.doubleValue
                                                       completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppDeferredResult *) = obj;

        id mockResult = [self mockForClass:[UAInAppDeferredResult class]];
        [[[mockResult stub] andReturnValue:@YES] isSuccess];
        [[[mockResult stub] andReturnValue:@NO] timedOut];
        [[[mockResult stub] andReturnValue:@0] backOff];
        [[[mockResult stub] andReturn:deferredResult] responseBody];

        completionBlock(mockResult);
        return YES;
    }]];

    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andReturnValue:@NO] isOverLimit];
    [[[mockChecker stub] andReturnValue:@YES] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{}
                                         experimentResult:OCMOCK_ANY
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:triggerContext completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);

    [self.mockInAppCoreSwiftBridge verify];
    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testIsMessageReadyOverLimitDeferred {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                retriableOnTimeout:YES];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:[UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                                                 retriableOnTimeout:YES]
                                                           builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.bypassHoldoutGroups = YES;
    }];

    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger
                                                                                             event:@"some event"];

    NSDictionary *deferredResult = @{
        @"audience_match": @YES,
        @"type": @"in_app_message",
        @"message": message.toJSON
    };

    [[self.mockInAppCoreSwiftBridge stub] resolveDeferredWithUrl: deferred.URL
                                                       channelID: @"channel ID"
                                                       audience: self.mockAudience
                                                       triggerType: triggerContext.trigger.typeName
                                                       triggerEvent: triggerContext.event
                                                       triggerGoal: triggerContext.trigger.goal.doubleValue
                                                       completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppDeferredResult *) = obj;

        id mockResult = [self mockForClass:[UAInAppDeferredResult class]];
        [[[mockResult stub] andReturnValue:@YES] isSuccess];
        [[[mockResult stub] andReturnValue:@NO] timedOut];
        [[[mockResult stub] andReturnValue:@0] backOff];
        [[[mockResult stub] andReturn:deferredResult] responseBody];

        completionBlock(mockResult);
        return YES;
    }]];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];


    __block BOOL overLimit = NO;
    __block BOOL checkAndIncrement = YES;

    id mockChecker = [self mockForProtocol:@protocol(UAFrequencyChecker)];
    [[[mockChecker stub] andDo:^(NSInvocation *invocation) {
        NSValue *result = [NSNumber numberWithBool:overLimit];
        [invocation setReturnValue:&result];
    }] isOverLimit];
    [[[mockChecker stub] andDo:^(NSInvocation *invocation) {
        NSValue *result = [NSNumber numberWithBool:checkAndIncrement];
        [invocation setReturnValue:&result];
    }] checkAndIncrement];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(mockChecker, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{}
                                         experimentResult:OCMOCK_ANY
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:triggerContext completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    // Put checker over the limit
    overLimit = YES;
    checkAndIncrement = NO;

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultSkip, result);

    [self.mockInAppCoreSwiftBridge verify];
    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testExecuteMessage {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
        builder.productId = @"test-product-id";
    }];

    [[self.mockInAppMessageManager expect] displayMessageWithScheduleID:@"schedule ID" completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(void) = obj;
        completionBlock();
        return YES;
    }]];
    
    [[(id)self.mockInAppCoreSwiftBridge expect] addImpressionWithEntityID:@"schedule ID"
                                                                  product:@"test-product-id"
                                                                contactID:nil
                                                         reportingContext:schedule.reportingContext];

    XCTestExpectation *executeFinished = [self expectationWithDescription:@"execute finished"];
    [self.engineDelegate executeSchedule:schedule completionHandler:^{
        [executeFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppMessageManager verify];
    [(id)self.mockInAppCoreSwiftBridge verify];
}

- (void)testExecuteMessagePassContactIdToImpression {

    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.productId = @"test-product-id";
    }];

    id mockInfo = [self mockForClass:[UARemoteDataInfo class]];
    [[[mockInfo stub] andReturn:@"test-contact-id"] contactID];
    [[[self.mockRemoteDataClient stub] andReturn:mockInfo] remoteDataInfoFromSchedule:schedule];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    [[self.mockAudience stub] evaluateExperimentsWithInfo:OCMOCK_ANY
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^complemtion)(UAExperimentResult * _Nullable, NSError * _Nullable) = obj;
        complemtion(nil, nil);
        return YES;
    }]];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:schedule.identifier
                                                campaigns:schedule.campaigns
                                         reportingContext:schedule.reportingContext
                                         experimentResult:nil
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                                void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
                                                completionBlock(UAInAppMessagePrepareResultSuccess);
                                                return YES;
                                            }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    [[self.mockInAppMessageManager expect] displayMessageWithScheduleID:@"schedule ID" completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(void) = obj;
        completionBlock();
        return YES;
    }]];
    
    [[(id)self.mockInAppCoreSwiftBridge expect] addImpressionWithEntityID:@"schedule ID"
                                                      product:@"test-product-id"
                                                    contactID:@"test-contact-id"
                                             reportingContext:schedule.reportingContext];

    XCTestExpectation *executeFinished = [self expectationWithDescription:@"execute finished"];
    [self.engineDelegate executeSchedule:schedule completionHandler:^{
        [executeFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppMessageManager verify];
    [(id)self.mockInAppCoreSwiftBridge verify];
}

- (void)testExecuteMessageNotCallingIfNoProductId {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];


    [[self.mockInAppMessageManager expect] displayMessageWithScheduleID:@"schedule ID" completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(void) = obj;
        completionBlock();
        return YES;
    }]];
    
    [[(id)self.mockInAppCoreSwiftBridge reject] addImpressionWithEntityID:[OCMArg any] product:[OCMArg any] contactID:[OCMArg any] reportingContext:[OCMArg any]];

    XCTestExpectation *executeFinished = [self expectationWithDescription:@"execute finished"];
    [self.engineDelegate executeSchedule:schedule completionHandler:^{
        [executeFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppMessageManager verify];
    [(id)self.mockInAppCoreSwiftBridge verify];
}

- (void)testExecuteDeferred {
    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:[UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                                                 retriableOnTimeout:YES]
                                                           builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.bypassHoldoutGroups = YES;
    }];

    [[self.mockInAppMessageManager expect] displayMessageWithScheduleID:@"schedule ID" completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(void) = obj;
        completionBlock();
        return YES;
    }]];

    XCTestExpectation *executeFinished = [self expectationWithDescription:@"execute finished"];
    [self.engineDelegate executeSchedule:schedule completionHandler:^{
        [executeFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppMessageManager verify];
}
/*
- (void)testExecuteActions {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{@"foo": @"bar"} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    id mockActionRunner = [self mockForClass:[UAActionRunner class]];
    [[mockActionRunner expect] runActionsWithActionValues:schedule.data
                                                situation:UAActionSituationAutomation
                                                 metadata:[OCMArg any]
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UAActionResult *) = obj;
        handler([UAActionResult emptyResult]);
        return YES;
    }]];


    XCTestExpectation *executeFinished = [self expectationWithDescription:@"execute finished"];
    [self.engineDelegate executeSchedule:schedule completionHandler:^{
        [executeFinished fulfill];
    }];

    [self waitForTestExpectations];
    [mockActionRunner verify];
}
*/
- (void)testCancelScheduleWithID {
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] cancelScheduleWithID:@"some ID" completionHandler:OCMOCK_ANY];

    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation cancelScheduleWithID:@"some ID" completionHandler:^(BOOL cancelled) {
        XCTAssertTrue(cancelled);
        [blockInvoked fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testCancelScheduleWithGroup {
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] cancelSchedulesWithGroup:@"some group" completionHandler:OCMOCK_ANY];

    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation cancelSchedulesWithGroup:@"some group" completionHandler:^(BOOL cancelled) {
        XCTAssertTrue(cancelled);
        [blockInvoked fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testCancelMessageSchedulesWithGroup {
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] cancelSchedulesWithGroup:@"some group" type:UAScheduleTypeInAppMessage completionHandler:OCMOCK_ANY];

    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation cancelMessageSchedulesWithGroup:@"some group" completionHandler:^(BOOL cancelled) {
        XCTAssertTrue(cancelled);
        [blockInvoked fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testCancelActionSchedulesWithGroup {
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] cancelSchedulesWithGroup:@"some group" type:UAScheduleTypeActions completionHandler:OCMOCK_ANY];

    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation cancelActionSchedulesWithGroup:@"some group" completionHandler:^(BOOL cancelled) {
        XCTAssertTrue(cancelled);
        [blockInvoked fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testSchedule {
    UASchedule *schedule = [[UASchedule alloc] init];

    // expectations
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;

        if (completionHandler) {
            completionHandler(YES);
        }
    }] schedule:schedule completionHandler:OCMOCK_ANY];

    // test
    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation schedule:schedule completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [blockInvoked fulfill];
    }];

    // verify
    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testScheduleMultiple {
    UASchedule *scheduleOne = [[UASchedule alloc] init];
    UASchedule *scheduleTwo = [[UASchedule alloc] init];


    // expectations
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;

        if (completionHandler) {
            completionHandler(YES);
        }
    }] scheduleMultiple:@[scheduleOne, scheduleTwo] completionHandler:OCMOCK_ANY];

    // test
    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation scheduleMultiple:@[scheduleOne, scheduleTwo] completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
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
    [(UAAutomationEngine *)[self.mockAutomationEngine expect] resume];
    self.inAppAutomation.componentEnabled = YES;

    // verify
    XCTAssertTrue(self.inAppAutomation.componentEnabled);
    [self.mockAutomationEngine verify];
}

- (void)testPrivacyManager {
    [self.inAppAutomation airshipReady];

    // test disable
    [[self.mockAutomationEngine expect] pause];
    [[self.mockRemoteDataClient expect] unsubscribe];

    self.privacyManager.enabledFeatures = UAFeaturesNone;

    [self.mockAutomationEngine verify];
    [self.mockRemoteDataClient verify];

    // test enable
    [(UAAutomationEngine *) [self.mockAutomationEngine expect] resume];
    [[self.mockRemoteDataClient expect] subscribe];

    self.privacyManager.enabledFeatures = UAFeaturesInAppAutomation;

    [self.mockAutomationEngine verify];
    [self.mockRemoteDataClient verify];
}

#pragma mark - Schedule with Holdout Group

- (void)testExperimentResultsSentToInAppMessageManagerPrepare {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.messageType = @"some-type";
        builder.campaigns = @{@"some": @"campaigns object"};
    }];

    id mockInfo = [self mockForClass:[UARemoteDataInfo class]];
    [[[self.mockRemoteDataClient stub] andReturn:mockInfo] remoteDataInfoFromSchedule:schedule];

    UAExperimentResult *experimentResult = [[UAExperimentResult alloc] initWithChannelId:@"channel-id"
                                                                               contactId:@"contact-id"
                                                                            isMatch:YES
                                                                       reportingMetadata:@[@{}]];

    UAExperimentMessageInfo *expectedInfo = [[UAExperimentMessageInfo alloc] initWithMessageType:@"some-type" campaignsJSON:schedule.campaigns];

    [[(id)self.mockAudience expect] evaluateExperimentsWithInfo:[OCMArg isEqual:expectedInfo]
                                              completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^complemtion)(UAExperimentResult * _Nullable, NSError * _Nullable) = obj;
        complemtion(experimentResult, nil);
        return YES;
    }]];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:schedule.identifier
                                                campaigns:schedule.campaigns
                                         reportingContext:schedule.reportingContext
                                         experimentResult:experimentResult
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
                                                void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
                                                completionBlock(UAInAppMessagePrepareResultSuccess);
                                                return YES;
                                            }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    [(id)self.mockInAppCoreSwiftBridge verify];
}

- (void)testScheduledMessageCallHoldoutGroupRespectBypassFlag {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.messageType = @"some-type";
        builder.bypassHoldoutGroups = YES;
        builder.campaigns = @{@"some": @"campaigns object"};
    }];

    id mockInfo = [self mockForClass:[UARemoteDataInfo class]];
    [[[self.mockRemoteDataClient stub] andReturn:mockInfo] remoteDataInfoFromSchedule:schedule];

    [[(id)self.mockAudience reject] evaluateExperimentsWithInfo:OCMOCK_ANY
                                              completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:OCMOCK_ANY
                                         reportingContext:OCMOCK_ANY
                                         experimentResult:OCMOCK_ANY
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    [(id)self.mockInAppCoreSwiftBridge verify];
    [self.mockInAppMessageManager verify];
}

- (void)testScheduledMessageDefaultsToTransactionalIfNoMessageType {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.messageType = nil;
        builder.bypassHoldoutGroups = NO;
        builder.campaigns = @{@"some": @"campaigns object"};
    }];

    id mockInfo = [self mockForClass:[UARemoteDataInfo class]];
    [[[self.mockRemoteDataClient stub] andReturn:mockInfo] remoteDataInfoFromSchedule:schedule];

    UAExperimentMessageInfo *expectedInfo = [[UAExperimentMessageInfo alloc] initWithMessageType:@"transactional" campaignsJSON:schedule.campaigns];

    UAExperimentResult *experimentResult = [[UAExperimentResult alloc] initWithChannelId:@"channel-id"
                                                                               contactId:@"contact-id"
                                                                            isMatch:YES
                                                                       reportingMetadata:@[@{}]];

    [[(id)self.mockAudience expect] evaluateExperimentsWithInfo:[OCMArg isEqual:expectedInfo]
                                                  completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^complemtion)(UAExperimentResult * _Nullable, NSError * _Nullable) = obj;
        complemtion(experimentResult, nil);
        return YES;
    }]];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] scheduleRequiresRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] bestEffortRefresh:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(id<UAFrequencyChecker>, NSError *) = (__bridge void (^)(id<UAFrequencyChecker>, NSError *))arg;
        callback(nil, nil);
    }] getFrequencyCheckerWithConstraintIDs:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:OCMOCK_ANY
                                         reportingContext:OCMOCK_ANY
                                         experimentResult:experimentResult
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    [(id)self.mockAudience verify];
    [self.mockInAppMessageManager verify];
}


@end
