/* Copyright 2010-2019 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UARemoteDataStore+Internal.h"
#import "UARemoteDataStorePayload+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAConfig.h"

@interface UARemoteDataStoreTest : XCTestCase
@property UARemoteDataStore *remoteDataStore;

@end

@implementation UARemoteDataStoreTest

- (void)setUp {
    [super setUp];
    self.remoteDataStore = [UARemoteDataStore storeWithName:@"UARemoteDataStoreTest." inMemory:YES];
}

- (void)tearDown {
    [self.remoteDataStore shutDown];
    [self.remoteDataStore waitForIdle];

    [super tearDown];
}

- (void)testFirstRemoteData {
    
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"fetched remote data"];
    
    UARemoteDataPayload *testPayload = [self createRemoteDataPayload];
    [self.remoteDataStore overwriteCachedRemoteDataWithResponse:@[testPayload]
                            completionHandler:^(BOOL success) {
                                XCTAssertTrue(success);
                            }];
    
    [self.remoteDataStore fetchRemoteDataFromCacheWithPredicate:nil
                              completionHandler:^(NSArray<UARemoteDataStorePayload *> *remoteDataStorePayloads) {
                                  XCTAssertEqual(1, remoteDataStorePayloads.count);
                                  UARemoteDataStorePayload *dataStorePayload = remoteDataStorePayloads[0];
                                  XCTAssertEqualObjects(testPayload.type, dataStorePayload.type);
                                  XCTAssertEqualObjects(testPayload.timestamp, dataStorePayload.timestamp);
                                  XCTAssertEqualObjects(testPayload.data, dataStorePayload.data);

                                  [testExpectation fulfill];
                              }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testNewRemoteData {
    
    
    NSArray<UARemoteDataPayload *> *testPayloads = @[ [self createRemoteDataPayload],
                                                      [self createRemoteDataPayload],
                                                      [self createRemoteDataPayload]
                                                      ];
    
    
    [self.remoteDataStore overwriteCachedRemoteDataWithResponse:testPayloads
                                   completionHandler:^(BOOL success) {
                                       XCTAssertTrue(success);
                                   }];
    
    
    // Verify we have 3 messages
    XCTestExpectation *firstFetch = [self expectationWithDescription:@"fetched first round of remote data"];
    [self.remoteDataStore fetchRemoteDataFromCacheWithPredicate:nil
                                     completionHandler:^(NSArray<UARemoteDataStorePayload *> *remoteDataStorePayloads) {
                                         XCTAssertEqual(testPayloads.count, remoteDataStorePayloads.count);
                                         for (UARemoteDataPayload *testPayload in testPayloads) {
                                             BOOL matchedPayloadTypes = NO;
                                             for (UARemoteDataStorePayload *dataStorePayload in remoteDataStorePayloads) {
                                                 if ([testPayload.type isEqualToString:dataStorePayload.type]) {
                                                     XCTAssertEqualObjects(testPayload.timestamp, dataStorePayload.timestamp);
                                                     XCTAssertEqualObjects(testPayload.data, dataStorePayload.data);
                                                     matchedPayloadTypes = YES;
                                                 }
                                             }
                                             XCTAssertTrue(matchedPayloadTypes);
                                         }
                                         [firstFetch fulfill];
                                     }];
    
    
    // Provide new remote data for one of the payload types
    UARemoteDataPayload *testPayload = [self createRemoteDataPayload];
    testPayload.type = testPayloads[1].type;
    
    
    // Sync only the modified message
    [self.remoteDataStore overwriteCachedRemoteDataWithResponse:@[testPayload]
                                   completionHandler:^(BOOL success) {
                                       XCTAssertTrue(success);
                            }];
    
    // Verify we only have the modified message with the updated title
    XCTestExpectation *secondFetch = [self expectationWithDescription:@"fetched second round of remote data"];
    [self.remoteDataStore fetchRemoteDataFromCacheWithPredicate:nil
                                     completionHandler:^(NSArray<UARemoteDataStorePayload *> *remoteDataStorePayloads) {
                                         XCTAssertEqual(1, remoteDataStorePayloads.count);
                                         UARemoteDataStorePayload *dataStorePayload = remoteDataStorePayloads[0];
                                         XCTAssertEqualObjects(testPayload.type, dataStorePayload.type);
                                         XCTAssertEqualObjects(testPayload.timestamp, dataStorePayload.timestamp);
                                         XCTAssertEqualObjects(testPayload.data, dataStorePayload.data);
                                         
                                         [secondFetch fulfill];
                                     }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
    
    
}

- (UARemoteDataPayload *)createRemoteDataPayload {
    UARemoteDataPayload *testPayload = [[UARemoteDataPayload alloc] initWithType:[[NSProcessInfo processInfo] globallyUniqueString]
                                                                       timestamp:[NSDate date]
                                                                            data:@{
                                                                                   @"message_center":  @{
                                                                                           @"background_color": [[NSProcessInfo processInfo] globallyUniqueString],
                                                                                           @"font": [[NSProcessInfo processInfo] globallyUniqueString]
                                                                                           }
                                                                                   }];
    return testPayload;
}

@end
