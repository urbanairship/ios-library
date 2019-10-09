/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UARemoteDataAPIClient+Internal.h"
#import "UARemoteDataManager+Internal.h"

#import "UARemoteDataPayload+Internal.h"
#import "UARemoteDataStore+Internal.h"

#import "UAPreferenceDataStore+Internal.h"
#import "UARuntimeConfig.h"
#import "UAUtils+Internal.h"

#import "UABaseTest.h"
#import "UATestDispatcher.h"

/**
 * Used to test what UARemoteDataManager does when the cache fails underneath it.
 */
@interface UATestRemoteDataStore : UARemoteDataStore
@property (nonatomic, assign) BOOL failOverwriteCachedRemoteDataWithResponse;
@end

@implementation UATestRemoteDataStore

- (void)overwriteCachedRemoteDataWithResponse:(NSArray<UARemoteDataPayload *> *)remoteDataPayloads completionHandler:(void (^)(BOOL))completionHandler {
    if (self.failOverwriteCachedRemoteDataWithResponse) {
        completionHandler(NO);
    } else {
        [super overwriteCachedRemoteDataWithResponse:remoteDataPayloads completionHandler:completionHandler];
    }
}

@end

@interface UARemoteDataManagerTest : UABaseTest

@property (nonatomic, strong) id mockAPIClient;
@property (nonatomic, strong) id mockAPIClientClass;

@property (nonatomic, strong) UARemoteDataManager *remoteDataManager;
@property (nonatomic, strong) UATestRemoteDataStore *testStore;

@property (nonatomic, strong) NSDictionary *expectedMetadata;

@property (nonatomic, strong) NSArray<NSDictionary *> *remoteDataFromCloud;
@property (nonatomic, assign) BOOL expectAPIClientFetch;


@end

@implementation UARemoteDataManagerTest

- (void)setUp {
    [super setUp];

    self.mockAPIClient = [self mockForClass:[UARemoteDataAPIClient class]];

    self.mockAPIClientClass = OCMClassMock([UARemoteDataAPIClient class]);
    OCMStub([self.mockAPIClientClass clientWithConfig:[OCMArg any] dataStore:[OCMArg any]]).andReturn(self.mockAPIClient);
    
    self.testStore = [UATestRemoteDataStore storeWithName:@"UARemoteDataManagerTest." inMemory:YES];
    self.remoteDataManager = [self createManager];
    self.expectAPIClientFetch = YES;
    self.expectedMetadata = [self.remoteDataManager createMetadata:[NSLocale autoupdatingCurrentLocale]];
}

- (void)tearDown {
    [self.mockAPIClient stopMocking];
    [self.mockAPIClientClass stopMocking];

    [self.testStore shutDown];
    [self.testStore waitForIdle];

    [super tearDown];
}

- (void)testUnsubscribe {
    // set up test data and expectations
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        XCTFail(@"Should never get any data");
    }];
    XCTAssertNotNil(subscription);

    [subscription dispose];

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];
}

// client (test) subscribes to remote data manager
// simulate one payload from cloud
// payload should be published to client
- (void)testSuccessfulRefresh {
    // set up test data and expectations
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    __block XCTestExpectation *receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"]];

    // subscribe to remote data manager and observe notifications
    __block NSUInteger callbackCount = 0;
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        switch(callbackCount) {
            case 0:
                [receivedDataExpectation fulfill];

                XCTAssert([remoteDataArray count] == 1);
                XCTAssertEqualObjects([NSCountedSet setWithArray:testPayloads], [NSCountedSet setWithArray:remoteDataArray]);
                break;
            default:
                XCTFail(@"Should only be one notification");
                break;
        }
        callbackCount++;
    }];
    XCTAssertNotNil(subscription);

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];

    // cleanup
    [subscription dispose];
}

// client (test) subscribes to remote data manager
// simulate 504 failure from cloud
- (void)testFailedRefresh {
    // set up test data and expectations
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata withHTTPStatus:504] mutableCopy];

    // subscribe to remote data manager and observe notifications
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        XCTFail("Callback should not fire on failed refresh");
    }];
    XCTAssertNotNil(subscription);

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];

    // cleanup
    [subscription dispose];
}

