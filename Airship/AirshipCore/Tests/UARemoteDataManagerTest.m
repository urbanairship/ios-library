/* Copyright Airship and Contributors */

#import "UARemoteDataManager+Internal.h"

#import "UARemoteDataPayload+Internal.h"
#import "UARemoteDataStore+Internal.h"
#import "UAAirshipBaseTest.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

typedef void (^UARemoteDataAPIClientCompletionHandler)(UARemoteDataResponse * _Nullable response, NSError * _Nullable error);

/**
 * Used to test what UARemoteDataManager does when the cache fails underneath it.
 */

static NSString * const RefreshTask = @"UARemoteDataManager.refresh";

@interface UARemoteDataManagerTest : UAAirshipBaseTest

@property (nonatomic, strong) id mockAPIClient;
@property (nonatomic, strong) id mockLocaleManager;
@property (nonatomic, strong) id mockTaskManager;

@property (nonatomic, strong) UARemoteDataManager *remoteDataManager;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, strong) UARemoteDataStore *testStore;
@property (nonatomic, strong) UATestAppStateTracker *testAppStateTracker;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;

@property (nonatomic, copy) void (^launchHandler)(id<UATask>);
@property (nonatomic, strong) UATestDate *testDate;
@property (nonatomic, copy) NSArray<NSDictionary *> *remoteDataFromCloud;
@property (nonatomic, strong) NSString *locale;
@property (nonatomic, strong) NSURL *requestURL;

@end

@implementation UARemoteDataManagerTest

- (void)setUp {
    [super setUp];

    self.mockAPIClient = [self mockForClass:[UARemoteDataAPIClient class]];
    self.requestURL = [NSURL URLWithString:@"some-url"];
    [[[self.mockAPIClient stub] andDo:^(NSInvocation *invocation) {
        id result = self.requestURL;
        [invocation setReturnValue:(void *)&result];
    }] remoteDataURLWithLocale:OCMOCK_ANY];

    self.testStore = [UARemoteDataStore storeWithName:[NSUUID UUID].UUIDString inMemory:YES];
    self.testDate = [[UATestDate alloc] initWithOffset:0 dateOverride:[NSDate date]];
    self.notificationCenter = [[NSNotificationCenter alloc] init];

    self.locale = @"en-US";
    self.mockLocaleManager = [self mockForClass:[UALocaleManager class]];
    [[[self.mockLocaleManager stub] andDo:^(NSInvocation *invocation) {
        id result = [NSLocale localeWithLocaleIdentifier:self.locale];
        [invocation setReturnValue:(void *)&result];
    }] currentLocale];

    self.mockTaskManager = [self mockForClass:[UATaskManager class]];
    // Capture the task launcher
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^launcher)(id<UATask>) =  (__bridge void (^)(id<UATask>))arg;

        [invocation getArgument:&arg atIndex:3];
        UADispatcher *dispatcher = (__bridge UADispatcher *)arg;

        self.launchHandler = ^(id<UATask> task) {
            [dispatcher dispatchAsync:^{
                launcher(task);
            }];
        };
    }] registerForTaskWithID:RefreshTask dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];


    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];
    self.testAppStateTracker = [[UATestAppStateTracker alloc] init];
    self.testAppStateTracker.currentState = UAApplicationStateActive;
    self.remoteDataManager = [self createManager];
}

- (void)tearDown {
    [self.testStore shutDown];
    [super tearDown];
}

- (void)testForegroundRefresh {
    [[self.mockTaskManager expect] enqueueRequestWithID:RefreshTask options:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];

    [self.mockTaskManager verify];
}

- (void)testRemoteConfigUpdated {
    [[self.mockTaskManager expect] enqueueRequestWithID:RefreshTask options:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UARuntimeConfig.configUpdatedEvent object:nil];

    [self.mockTaskManager verify];
}

- (void)testCheckRefresh {
    // Set initial metadata
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    [self updatePayloads:payloads];

    self.remoteDataManager.remoteDataRefreshInterval = 100;

    __block NSUInteger count = 0;
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        count++;
    }] enqueueRequestWithID:RefreshTask options:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(0, count);

    // Refresh interval
    self.testDate.offset += 100;
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(1, count);
}

- (void)testCheckRefreshAppVersionChanages {
    self.remoteDataManager.remoteDataRefreshInterval = 1000;

    // Set initial metadata
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    [self updatePayloads:payloads];

    __block NSUInteger count = 0;

    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        count++;
    }] enqueueRequestWithID:RefreshTask options:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(0, count);

    // change app version
    id mockedBundle = [self mockForClass:[NSBundle class]];
    [[[mockedBundle stub] andReturn:mockedBundle] mainBundle];
    [[[mockedBundle stub] andReturn:@{@"CFBundleShortVersionString": @"1.1.1"}] infoDictionary];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(1, count);
}

