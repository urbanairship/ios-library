/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"

#import "UAirship+Internal.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageCustomDisplayContent+Internal.h"
#import "UAActionRunner.h"
#import "UATestDispatcher.h"
#import "UAInAppMessageDefaultDisplayCoordinator+Internal.h"
#import "UAInAppMessageAssetManager+Internal.h"
#import "UAInAppMessageAssetCache+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "NSObject+UAAdditions.h"

NSString * const UAInAppMessageManagerTestScheduleID = @"schedule ID";

@interface UAInAppMessageManagerTest : UAAirshipBaseTest
@property(nonatomic, strong) UAInAppMessageManager *manager;
@property(nonatomic, strong) UAInAppMessage *message;
@property(nonatomic, strong) UATestDispatcher *testDispatcher;

@property(nonatomic, strong) id mockDelegate;
@property(nonatomic, strong) id mockAdapter;
@property(nonatomic, strong) id mockActionRunner;
@property(nonatomic, strong) id mockDefaultDisplayCoordinator;
@property(nonatomic, strong) id mockDelegatedDisplayCoordinator;
@property(nonatomic, strong) id mockAssetManager;
@property(nonatomic, strong) id mockAssetCache;
@property(nonatomic, strong) id mockAssets;
@property(nonatomic, strong) id mockAnalytics;

@end

@implementation UAInAppMessageManagerTest

- (void)setUp {
    [super setUp];

    self.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.actions = @{@"cool": @"story"};
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    self.mockDelegate = [self mockForProtocol:@protocol(UAInAppMessagingDelegate)];
    self.mockAdapter = [self mockForProtocol:@protocol(UAInAppMessageAdapterProtocol)];

    self.mockActionRunner = [self mockForClass:[UAActionRunner class]];
    self.testDispatcher = [UATestDispatcher testDispatcher];
    self.mockDefaultDisplayCoordinator = [self mockForClass:[UAInAppMessageDefaultDisplayCoordinator class]];

    // Note: KVO fails for protocol mocks
    self.mockDelegatedDisplayCoordinator = [self mockForClass:[UAInAppMessageDefaultDisplayCoordinator class]];

    self.mockAssetManager = [self mockForClass:[UAInAppMessageAssetManager class]];
    self.mockAssetCache = [self mockForClass:[UAInAppMessageAssetCache class]];
    self.mockAssets = [self mockForClass:[UAInAppMessageAssets class]];
    self.mockAnalytics = [self mockForClass:[UAAnalytics class]];

    self.manager = [UAInAppMessageManager managerWithDataStore:self.dataStore
                                                     analytics:self.mockAnalytics
                                                    dispatcher:self.testDispatcher
                                            displayCoordinator:self.mockDefaultDisplayCoordinator
                                                  assetManager:self.mockAssetManager];

    self.manager.delegate = self.mockDelegate;

    UA_WEAKIFY(self)
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        UA_STRONGIFY(self)
        return self.mockAdapter;
    } forDisplayType:UAInAppMessageDisplayTypeCustom];
}

- (void)testPrepare {
    UA_WEAKIFY(self)
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        UA_STRONGIFY(self)
        return self.mockAdapter;
    } forDisplayType:UAInAppMessageDisplayTypeCustom];

    XCTestExpectation *adapterPrepareCalled = [self expectationWithDescription:@"adapter prepare should be called"];
    [[[self.mockAdapter expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:3];
        prepareBlock(UAInAppMessagePrepareResultSuccess);
        [adapterPrepareCalled fulfill];
    }] prepareWithAssets:self.mockAssets completionHandler:OCMOCK_ANY];

    [[[self.mockDelegate expect] andReturn:self.message] extendMessage:self.message];

    XCTestExpectation *assetManagerPrepareCalled = [self expectationWithDescription:@"asset manager prepare should be called"];
    [[[self.mockAssetManager expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:4];
        prepareBlock(UAInAppMessagePrepareResultSuccess);
        [assetManagerPrepareCalled fulfill];
    }] onPrepareMessage:self.message scheduleID:UAInAppMessageManagerTestScheduleID completionHandler:OCMOCK_ANY];

    XCTestExpectation *assetManagerAssetsForScheduleCalled = [self expectationWithDescription:@"asset manager assetsForSchedule should be called"];
    [[[self.mockAssetManager expect] andDo:^(NSInvocation *invocation) {
        void (^completionBlock)(UAInAppMessageAssets *);
        [invocation getArgument:&completionBlock atIndex:3];
        completionBlock(self.mockAssets);
        [assetManagerAssetsForScheduleCalled fulfill];
    }] assetsForScheduleID:UAInAppMessageManagerTestScheduleID completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare should be finished"];
    [self.manager prepareMessage:self.message scheduleID:UAInAppMessageManagerTestScheduleID completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAdapter verify];
    [self.mockDelegate verify];
    [self.mockAssetManager verify];
    [self.mockAssetCache verify];
}

- (void)testPrepareExtendMessageFailed {
    UA_WEAKIFY(self)
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        UA_STRONGIFY(self)
        return self.mockAdapter;
    } forDisplayType:UAInAppMessageDisplayTypeCustom];

    [[[self.mockDelegate expect] andReturn:nil] extendMessage:self.message];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare should be finished"];
    [self.manager prepareMessage:self.message scheduleID:UAInAppMessageManagerTestScheduleID completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    [self.mockAdapter verify];
    [self.mockDelegate verify];
}