// client (test) subscribes to remote data manager
// simulate API failure when fetching payload from cloud
// payload should not be published to client
- (void)testCacheFailedRefresh {
    // simulate a failure when overwriting cache
    self.testStore.failOverwriteCachedRemoteDataWithResponse = YES;

    // set up test data and expectations
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    // subscribe to remote data manager and observe notifications
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        XCTFail("Callback should not fire on failed refresh");
    }];
    XCTAssertNotNil(subscription);

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];

    // cleanup
    [subscription dispose];
}

// client (test) subscribes to remote data manager
// simulate one payload from cloud
// payload should not be published to client
- (void)testFailedRefreshNoData {
    // set up test data and expectations
     NSArray<UARemoteDataPayload *> *testPayloads = [self createNPayloadsAndSetupTest:0 metadata:self.expectedMetadata withHTTPStatus:200];

    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        XCTFail(@"Callback should not fire when there is no data");
    }];
    XCTAssertNotNil(subscription);

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];

    // cleanup
    [subscription dispose];
}

// client (test) subscribes to remote data manager
// simulate one payload from cloud
// payload should be published to client
// simulate same payload from cloud
// payload should not be published to client
- (void)testSuccessfulRefreshPayloadDoesntChange {
    // set up test 1
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    __block XCTestExpectation *receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"]];

    // subscribe to remote data manager and observe notifications
    __block NSUInteger callbackCount = 0;
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        switch(callbackCount) {
            case 0:
                // first notification
                [receivedDataExpectation fulfill];

                XCTAssert([remoteDataArray count] == 1);
                XCTAssertEqualObjects([NSCountedSet setWithArray:testPayloads],[NSCountedSet setWithArray:remoteDataArray]);
                break;
            default:
                XCTFail(@"Should only be one notification");
                break;
        }
        callbackCount++;
    }];
    XCTAssertNotNil(subscription);

    // test 1
    [self refresh];

    // verify 1
    [self waitForTestExpectations];

    // setup with same payload
    [self setupTestWithPayloads:testPayloads];

    // test 2
    [self refresh];

    // verify 2
    [self waitForTestExpectations];

    // cleanup
    [subscription dispose];
}

// client (test) subscribes to remote data manager
// simulate one payload from cloud
// payload should be published to client
// simulate changed payload from cloud
// payload should be published to client
- (void)testSuccessfulRefreshPayloadChanged {
    // set up test data and expectations
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    __block XCTestExpectation *receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data of type: %@",testPayloads[0].type]];

    // test
    // subscribe to remote data manager and observe notifications
    __block NSUInteger callbackCount = 0;
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        switch(callbackCount) {
            case 0:
            case 1:
                [receivedDataExpectation fulfill];

                XCTAssert([remoteDataArray count] == 1);
                XCTAssertEqualObjects([NSCountedSet setWithArray:testPayloads],[NSCountedSet setWithArray:remoteDataArray]);
                break;
            default:
                XCTFail(@"Should only be two notifications");
                break;
        }
        callbackCount++;
    }];
    XCTAssertNotNil(subscription);

    [self refresh];

    // verify
    [self waitForTestExpectations];

    // setup with changed payload
    testPayloads[0] = [self changePayload:testPayloads[0]];
    [self setupTestWithPayloads:testPayloads];
    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"]];

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];

    // cleanup
    [subscription dispose];
}

