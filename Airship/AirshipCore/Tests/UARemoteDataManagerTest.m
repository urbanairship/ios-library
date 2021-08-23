/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

/**
 * Used to test what UARemoteDataManager does when the cache fails underneath it.
 */

static NSString * const RefreshTask = @"RemoteDataManager.refresh";

@interface UARemoteDataManagerTest : UAAirshipBaseTest

@property (nonatomic, strong) UATestRemoteDataAPIClient *testAPIClient;
@property (nonatomic, strong) UATestLocaleManager *testLocaleManager;
@property (nonatomic, strong) UATestTaskManager *testTaskManager;

@property (nonatomic, strong) UARemoteDataManager *remoteDataManager;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, strong) UARemoteDataStore *testStore;
@property (nonatomic, strong) UATestAppStateTracker *testAppStateTracker;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;

@property (nonatomic, strong) UATestDate *testDate;
@property (nonatomic, copy) NSArray<NSDictionary *> *remoteDataFromCloud;
@property (nonatomic, strong) NSURL *requestURL;
@end

@implementation UARemoteDataManagerTest

- (void)setUp {
    [super setUp];

    self.testAPIClient = [[UATestRemoteDataAPIClient alloc] init];
    self.requestURL = [NSURL URLWithString:@"some-url"];
    
    UA_WEAKIFY(self)
    self.testAPIClient.metdataCallback = ^(NSLocale * locale) {
        UA_STRONGIFY(self)
        return @{ @"url": self.requestURL.absoluteString };
    };
    
    self.testStore = [[UARemoteDataStore alloc] initWithStoreName:[NSUUID UUID].UUIDString inMemory:YES];
    self.testDate = [[UATestDate alloc] initWithOffset:0 dateOverride:[NSDate date]];
    self.notificationCenter = [[NSNotificationCenter alloc] init];

    self.testLocaleManager = [[UATestLocaleManager alloc] init];
    self.testLocaleManager.currentLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en-US"];
    self.testTaskManager = [[UATestTaskManager alloc] init];
    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];
    self.testAppStateTracker = [[UATestAppStateTracker alloc] init];
    self.testAppStateTracker.currentState = UAApplicationStateActive;
    self.remoteDataManager = [self createManager];
    
    XCTAssertEqual(1, self.testTaskManager.enqueuedRequestsCount);
    [self.testTaskManager clearEnqueuedRequests];
}


- (void)tearDown {
    [self.testStore shutDown];
    [super tearDown];
}


- (UARemoteDataManager *)createManager {
    return [[UARemoteDataManager alloc] initWithDataStore:self.dataStore
                                            localeManager:self.testLocaleManager
                                           privacyManager:self.privacyManager
                                                apiClient:self.testAPIClient
                                          remoteDataStore:self.testStore
                                              taskManager:self.testTaskManager
                                               dispatcher:[[UATestDispatcher alloc] init]
                                                     date:self.testDate
                                       notificationCenter:self.notificationCenter
                                          appStateTracker:self.testAppStateTracker];
}


- (void)testForegroundRefresh {
    XCTAssertEqual(0, self.testTaskManager.enqueuedRequestsCount);
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(1, self.testTaskManager.enqueuedRequestsCount);
}


- (void)testRemoteConfigUpdated {
    XCTAssertEqual(0, self.testTaskManager.enqueuedRequestsCount);
    [self.notificationCenter postNotificationName:UARuntimeConfig.configUpdatedEvent object:nil];
    XCTAssertEqual(1, self.testTaskManager.enqueuedRequestsCount);
}

- (void)testCheckRefresh {
    XCTAssertEqual(0, self.testTaskManager.enqueuedRequestsCount);

    // Set initial metadata
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    [self updatePayloads:payloads];

    self.remoteDataManager.remoteDataRefreshInterval = 100;

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(0, self.testTaskManager.enqueuedRequestsCount);

    // Refresh interval
    self.testDate.offset += 100;
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(1, self.testTaskManager.enqueuedRequestsCount);
}

- (void)testCheckRefreshAppVersionChanages {
    self.remoteDataManager.remoteDataRefreshInterval = 1000;

    // Set initial metadata
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    [self updatePayloads:payloads];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(0, self.testTaskManager.enqueuedRequestsCount);

    // change app version
    id mockedBundle = [self mockForClass:[NSBundle class]];
    [[[mockedBundle stub] andReturn:mockedBundle] mainBundle];
    [[[mockedBundle stub] andReturn:@{@"CFBundleShortVersionString": @"1.1.1"}] infoDictionary];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(1, self.testTaskManager.enqueuedRequestsCount);
}

- (void)testCheckRefreshMetadataChanages {
    self.remoteDataManager.remoteDataRefreshInterval = 1000;

    // Set initial metadata
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    [self updatePayloads:payloads];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(0, self.testTaskManager.enqueuedRequestsCount);

    // change URL
    self.requestURL = [NSURL URLWithString:@"some-other-url"];

    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
    XCTAssertEqual(1, self.testTaskManager.enqueuedRequestsCount);
}

- (void)testLocaleChangeRefresh {
    XCTAssertEqual(0, self.testTaskManager.enqueuedRequestsCount);
    [self.notificationCenter postNotificationName:UALocaleManager.localeUpdatedEvent object:nil];
    XCTAssertEqual(1, self.testTaskManager.enqueuedRequestsCount);
}