- (void)testCheckRefreshMetadataChanages {
    self.remoteDataManager.remoteDataRefreshInterval = 1000;

    // Set initial metadata
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    [self updatePayloads:payloads];

    __block NSUInteger count = 0;
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        count++;
    }] enqueueRequestWithID:RefreshTask options:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(0, count);

    // change URL
    self.requestURL = [NSURL URLWithString:@"some-other-url"];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(1, count);
}

- (void)testLocaleChangeRefresh {
    [[self.mockTaskManager expect] enqueueRequestWithID:RefreshTask options:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UALocaleManager.localeUpdatedEvent object:nil];

    [self.mockTaskManager verify];
}

- (void)testContentAvailableRefresh {
    [[self.mockTaskManager expect] enqueueRequestWithID:RefreshTask options:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];

    [((NSObject<UAPushableComponent> *)self.remoteDataManager) receivedRemoteNotification:@{
        @"com.urbanairship.remote-data.update": @(true)
    } completionHandler:^(UIBackgroundFetchResult result) {
        XCTAssertEqual(UAActionFetchResultNewData, result);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockTaskManager verify];
}

- (void)testRefreshRemoteData {
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    UARemoteDataResponse *response = [[UARemoteDataResponse alloc] initWithStatus:200
                                                                       requestURL:self.requestURL
                                                                         payloads:payloads
                                                                     lastModified:@"2018-01-01T12:00:00"];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARemoteDataAPIClientCompletionHandler completionHandler = (__bridge UARemoteDataAPIClientCompletionHandler) arg;
        completionHandler(response, nil);
    }] fetchRemoteDataWithLocale:OCMOCK_ANY lastModified:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Task finished"];
    [[[mockTask expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] taskCompleted];

    self.launchHandler(mockTask);

    [self waitForTestExpectations];

    [self.mockAPIClient verify];
    [mockTask verify];
}

- (void)testRefreshRemoteData304 {
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    UARemoteDataResponse *response = [[UARemoteDataResponse alloc] initWithStatus:200
                                                                       requestURL:self.requestURL
                                                                         payloads:payloads
                                                                     lastModified:@"2018-01-01T12:00:00"];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARemoteDataAPIClientCompletionHandler completionHandler = (__bridge UARemoteDataAPIClientCompletionHandler) arg;
        completionHandler(response, nil);
    }] fetchRemoteDataWithLocale:OCMOCK_ANY lastModified:nil completionHandler:OCMOCK_ANY];


    UARemoteDataResponse *updateResponse = [[UARemoteDataResponse alloc] initWithStatus:304
                                                                             requestURL:self.requestURL
                                                                               payloads:nil
                                                                           lastModified:nil];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARemoteDataAPIClientCompletionHandler completionHandler = (__bridge UARemoteDataAPIClientCompletionHandler) arg;
        completionHandler(updateResponse, nil);
    }] fetchRemoteDataWithLocale:OCMOCK_ANY lastModified:@"2018-01-01T12:00:00" completionHandler:OCMOCK_ANY];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    XCTestExpectation *firstTask = [self expectationWithDescription:@"Task finished"];
    [[[mockTask expect] andDo:^(NSInvocation *invocation) {
        [firstTask fulfill];
    }] taskCompleted];

    self.launchHandler(mockTask);

    XCTestExpectation *secontTask = [self expectationWithDescription:@"Task finished"];
    [[[mockTask expect] andDo:^(NSInvocation *invocation) {
        [secontTask fulfill];
    }] taskCompleted];

    self.launchHandler(mockTask);

    [self waitForTestExpectations];

    [self.mockAPIClient verify];
    [mockTask verify];
}

- (void)testRefreshRemoteDataClientError {
    UARemoteDataResponse *response = [[UARemoteDataResponse alloc] initWithStatus:400
                                                                       requestURL:self.requestURL
                                                                         payloads:nil
                                                                     lastModified:nil];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARemoteDataAPIClientCompletionHandler completionHandler = (__bridge UARemoteDataAPIClientCompletionHandler) arg;
        completionHandler(response, nil);
    }] fetchRemoteDataWithLocale:OCMOCK_ANY lastModified:nil completionHandler:OCMOCK_ANY];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    XCTestExpectation *firstTask = [self expectationWithDescription:@"Task finished"];
    [[[mockTask expect] andDo:^(NSInvocation *invocation) {
        [firstTask fulfill];
    }] taskCompleted];

    self.launchHandler(mockTask);

    [self waitForTestExpectations];

    [self.mockAPIClient verify];
    [mockTask verify];
}