// client (test) subscribes to remote data manager
// simulate one payload from cloud
// payload should be published to client
// simulate changed metadata from cloud
// payload with new metadata should be published to client
- (void)testSuccessfulRefreshMetadataChanged {
    // set up test data and expectations
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    __block XCTestExpectation *receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data of type: %@", testPayloads[0].type]];

    // test
    // subscribe to remote data manager and observe notifications
    __block NSUInteger callbackCount = 0;
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        switch(callbackCount) {
            case 0:
                [receivedDataExpectation fulfill];

                XCTAssert([remoteDataArray count] == 1);
                XCTAssertEqualObjects([NSCountedSet setWithArray:testPayloads], [NSCountedSet setWithArray:remoteDataArray]);
                break;
            case 1:
                [receivedDataExpectation fulfill];

                XCTAssert([remoteDataArray count] == 1);

                // Make the expected metadata change to the expected payload
                XCTAssertEqualObjects([NSCountedSet setWithArray:testPayloads], [NSCountedSet setWithArray:remoteDataArray]);
                break;
            default:
                XCTFail(@"Should only be two notifications");
                break;
        }
        callbackCount++;
    }];

    XCTAssertNotNil(subscription);

    [self refresh];

    // verify
    [self waitForTestExpectations];

    // setup with changed mocked payload
    NSString *expectedChangedLocaleString = @"changed-locale";
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:expectedChangedLocaleString];
    id mockLocaleClass = [self strictMockForClass:[NSLocale class]];
    [[[mockLocaleClass stub] andReturn:locale] autoupdatingCurrentLocale];

    // Update with mocked metadata locale
    testPayloads[0] = [self updatePayloadMetadata:testPayloads[0]];
    [self setupTestWithPayloads:testPayloads];

    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"]];

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];

    // cleanup
    [subscription dispose];

    [mockLocaleClass stopMocking];
}

// client (test) subscribes to remote data manager
// simulate multiple payloads from cloud
// payloads should be published to client
// simulate same payloads from cloud
// payloads should not be published to client
- (void)testMultiplePayloadsNoneHaveChanged {
    // setup
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:2 metadata:self.expectedMetadata] mutableCopy];

    __block XCTestExpectation *receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"",testPayload.type"]];

    // test
    // subscribe to remote data manager and observe notifications
    __block NSUInteger callbackCount = 0;
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        [receivedDataExpectation fulfill];
        switch(callbackCount) {
            case 0:
                XCTAssert([remoteDataArray count] == 2);
                XCTAssertTrue([[NSCountedSet setWithArray:testPayloads] isEqualToSet:[NSCountedSet setWithArray:remoteDataArray]]);
                break;
            default:
                XCTFail(@"Should only be one notification");
                break;
        }
        callbackCount++;
    }];
    XCTAssertNotNil(subscription);

    [self refresh];

    // verify
    [self waitForTestExpectations];

    // setup with same payloads
    [self setupTestWithPayloads:testPayloads];

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];
    XCTAssert(callbackCount == 1);

    // cleanup
    [subscription dispose];
}

// client (test) subscribes to remote data manager
// simulate multiple payloads from cloud
// payloads should be published to client
// simulate changed payloads from cloud
// payloads should be published to client
- (void)testMultiplePayloadsAllHaveChanged {
    // setup
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:2 metadata:self.expectedMetadata] mutableCopy];

    __block XCTestExpectation *receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"]];

    // test
    // subscribe to remote data manager and observe notifications
    __block NSUInteger callbackCount = 0;
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        [receivedDataExpectation fulfill];
        switch(callbackCount) {
            case 0:
            case 1:
                XCTAssert([remoteDataArray count] == 2);
                XCTAssertEqualObjects([NSCountedSet setWithArray:testPayloads],[NSCountedSet setWithArray:remoteDataArray]);
                break;
            default:
                XCTFail(@"Should only be one notification");
                break;
        }
        callbackCount++;
    }];
    XCTAssertNotNil(subscription);

    [self refresh];

    // verify
    [self waitForTestExpectations];

    // setup with new payloads
    testPayloads[0] = [self changePayload:testPayloads[0]];
    testPayloads[1] = [self changePayload:testPayloads[1]];
    [self setupTestWithPayloads:testPayloads];
    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"]];

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];
    XCTAssert(callbackCount == 2,"Callback count (%lu) should be 2",callbackCount);

    // cleanup
    [subscription dispose];
}

