/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UARemoteDataStoreTest : UABaseTest
@property UARemoteDataStore *remoteDataStore;
@end

@implementation UARemoteDataStoreTest

- (void)setUp {
    [super setUp];
    self.remoteDataStore = [[UARemoteDataStore alloc] initWithStoreName:self.name inMemory:YES];
}

- (void)tearDown {
    [self.remoteDataStore shutDown];
    [super tearDown];
}

- (void)testFirstRemoteData {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"fetched remote data"];
    
    UARemoteDataPayload *testPayload = [self createRemoteDataPayload];
    [self.remoteDataStore overwriteCachedRemoteData:@[testPayload]
                            completionHandler:^(BOOL success) {
                                XCTAssertTrue(success);
                            }];
    
    [self.remoteDataStore fetchRemoteDataFromCacheWithPredicate:nil
                              completionHandler:^(NSArray<UARemoteDataPayload *> *remoteDataStorePayloads) {
                                  XCTAssertEqual(1, remoteDataStorePayloads.count);
                                  UARemoteDataPayload *dataStorePayload = remoteDataStorePayloads[0];
                                  XCTAssertEqualObjects(testPayload.type, dataStorePayload.type);
                                  XCTAssertEqualObjects(testPayload.timestamp, dataStorePayload.timestamp);
                                  XCTAssertEqualObjects(testPayload.data, dataStorePayload.data);
                                  XCTAssertEqualObjects(testPayload.metadata, dataStorePayload.metadata);

                                  [testExpectation fulfill];
                              }];
    
    [self waitForTestExpectations];
}

- (void)testNewRemoteData {
    NSArray<UARemoteDataPayload *> *testPayloads = @[ [self createRemoteDataPayload],
                                                      [self createRemoteDataPayload],
                                                      [self createRemoteDataPayload] ];
    
    [self.remoteDataStore overwriteCachedRemoteData:testPayloads
                                   completionHandler:^(BOOL success) {
                                       XCTAssertTrue(success);
                                   }];

    // Verify we have 3 messages
    XCTestExpectation *firstFetch = [self expectationWithDescription:@"fetched first round of remote data"];
    [self.remoteDataStore fetchRemoteDataFromCacheWithPredicate:nil
                                     completionHandler:^(NSArray<UARemoteDataPayload *> *remoteDataStorePayloads) {
                                         XCTAssertEqual(testPayloads.count, remoteDataStorePayloads.count);
                                         for (UARemoteDataPayload *testPayload in testPayloads) {
                                             BOOL matchedPayloadTypes = NO;
                                             for (UARemoteDataPayload *dataStorePayload in remoteDataStorePayloads) {
                                                 if ([testPayload.type isEqualToString:dataStorePayload.type]) {
                                                     XCTAssertEqualObjects(testPayload.timestamp, dataStorePayload.timestamp);
                                                     XCTAssertEqualObjects(testPayload.data, dataStorePayload.data);
                                                     XCTAssertEqualObjects(testPayload.metadata, dataStorePayload.metadata);
                                                     matchedPayloadTypes = YES;
                                                 }
                                             }
                                             XCTAssertTrue(matchedPayloadTypes);
                                         }
                                         [firstFetch fulfill];
                                     }];
    
    
    // Provide new remote data for one of the payload types
    UARemoteDataPayload *testPayload = [self createRemoteDataPayloadWithType:testPayloads[1].type];

    // Sync only the modified message
    [self.remoteDataStore overwriteCachedRemoteData:@[testPayload]
                                   completionHandler:^(BOOL success) {
                                       XCTAssertTrue(success);
                            }];
    
    // Verify we only have the modified message with the updated title
    XCTestExpectation *secondFetch = [self expectationWithDescription:@"fetched second round of remote data"];
    [self.remoteDataStore fetchRemoteDataFromCacheWithPredicate:nil
                                     completionHandler:^(NSArray<UARemoteDataPayload *> *remoteDataStorePayloads) {
                                         XCTAssertEqual(1, remoteDataStorePayloads.count);
                                         UARemoteDataPayload *dataStorePayload = remoteDataStorePayloads[0];
                                         XCTAssertEqualObjects(testPayload.type, dataStorePayload.type);
                                         XCTAssertEqualObjects(testPayload.timestamp, dataStorePayload.timestamp);
                                         XCTAssertEqualObjects(testPayload.data, dataStorePayload.data);
                                         XCTAssertEqualObjects(testPayload.metadata, dataStorePayload.metadata);
                                         
                                         [secondFetch fulfill];
                                     }];
    
    [self waitForTestExpectations];
}

- (UARemoteDataPayload *)createRemoteDataPayload {
    return [self createRemoteDataPayloadWithType:nil];
}

- (UARemoteDataPayload *)createRemoteDataPayloadWithType:(NSString *)type {
    NSString *payloadType = type ?: [[NSProcessInfo processInfo] globallyUniqueString];
    UARemoteDataPayload *testPayload = [[UARemoteDataPayload alloc] initWithType:payloadType
                                                                       timestamp:[NSDate date]
                                                                            data:@{
                                                                                   @"message_center":  @{
                                                                                           @"background_color": [[NSProcessInfo processInfo] globallyUniqueString],
                                                                                           @"font": [[NSProcessInfo processInfo] globallyUniqueString]
                                                                                           }
                                                                                   }
                                                                        metadata:@{@"cool" : @"story"}];
    return testPayload;
}

@end