- (void)testContentAvailableRefresh {
    XCTAssertEqual(0, self.testTaskManager.enqueuedRequestsCount);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback called"];

    [((NSObject<UAPushableComponent> *)self.remoteDataManager) receivedRemoteNotification:@{
        @"com.urbanairship.remote-data.update": @(true)
    } completionHandler:^(UIBackgroundFetchResult result) {
        XCTAssertEqual(UAActionFetchResultNewData, result);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
    XCTAssertEqual(1, self.testTaskManager.enqueuedRequestsCount);
}

- (void)testRefreshRemoteData {
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    [self updatePayloads:payloads];
}

- (void)testRefreshRemoteData304 {
    UARemoteDataResponse *updateResponse = [[UARemoteDataResponse alloc] initWithStatus:304
                                                                               metadata:nil
                                                                               payloads:nil
                                                                           lastModified:nil];
    
    self.testAPIClient.fetchCallback = ^(NSLocale *locale, NSString *timeStamp, void (^completionHandler)(UARemoteDataResponse *, NSError *)) {
        completionHandler(updateResponse, nil);
    };

    UATestTask *task = [self.testTaskManager launchSyncWithTaskID:RefreshTask options:UATaskRequestOptions.defaultOptions];
    XCTAssertTrue(task.completed);
}

- (void)testRefreshRemoteDataClientError {
    UARemoteDataResponse *response = [[UARemoteDataResponse alloc] initWithStatus:400
                                                                         metadata:nil
                                                                         payloads:nil
                                                                     lastModified:nil];

    self.testAPIClient.fetchCallback = ^(NSLocale *locale, NSString *timeStamp, void (^completionHandler)(UARemoteDataResponse *, NSError *)) {
        completionHandler(response, nil);
    };

    UATestTask *task = [self.testTaskManager launchSyncWithTaskID:RefreshTask options:UATaskRequestOptions.defaultOptions];
    XCTAssertTrue(task.completed);
}

- (void)testRefreshRemoteDataServerError {
    UARemoteDataResponse *response = [[UARemoteDataResponse alloc] initWithStatus:500
                                                                         metadata:nil
                                                                         payloads:nil
                                                                     lastModified:nil];

    self.testAPIClient.fetchCallback = ^(NSLocale *locale, NSString *timeStamp, void (^completionHandler)(UARemoteDataResponse *, NSError *)) {
        completionHandler(response, nil);
    };

    UATestTask *task = [self.testTaskManager launchSyncWithTaskID:RefreshTask options:UATaskRequestOptions.defaultOptions];
    XCTAssertTrue(task.failed);
}

- (void)testRefreshLastModifiedMetadataChanges {
    NSArray *payloads =  @[@{ @"type": @"test", @"timestamp":@"2017-01-01T12:00:00", @"data": @{ @"foo": @"bar" }}];
    [self updatePayloads:payloads];
    
    self.testAPIClient.fetchCallback = ^(NSLocale *locale, NSString *timeStamp, void (^completionHandler)(UARemoteDataResponse *, NSError *)) {
        XCTAssertNotNil(timeStamp);
        completionHandler(nil, nil);
    };
    
    UATestTask *task = [self.testTaskManager launchSyncWithTaskID:RefreshTask options:UATaskRequestOptions.defaultOptions];
    XCTAssertTrue(task.failed);

    // change return URL
    self.requestURL = [NSURL URLWithString:@"some-other-url"];

    self.testAPIClient.fetchCallback = ^(NSLocale *locale, NSString *timeStamp, void (^completionHandler)(UARemoteDataResponse *, NSError *)) {
        XCTAssertNil(timeStamp);
        completionHandler(nil, nil);
    };
    task = [self.testTaskManager launchSyncWithTaskID:RefreshTask options:UATaskRequestOptions.defaultOptions];
    XCTAssertTrue(task.failed);
}


- (void)testRefreshError {
    id error = [self mockForClass:[NSError class]];
    self.testAPIClient.fetchCallback = ^(NSLocale *locale, NSString *timeStamp, void (^completionHandler)(UARemoteDataResponse *, NSError *)) {
        completionHandler(nil, error);
    };
    
    UATestTask *task = [self.testTaskManager launchSyncWithTaskID:RefreshTask options:UATaskRequestOptions.defaultOptions];
    XCTAssertTrue(task.failed);
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
    UA_WEAKIFY(self)
    self.testAPIClient.fetchCallback = ^(NSLocale * locale, NSString * timestamp, void (^completionHandler)(UARemoteDataResponse * _Nullable, NSError * _Nullable)) {
        
        UA_STRONGIFY(self)
        
        NSDictionary *metadata = self.testAPIClient.metdataCallback(locale);
        NSMutableArray *parsed = [NSMutableArray array];
        for (id payload in payloads) {
            NSString *type = payload[@"type"];
            NSDate *timestamp = [[UAUtils ISODateFormatterUTCWithDelimiter] dateFromString:payload[@"timestamp"]];
            NSDictionary *data = payload[@"data"];
            
            UARemoteDataPayload *remoteData = [[UARemoteDataPayload alloc] initWithType:type
                                                                              timestamp:timestamp
                                                                                   data:data
                                                                               metadata:metadata];
            
            [parsed addObject:remoteData];
        }
        
        UARemoteDataResponse *response = [[UARemoteDataResponse alloc] initWithStatus:200
                                                                             metadata:metadata
                                                                              payloads:parsed
                                                                         lastModified:@"2018-01-01T12:00:00"];
        
        completionHandler(response, nil);
    };

    UATestTask *task = [self.testTaskManager launchSyncWithTaskID:RefreshTask options:UATaskRequestOptions.defaultOptions];
    XCTAssertTrue(task.completed);
}

- (void)testSettingRefreshInterval {
    XCTAssertEqual(self.remoteDataManager.remoteDataRefreshInterval, 10);
    self.remoteDataManager.remoteDataRefreshInterval = 9999;
    XCTAssertEqual(self.remoteDataManager.remoteDataRefreshInterval, 9999);
}

@end