// simulate multiple payloads from cloud
// client (test) subscribes to remote data manager
// all payloads should be published to client
// simulate changed payloads from cloud
// all changed payloads should be published to client
- (void)testMultiplePayloadsAllHaveChangedDataReceivedBeforeSubscription {
    // setup
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:2 metadata:self.expectedMetadata] mutableCopy];

    [self refresh];
    [self waitForTestExpectations];

    __block XCTestExpectation *receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"]];

    // test
    // subscribe to remote data manager and observe notifications
    __block NSUInteger callbackCount = 0;
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        [receivedDataExpectation fulfill];
        switch(callbackCount) {
            case 0:
            case 1:
                XCTAssert([remoteDataArray count] == 2);
                XCTAssertEqualObjects([NSCountedSet setWithArray:testPayloads],[NSCountedSet setWithArray:remoteDataArray]);
                break;
            default:
                XCTFail(@"Should only be two notifications");
                break;
        }
        callbackCount++;
    }];
    XCTAssertNotNil(subscription);

    // verify
    [self waitForTestExpectations];

    // setup
    testPayloads[0] = [self changePayload:testPayloads[0]];
    testPayloads[1] = [self changePayload:testPayloads[1]];
    [self setupTestWithPayloads:testPayloads];
    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"]];

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];
    XCTAssert(callbackCount == 2,"Callback count (%lu) should be 2",callbackCount);

    // cleanup
    [subscription dispose];
}

// client (test) subscribes to remote data manager
// simulate multiple payloads from cloud
// payloads should be published to client
// simulate some changed payloads from cloud
// all payloads should be published to client
- (void)testMultiplePayloadsSomeHaveChanged {
    // setup
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:2 metadata:self.expectedMetadata] mutableCopy];

    __block XCTestExpectation *receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"]];

    // test
    // subscribe to remote data manager and observe notifications
    __block NSUInteger callbackCount = 0;
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        [receivedDataExpectation fulfill];
        switch(callbackCount) {
            case 0:
                XCTAssert([remoteDataArray count] == 2);
                XCTAssertEqualObjects([NSCountedSet setWithArray:testPayloads],[NSCountedSet setWithArray:remoteDataArray]);
                break;
            case 1:
                XCTAssertEqualObjects(testPayloads, remoteDataArray);
                break;
            default:
                XCTFail(@"Should only be one notification");
                break;
        }
        callbackCount++;
    }];

    XCTAssertNotNil(subscription);

    [self refresh];

    // verify
    [self waitForTestExpectations];

    // setup with one changed payload
    testPayloads[1] = [self changePayload:testPayloads[1]];
    [self setupTestWithPayloads:testPayloads];
    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"]];

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];
    XCTAssert(callbackCount == 2);

    // cleanup
    [subscription dispose];
}

/**
 * Test that the result is sorted by the subscribe order.
 */
- (void)testSortUpdates {
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:2 metadata:self.expectedMetadata] mutableCopy];
    NSArray *reversed = [[testPayloads reverseObjectEnumerator] allObjects];

    __block XCTestExpectation *receivedDataExpectation = [self expectationWithDescription:@"Received data"];
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[reversed valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        [receivedDataExpectation fulfill];
        XCTAssertEqualObjects(reversed, remoteDataArray);
    }];

    [self refresh];
    [self waitForTestExpectations];

    // cleanup
    [subscription dispose];
}

// client (test) subscribes to remote data manager
// simulate multiple payloads from cloud, with at least two of a single type
// all payloads should be published to client
// simulate same payloads from cloud
// payloads should not be published to client
- (void)testMultiplePayloadsPerTypeNoneHaveChanged {
    // setup
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:2 metadata:self.expectedMetadata] mutableCopy];
    // add a third payload that is of the same type as the first payload
    [testPayloads addObject:[self changePayload:testPayloads[0]]];
    [self replaceTestPayloads:testPayloads];

    __block XCTestExpectation *receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data"",testPayload.type"]];

    // test
    // subscribe to remote data manager and observe notifications
    __block NSUInteger callbackCount = 0;
    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        [receivedDataExpectation fulfill];
        switch(callbackCount) {
            case 0:
                XCTAssert([remoteDataArray count] == 3,@"array count is %lu, but should be 3",remoteDataArray.count);
                XCTAssertTrue([[NSCountedSet setWithArray:testPayloads] isEqualToSet:[NSCountedSet setWithArray:remoteDataArray]],@"published data does not match cloud data");
                break;
            default:
                XCTFail(@"Should only be one notification");
                break;
        }
        callbackCount++;
    }];
    XCTAssertNotNil(subscription);

    [self refresh];

    // verify
    [self waitForTestExpectations];

    // setup with same payloads
    [self setupTestWithPayloads:testPayloads];

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];
    XCTAssert(callbackCount == 1);

    // cleanup
    [subscription dispose];
}