- (void)testRefreshRemoteDataServerError {
    UARemoteDataResponse *response = [[UARemoteDataResponse alloc] initWithStatus:500
                                                                       requestURL:self.requestURL
                                                                         payloads:nil
                                                                     lastModified:nil];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARemoteDataAPIClientCompletionHandler completionHandler = (__bridge UARemoteDataAPIClientCompletionHandler) arg;
        completionHandler(response, nil);
    }] fetchRemoteDataWithLocale:OCMOCK_ANY lastModified:nil completionHandler:OCMOCK_ANY];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    XCTestExpectation *firstTask = [self expectationWithDescription:@"Task finished"];
    [[[mockTask expect] andDo:^(NSInvocation *invocation) {
        [firstTask fulfill];
    }] taskFailed];

    self.launchHandler(mockTask);

    [self waitForTestExpectations];

    [self.mockAPIClient verify];
    [mockTask verify];
}

- (void)testRefreshLastModifiedMetadataChanges {
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    UARemoteDataResponse *response = [[UARemoteDataResponse alloc] initWithStatus:200
                                                                       requestURL:self.requestURL
                                                                         payloads:payloads
                                                                     lastModified:@"2018-01-01T12:00:00"];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARemoteDataAPIClientCompletionHandler completionHandler = (__bridge UARemoteDataAPIClientCompletionHandler) arg;
        completionHandler(response, nil);
    }] fetchRemoteDataWithLocale:OCMOCK_ANY lastModified:nil completionHandler:OCMOCK_ANY];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    XCTestExpectation *firstTask = [self expectationWithDescription:@"Task finished"];
    [[[mockTask expect] andDo:^(NSInvocation *invocation) {
        [firstTask fulfill];
    }] taskCompleted];

    self.launchHandler(mockTask);

    [self waitForTestExpectations];

    // change return URL
    self.requestURL = [NSURL URLWithString:@"some-other-url"];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARemoteDataAPIClientCompletionHandler completionHandler = (__bridge UARemoteDataAPIClientCompletionHandler) arg;
        completionHandler(response, nil);
    }] fetchRemoteDataWithLocale:OCMOCK_ANY lastModified:nil completionHandler:OCMOCK_ANY];

    XCTestExpectation *secontTask = [self expectationWithDescription:@"Task finished"];
    [[[mockTask expect] andDo:^(NSInvocation *invocation) {
        [secontTask fulfill];
    }] taskCompleted];

    self.launchHandler(mockTask);

    [self waitForTestExpectations];

    [self.mockAPIClient verify];
    [mockTask verify];
}

- (void)testRefreshError {
    id error = [self mockForClass:[NSError class]];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARemoteDataAPIClientCompletionHandler completionHandler = (__bridge UARemoteDataAPIClientCompletionHandler) arg;
        completionHandler(nil, error);
    }] fetchRemoteDataWithLocale:OCMOCK_ANY lastModified:nil completionHandler:OCMOCK_ANY];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Task finished"];
    [[[mockTask expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] taskFailed];

    self.launchHandler(mockTask);

    [self waitForTestExpectations];
    [self.mockAPIClient verify];
    [mockTask verify];
}

- (void)testMetadata {
    id expectedMetadata = @{
        @"url": self.requestURL.absoluteString
    };

    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    [self updatePayloads:payloads];

    __block id metadata;
    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"Callback called"];
    [self.remoteDataManager subscribeWithTypes:@[@"test"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        metadata = remoteDataArray[0].metadata;
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertEqualObjects(expectedMetadata, metadata);
}

- (void)testSubscribe {
    NSArray *payloads = @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];

    [self updatePayloads:payloads];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"Callback called"];
    __block NSArray *remoteData = nil;

    [self.remoteDataManager subscribeWithTypes:@[@"test"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        remoteData = remoteDataArray;
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertEqual(1, remoteData.count);
    UARemoteDataPayload *payload = remoteData[0];
    XCTAssertEqualObjects(payloads[0][@"data"], payload.data);
    XCTAssertEqualObjects(@"test", payload.type);
}

- (void)testUnsubscribe {
    NSArray *payloads = @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];

    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:@[@"test"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        XCTFail(@"Should never get any data");
    }];
    [subscription dispose];
    [self updatePayloads:payloads];
}

- (void)testSubscriptionUpdates {
    NSArray *payloads = @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    NSArray *update = @[@{ @"type": @"test", @"timestamp":@"2018-01-01T12:00:00", @"data": @{ @"super": @"cool" }}];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"Callback called"];
    callbackCalled.expectedFulfillmentCount = 3;
    NSMutableArray *responses = [NSMutableArray array];
    [self.remoteDataManager subscribeWithTypes:@[@"test"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        [responses addObject:remoteDataArray];
        [callbackCalled fulfill];
    }];

    [self updatePayloads:payloads];
    [self updatePayloads:update];

    [self waitForTestExpectations];

    XCTAssertEqual(3, responses.count);
    UARemoteDataPayload *payload = responses[1][0];
    XCTAssertEqualObjects(payloads[0][@"data"], payload.data);
    XCTAssertEqualObjects(@"test", payload.type);

    payload = responses[2][0];
    XCTAssertEqualObjects(update[0][@"data"], payload.data);
    XCTAssertEqualObjects(@"test", payload.type);
}