- (void)testPrepareCancel {
    UA_WEAKIFY(self)
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        UA_STRONGIFY(self)
        return self.mockAdapter;
    } forDisplayType:UAInAppMessageDisplayTypeCustom];

    XCTestExpectation *adapterPrepareCalled = [self expectationWithDescription:@"adapter prepare should be called"];
    [[[self.mockAdapter expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:3];
        prepareBlock(UAInAppMessagePrepareResultCancel);
        [adapterPrepareCalled fulfill];
    }] prepareWithAssets:self.mockAssets completionHandler:OCMOCK_ANY];

    [[[self.mockDelegate expect] andReturn:self.message] extendMessage:self.message];

    XCTestExpectation *assetManagerPrepareCalled = [self expectationWithDescription:@"asset manager prepare should be called"];
    [[[self.mockAssetManager expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:4];
        prepareBlock(UAInAppMessagePrepareResultSuccess);
        [assetManagerPrepareCalled fulfill];
    }] onPrepareMessage:self.message scheduleID:UAInAppMessageManagerTestScheduleID completionHandler:OCMOCK_ANY];


    XCTestExpectation *assetManagerAssetsForScheduleCalled = [self expectationWithDescription:@"asset manager assetsForSchedule should be called"];
    [[[self.mockAssetManager expect] andDo:^(NSInvocation *invocation) {
        void (^completionBlock)(UAInAppMessageAssets *);
        [invocation getArgument:&completionBlock atIndex:3];
        completionBlock(self.mockAssets);
        [assetManagerAssetsForScheduleCalled fulfill];
    }] assetsForScheduleID:UAInAppMessageManagerTestScheduleID completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare should be finished"];
    [self.manager prepareMessage:self.message scheduleID:UAInAppMessageManagerTestScheduleID completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultCancel, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAdapter verify];
    [self.mockDelegate verify];
    [self.mockAssetManager verify];
    [self.mockAssetCache verify];
}

- (void)testPrepareNoFactory {
    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare should be finished"];
    [self.manager prepareMessage:self.message scheduleID:UAInAppMessageManagerTestScheduleID completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepareNilAdapter {
    [self.manager setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
        return nil;
    } forDisplayType:UAInAppMessageDisplayTypeCustom];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare should be finished"];
    [self.manager prepareMessage:self.message scheduleID:UAInAppMessageManagerTestScheduleID completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testDisplay {
    // Prepare first
    [self testPrepare];

    // Execute
    [[[self.mockDefaultDisplayCoordinator stub] andReturnValue:@(YES)] isReady];
    [[[self.mockAdapter stub] andReturnValue:@(YES)] isReadyToDisplay];
    [[self.mockAnalytics expect] addEvent:OCMOCK_ANY];

    // Display
    XCTestExpectation *displayBlockCalled = [self expectationWithDescription:@"display block should be called"];
    [[[self.mockAdapter expect] andDo:^(NSInvocation *invocation) {
        void (^displayBlock)(UAInAppMessageResolution *);
        [invocation getArgument:&displayBlock atIndex:2];
        displayBlock([UAInAppMessageResolution userDismissedResolution]);
        [displayBlockCalled fulfill];
    }] display:OCMOCK_ANY];

    [[self.mockActionRunner expect] runActionsWithActionValues:self.message.actions
                                                     situation:UASituationManualInvocation
                                                      metadata:nil
                                             completionHandler:OCMOCK_ANY];

    [[self.mockDelegate expect] messageWillBeDisplayed:self.message scheduleID:UAInAppMessageManagerTestScheduleID];
    [[self.mockDelegate expect] messageFinishedDisplaying:self.message scheduleID:UAInAppMessageManagerTestScheduleID resolution:OCMOCK_ANY];

    XCTestExpectation *executeFinished = [self expectationWithDescription:@"execute finished"];
    [self.manager displayMessageWithScheduleID:UAInAppMessageManagerTestScheduleID completionHandler:^{
        [executeFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAdapter verify];
    [self.mockAnalytics verify];
    [self.mockDelegate verify];
    [self.mockActionRunner verify];
}

- (void)testDisplayInterval {
    [[self.mockDefaultDisplayCoordinator expect] setDisplayInterval:100];
    self.manager.displayInterval = 100;
    [self.mockDefaultDisplayCoordinator verify];
}

- (void)testIsReadyToDisplay {
    [self testPrepare];

    [[[self.mockAdapter stub] andReturnValue:@(YES)] isReadyToDisplay];
    [[[self.mockDefaultDisplayCoordinator stub] andReturnValue:@(YES)] isReady];
    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, [self.manager isReadyToDisplay:UAInAppMessageManagerTestScheduleID]);
}

- (void)testIsReadyToDisplayInvalid {
    XCTAssertEqual(UAAutomationScheduleReadyResultInvalidate, [self.manager isReadyToDisplay:UAInAppMessageManagerTestScheduleID]);
}

- (void)testIsReadyToDisplayCoordinatorNotReady {
    [self testPrepare];

    [[[self.mockAdapter stub] andReturnValue:@(YES)] isReadyToDisplay];
    [[[self.mockDefaultDisplayCoordinator stub] andReturnValue:@(NO)] isReady];
    XCTAssertEqual(UAAutomationScheduleReadyResultNotReady, [self.manager isReadyToDisplay:UAInAppMessageManagerTestScheduleID]);
}

- (void)testIsReadyToDisplayAdapterNotReady {
    [self testPrepare];

    [[[self.mockAdapter stub] andReturnValue:@(NO)] isReadyToDisplay];
    [[[self.mockDefaultDisplayCoordinator stub] andReturnValue:@(YES)] isReady];
    XCTAssertEqual(UAAutomationScheduleReadyResultNotReady, [self.manager isReadyToDisplay:UAInAppMessageManagerTestScheduleID]);
}

@end