- (void)testSettingRefreshInterval {
    XCTAssertEqual(self.remoteDataManager.remoteDataRefreshInterval,0);
    self.remoteDataManager.remoteDataRefreshInterval = 9999;
    XCTAssertEqual(self.remoteDataManager.remoteDataRefreshInterval,9999);
}

- (void)testRefreshInterval {
    // set up test data
    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    __block XCTestExpectation *receivedDataExpectation;

    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        if (receivedDataExpectation) {
            [receivedDataExpectation fulfill];
        } else {
            XCTFail(@"Didn't expect to receive any data");
        }
    }];
    XCTAssertNotNil(subscription);

    // expect to get data
    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data of type: %@",testPayloads[0].type]];

    // test
    [self foregroundRefresh];

    // verify
    [self waitForTestExpectations];

    // setup with changed payload but long refresh interval
    testPayloads[0] = [self changePayload:testPayloads[0]];
    [self setupTestWithPayloads:testPayloads];
    self.remoteDataManager.remoteDataRefreshInterval = 9999;

    // expect not to get data
    receivedDataExpectation = nil;
    self.expectAPIClientFetch = NO;

    // test
    [self foregroundRefresh];

    // verify
    [self waitForTestExpectations];

    // setup
    [self setupTestWithPayloads:testPayloads];
    self.remoteDataManager.remoteDataRefreshInterval = 0;

    // expect to get data from previous refresh
    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Received remote data of type: %@",testPayloads[0].type]];
    self.expectAPIClientFetch = YES;

    // test
    [self foregroundRefresh];

    // verify
    [self waitForTestExpectations];

    // cleanup
    [subscription dispose];
}

// Tests app locale change when a locale change happens while the app is terminated
- (void)testAppLocaleChange {
    __block XCTestExpectation *receivedDataExpectation;

    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    // change the locale identifier to en_01
    id mockedLocale = [self mockForClass:[NSLocale class]];
    [[[mockedLocale stub] andReturn:mockedLocale] currentLocale];
    [[[mockedLocale stub] andReturn:@"en_01"] localeIdentifier];

    // create a new remote data manager, which should cause a refresh due to the changed app locale
    self.remoteDataManager = [self createManager];

    // expect to get data
    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"First receipt of remote data of type: %@",testPayloads[0].type]];
    receivedDataExpectation.assertForOverFulfill = NO; // NOTE: it's OK to be notified of data more than once

    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        if (receivedDataExpectation) {
            [receivedDataExpectation fulfill];
        } else {
            XCTFail(@"Didn't expect to receive any data");
        }
    }];
    XCTAssertNotNil(subscription);

    // verify
    [self waitForTestExpectations];

    // set up new payloads
    testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    // create a new remote data manager, which should not cause a refresh due to the unchanged app locale
    [subscription dispose];
    self.remoteDataManager = [self createManager];

    // expect to get data
    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Second receipt remote data of type: %@",testPayloads[0].type]];
    receivedDataExpectation.assertForOverFulfill = NO; // NOTE: it's OK to be notified of data more than once

    subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        if (receivedDataExpectation) {
            [receivedDataExpectation fulfill];
        } else {
            XCTFail(@"Didn't expect to receive any data");
        }
    }];
    XCTAssertNotNil(subscription);

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];
}