- (void)testSubscriptionUpdatesNoChanges {
    NSArray *payloads = @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"Callback called"];
    callbackCalled.expectedFulfillmentCount = 2;
    NSMutableArray *responses = [NSMutableArray array];
    [self.remoteDataManager subscribeWithTypes:@[@"test"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        [responses addObject:remoteDataArray];
        [callbackCalled fulfill];
    }];

    [self updatePayloads:payloads];
    [self updatePayloads:payloads];

    [self waitForTestExpectations];

    XCTAssertEqual(2, responses.count);
    UARemoteDataPayload *payload = responses[1][0];
    XCTAssertEqualObjects(payloads[0][@"data"], payload.data);
    XCTAssertEqualObjects(@"test", payload.type);
}

- (void)testSubscriptionUpdatesMetadataChanged {
    NSArray *payloads = @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"Callback called"];
    callbackCalled.expectedFulfillmentCount = 3;
    NSMutableArray *responses = [NSMutableArray array];
    [self.remoteDataManager subscribeWithTypes:@[@"test"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        [responses addObject:remoteDataArray];
        [callbackCalled fulfill];
    }];

    [self updatePayloads:payloads];

    // change URL so metadata changes
    self.requestURL = [NSURL URLWithString:@"some-other-url"];

    [self updatePayloads:payloads];

    [self waitForTestExpectations];

    XCTAssertEqual(3, responses.count);
    UARemoteDataPayload *payload = responses[1][0];
    XCTAssertEqualObjects(payloads[0][@"data"], payload.data);
    XCTAssertEqualObjects(@"test", payload.type);

    payload = responses[2][0];
    XCTAssertEqualObjects(payloads[0][@"data"], payload.data);
    XCTAssertEqualObjects(@"test", payload.type);
}

- (void)testSortUpdates {
    NSArray *payloads = @[
        @{ @"type": @"foo", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }},
        @{ @"type": @"bar", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }},
    ];

    [self updatePayloads:payloads];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"Callback called"];
    __block NSArray *remoteData = nil;
    [self.remoteDataManager subscribeWithTypes:@[@"bar", @"foo"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        remoteData = remoteDataArray;
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertEqual(2, remoteData.count);
    XCTAssertEqualObjects(@"bar", ((UARemoteDataPayload *)remoteData[0]).type);
    XCTAssertEqualObjects(@"foo", ((UARemoteDataPayload *)remoteData[1]).type);
}

- (void)updatePayloads:(NSArray *)payloads {
    UARemoteDataResponse *response = [[UARemoteDataResponse alloc] initWithStatus:200
                                                                       requestURL:self.requestURL
                                                                         payloads:payloads
                                                                     lastModified:@"2018-01-01T12:00:00"];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARemoteDataAPIClientCompletionHandler completionHandler = (__bridge UARemoteDataAPIClientCompletionHandler) arg;
        completionHandler(response, nil);
    }] fetchRemoteDataWithLocale:OCMOCK_ANY lastModified:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    XCTestExpectation *updateFinished = [self expectationWithDescription:@"Task finished"];
    [[[mockTask expect] andDo:^(NSInvocation *invocation) {
        [updateFinished fulfill];
    }] taskCompleted];

    self.launchHandler(mockTask);

    [self waitForTestExpectations:@[updateFinished]];

    [self.mockAPIClient verify];
    [mockTask verify];
}

- (void)testSettingRefreshInterval {
    XCTAssertEqual(self.remoteDataManager.remoteDataRefreshInterval, UARemoteDataRefreshIntervalDefault);
    self.remoteDataManager.remoteDataRefreshInterval = 9999;
    XCTAssertEqual(self.remoteDataManager.remoteDataRefreshInterval, 9999);
}

- (UARemoteDataManager *)createManager {
    return [UARemoteDataManager remoteDataManagerWithConfig:self.config
                                                  dataStore:self.dataStore
                                            remoteDataStore:self.testStore
                                        remoteDataAPIClient:self.mockAPIClient
                                         notificationCenter:self.notificationCenter
                                            appStateTracker:self.testAppStateTracker
                                                 dispatcher:[[UATestDispatcher alloc] init]
                                                       date:self.testDate
                                              localeManager:self.mockLocaleManager
                                                taskManager:self.mockTaskManager
                                             privacyManager:self.privacyManager];
}

@end