- (void)testAppVersionChange {
    __block XCTestExpectation *receivedDataExpectation;

    NSMutableArray<UARemoteDataPayload *> *testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    // change the app version
    id mockedBundle = [self mockForClass:[NSBundle class]];
    [[[mockedBundle stub] andReturn:mockedBundle] mainBundle];
    [[[mockedBundle stub] andReturn:@{@"CFBundleShortVersionString": @"1.1.1"}] infoDictionary];

    // create a new remote data manager, which should cause a refresh due to the changed app version
    self.remoteDataManager = [self createManager];

    // expect to get data
    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"First receipt of remote data of type: %@",testPayloads[0].type]];
    receivedDataExpectation.assertForOverFulfill = NO; // NOTE: it's OK to be notified of data more than once

    UADisposable *subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        if (receivedDataExpectation) {
            [receivedDataExpectation fulfill];
        } else {
            XCTFail(@"Didn't expect to receive any data");
        }
    }];
    XCTAssertNotNil(subscription);

    // verify
    [self waitForTestExpectations];

    // set up new payloads
    testPayloads = [[self createNPayloadsAndSetupTest:1 metadata:self.expectedMetadata] mutableCopy];

    // create a new remote data manager, which should not cause a refresh due to the unchanged app version
    [subscription dispose];
    self.remoteDataManager = [self createManager];

    // expect to get data
    receivedDataExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"Second receipt remote data of type: %@",testPayloads[0].type]];
    receivedDataExpectation.assertForOverFulfill = NO; // NOTE: it's OK to be notified of data more than once

    subscription = [self.remoteDataManager subscribeWithTypes:[testPayloads valueForKeyPath:@"type"] block:^(NSArray<UARemoteDataPayload *> * _Nonnull remoteDataArray) {
        if (receivedDataExpectation) {
            [receivedDataExpectation fulfill];
        } else {
            XCTFail(@"Didn't expect to receive any data");
        }
    }];
    XCTAssertNotNil(subscription);

    // test
    [self refresh];

    // verify
    [self waitForTestExpectations];
}

#pragma mark -
#pragma mark Utility Methods

- (UARemoteDataPayload *)updatePayloadMetadata:(UARemoteDataPayload *)testPayload {
    UARemoteDataPayload *newTestPayload = [testPayload copy];

    NSTimeInterval secondsPerHour = 60 * 60;

    newTestPayload.timestamp = [testPayload.timestamp dateByAddingTimeInterval:1 * secondsPerHour];
    newTestPayload.metadata = [self.remoteDataManager createMetadata:[NSLocale autoupdatingCurrentLocale]];

    return newTestPayload;
}

- (UARemoteDataPayload *)changePayload:(UARemoteDataPayload *)testPayload {
    UARemoteDataPayload *newTestPayload = [testPayload copy];

    NSTimeInterval secondsPerHour = 60 * 60;
    newTestPayload.timestamp = [testPayload.timestamp dateByAddingTimeInterval:1 * secondsPerHour];

    NSMutableDictionary *testData = [testPayload.data mutableCopy];
    if (!testData[@"extraData"]) {
        testData[@"extraData"] = @"";
    }
    testData[@"extraData"] = [testData[@"extraData"] stringByAppendingString:@"ABCDEFG "];
    newTestPayload.data = testData;

    return newTestPayload;
}

- (NSArray<UARemoteDataPayload *> *)createNPayloadsAndSetupTest:(NSUInteger)numberOfPayloads metadata:(NSDictionary *)metadata {
    return [self createNPayloadsAndSetupTest:numberOfPayloads metadata:metadata withHTTPStatus:0];
}

- (NSArray<UARemoteDataPayload *> *)createNPayloadsAndSetupTest:(NSUInteger)numberOfPayloads metadata:(NSDictionary *)metadata withHTTPStatus:(NSUInteger)statusCode {
    NSMutableArray *testPayloads = [NSMutableArray arrayWithCapacity:numberOfPayloads];
    UARemoteDataPayload *testPayload;
    for (NSUInteger index = 0;index < numberOfPayloads;index++) {
        testPayload = [[UARemoteDataPayload alloc] initWithType:[[NSProcessInfo processInfo] globallyUniqueString]
                                                      timestamp:[UAUtils parseISO8601DateFromString:@"2017-01-01T12:00:00"]
                                                           data:@{
                                                                  @"message_center":  @{
                                                                          @"background_color": @"0000FF",
                                                                          @"font": [[NSProcessInfo processInfo] globallyUniqueString]
                                                                          }
                                                                  } metadata:metadata];
        [testPayloads addObject:testPayload];
    }

    [self setupTestWithPayloads:testPayloads withHTTPStatus:statusCode];

    return testPayloads;
}


- (void)setupTestWithPayloads:(NSArray<UARemoteDataPayload *> *)testPayloads {
    return [self setupTestWithPayloads:testPayloads withHTTPStatus:0];
}

- (void)setupTestWithPayloads:(NSArray<UARemoteDataPayload *> *)testPayloads withHTTPStatus:(NSUInteger)statusCode {
    NSArray *mockRemoteData = [self getMockedRemoteDataForPayloads:testPayloads];
    [self setUpMockAPIClientToReturnHTTPStatus:statusCode andRemoteData:mockRemoteData];
}

- (void)replaceTestPayloads:(NSArray<UARemoteDataPayload *> *)testPayloads {
    self.remoteDataFromCloud = [self getMockedRemoteDataForPayloads:testPayloads];
}

- (NSArray *)getMockedRemoteDataForPayloads:(NSArray<UARemoteDataPayload *> *)payloads {
    NSMutableArray *mockedRemoteData = [NSMutableArray array];
    NSDateFormatter *isoDateFormatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    for (NSUInteger index = 0; index < [payloads count]; index++) {
        XCTAssertNotNil(payloads[index].type);
        XCTAssertNotNil([isoDateFormatter stringFromDate:payloads[index].timestamp]);
        XCTAssertNotNil(payloads[index].data);
        NSMutableDictionary *payload =  [NSMutableDictionary dictionaryWithDictionary:@{
                                          @"type": payloads[index].type,
                                          @"timestamp": [isoDateFormatter stringFromDate:payloads[index].timestamp],
                                          @"data": payloads[index].data,
                                          @"metadata": payloads[index].metadata,
                                          }];

        [mockedRemoteData addObject:payload];
    }
    return mockedRemoteData;
}

- (void)setUpMockAPIClientToReturnHTTPStatus:(NSUInteger)statusCode andRemoteData:(NSArray<NSDictionary *> *)remoteData {
    // a zero statusCode indicates that we should return 304 if the data is unchanged, 200 if it is changed
    if (statusCode == 0) {
        if ([[NSCountedSet setWithArray:self.remoteDataFromCloud] isEqualToSet:[NSCountedSet setWithArray:remoteData]]) {
            statusCode = 304;
        } else {
            statusCode = 200;
        }
    }
    self.remoteDataFromCloud = remoteData;

    // safe to do set up expectation multiple times and no way to overwrite or cancel earlier ones
    [[[self.mockAPIClient stub] andDo:^(NSInvocation *invocation) {
        if (!self.expectAPIClientFetch) {
            XCTFail(@"Expecting no APIClient fetch");
            return;
        }

        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UARemoteDataRefreshSuccessBlock successBlock = (__bridge UARemoteDataRefreshSuccessBlock) arg;
        [invocation getArgument:&arg atIndex:3];
        UARemoteDataRefreshFailureBlock failureBlock = (__bridge UARemoteDataRefreshFailureBlock) arg;
        switch (statusCode) {
            case 200: {
                successBlock(statusCode,self.remoteDataFromCloud);
                break;
            }
            case 304: {
                successBlock(statusCode,nil);
                break;
            }
            case 504: {
                failureBlock();
                break;
            }
            default: {
                XCTFail(@"Unsupported statusCode = %ld",statusCode);
                break;
            }
        }
    }] fetchRemoteData:OCMOCK_ANY onFailure:OCMOCK_ANY];
}

- (void)refresh {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Refresh completion handler called"];
    [self.remoteDataManager refreshWithCompletionHandler:^(BOOL success) {
        [expectation fulfill];
    }];
}

- (void)foregroundRefresh {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Refresh completion handler called"];
    [self.remoteDataManager foregroundRefreshWithCompletionHandler:^(BOOL success) {
        [expectation fulfill];
    }];
}


- (UARemoteDataManager *)createManager {
    return [UARemoteDataManager remoteDataManagerWithConfig:self.config
                                                  dataStore:self.dataStore
                                            remoteDataStore:self.testStore
                                        remoteDataAPIClient:self.mockAPIClient
                                         notificationCenter:[[NSNotificationCenter alloc] init]
                                                 dispatcher:[UATestDispatcher testDispatcher]];
}

@end

