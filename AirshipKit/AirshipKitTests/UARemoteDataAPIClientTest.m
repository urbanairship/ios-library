/* Copyright 2018 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UABaseTest.h"
#import "UAConfig.h"
#import "UARequestSession+Internal.h"
#import "UARemoteDataAPIClient+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAirshipVersion.h"

@interface UARemoteDataAPIClientTest : UABaseTest

@property (nonatomic, strong) UARemoteDataAPIClient *remoteDataAPIClient;
@property (nonatomic, strong) UAConfig *config;

@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) id mockSessionClass;
@property (nonatomic, strong) id mockDataStore;

@end

@implementation UARemoteDataAPIClientTest

- (void)setUp {
    [super setUp];
    
    self.config = [UAConfig config];
    self.config.developmentAppKey = @"appKey";
    self.config.inProduction = NO;

    self.mockSession = [OCMockObject niceMockForClass:[UARequestSession class]];
    self.mockDataStore = [OCMockObject niceMockForClass:[UAPreferenceDataStore class]];
    self.mockSessionClass = OCMClassMock([UARequestSession class]);
    [[[self.mockSessionClass stub] andReturn:self.mockSession] sessionWithConfig:OCMOCK_ANY];
    
    self.remoteDataAPIClient = [UARemoteDataAPIClient clientWithConfig:self.config dataStore:self.mockDataStore];
    
}

- (void)tearDown {
    [self.mockDataStore stopMocking];
    [self.mockSession stopMocking];

    [super tearDown];
}

/**
 * Test refreshing the remote data
 */
- (void)testRefreshRemoteData {
    
    // Create a successful response
    NSDictionary *remoteDataDict = @{ @"type": @"test_data_type",
                                      @"timestamp":@"2017-01-01T12:00:00",
                                      @"data": @{ @"message_center" :
                                                      @{ @"background_color" : @"0000FF",
                                                         @"font" : @"Comic Sans"
                                                        }
                                                  }
                                        };
    NSData *responseData = [self createRemoteDataFromDictionaries:@[remoteDataDict]];
    NSString *expectedLastModifiedTimestamp = remoteDataDict[@"timestamp"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{@"Last-Modified":expectedLastModifiedTimestamp}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        
        // delay call back a bit to simulate actually going to the cloud
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(responseData, (NSURLResponse *)response, nil);
        });
    }] dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;
        NSString *expected = [NSString stringWithFormat:@"https://remote-data.urbanairship.com/api/remote-data/app/appKey/ios?sdk_version=%@", [UAirshipVersion get]];

        return [[request.URL absoluteString] isEqualToString:expected];
    }] retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    
    // Make call
    [self.remoteDataAPIClient fetchRemoteData:^(NSUInteger statusCode, NSArray<NSDictionary *> *remoteData) {
        XCTAssertEqual(statusCode, 200);
        XCTAssertTrue([remoteData count] == 1, @"There should be exactly 1 payload");
        XCTAssertTrue([remoteData[0][@"type"] isEqualToString:remoteDataDict[@"type"]]);
        XCTAssertEqualObjects(remoteData[0][@"data"], remoteDataDict[@"data"], @"Remote data should match");
        [refreshFinished fulfill];
    } onFailure:^() {
        XCTFail(@"Should not fail");
        [refreshFinished fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockSession verify];
    }];
    
}

/**
 * Test refreshing the remote data, but cancel the callbacks
 */
- (void)testRefreshRemoteDataButCancelCallbacks {
    
    // Create a successful response
    NSDictionary *remoteDataDict = @{ @"type": @"test_data_type",
                                      @"timestamp":@"2017-01-01T12:00:00",
                                      @"data": @{ @"message_center" :
                                                      @{ @"background_color" : @"0000FF",
                                                         @"font" : @"Comic Sans"
                                                         }
                                                  }
                                      };
    NSData *responseData = [self createRemoteDataFromDictionaries:@[remoteDataDict]];
    NSString *expectedLastModifiedTimestamp = remoteDataDict[@"timestamp"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{@"Last-Modified":expectedLastModifiedTimestamp}];
    
    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        
        // delay call back a bit to simulate actually going to the cloud
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(responseData, (NSURLResponse *)response, nil);
        });
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    // Make call
    UADisposable *disposable = [self.remoteDataAPIClient fetchRemoteData:^(NSUInteger statusCode, NSArray<NSDictionary *> *remoteData) {
        UA_LDEBUG(@"Callback");
        XCTFail(@"Should not call callbacks");
    } onFailure:^() {
        XCTFail(@"Should not call callbacks");
    }];
    
    [disposable dispose];
    
}

/**
 * Test refreshing the remote data when there are multiple payloads
 */
- (void)testRefreshRemoteDataWithMultiplePayloads {
    
    // Create a successful response
    NSDictionary *remoteDataDict1 = @{ @"type": @"test_data_type",
                                       @"timestamp":@"2017-01-01T12:00:00",
                                       @"data": @{ @"message_center" :
                                                      @{ @"background_color" : @"0000FF",
                                                         @"font" : @"Comic Sans"
                                                         }
                                                  }
                                      };
    NSDictionary *remoteDataDict2 = @{ @"type": @"test_data_type_2",
                                       @"timestamp":@"2017-01-01T13:00:00",
                                       @"data": @{ @"test-stuff" :
                                                      @{ @"background_color" : @"00FF00",
                                                         @"font" : @"Courier"
                                                         }
                                                  }
                                      };
    NSArray *remoteDataDicts = [NSArray arrayWithObjects:remoteDataDict2,remoteDataDict1, nil];
    NSData *responseData = [self createRemoteDataFromDictionaries:remoteDataDicts];
    NSString *expectedLastModifiedTimestamp = [remoteDataDicts valueForKeyPath:@"@max.timestamp"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{@"Last-Modified":expectedLastModifiedTimestamp}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        
        completionHandler(responseData, (NSURLResponse *)response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    
    // Make call
    [self.remoteDataAPIClient fetchRemoteData:^(NSUInteger statusCode, NSArray<NSDictionary *> *remoteData) {
        XCTAssertEqual(statusCode, 200);
        XCTAssertTrue([remoteData count] == 2, @"There should be exactly 2 payloads");
        NSDictionary *testDict1, *testDict2;
        if ([remoteData[0][@"type"] isEqualToString:remoteDataDict1[@"type"]]) {
            testDict1 = remoteData[0];
            testDict2 = remoteData[1];
        } else {
            testDict1 = remoteData[1];
            testDict2 = remoteData[0];
        }
        XCTAssertTrue([testDict1[@"type"] isEqualToString:remoteDataDict1[@"type"]]);
        XCTAssertEqualObjects(testDict1[@"data"], remoteDataDict1[@"data"], @"Remote data should match");
        XCTAssertTrue([testDict2[@"type"] isEqualToString:remoteDataDict2[@"type"]]);
        XCTAssertEqualObjects(testDict2[@"data"], remoteDataDict2[@"data"], @"Remote data should match");
       [refreshFinished fulfill];
    } onFailure:^() {
        XCTFail(@"Should not fail");
        [refreshFinished fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockSession verify];
    }];
    
}

/**
 * Test refreshing the remote data, but it hasn't changed
 */
- (void)testRefreshRemoteDataUnchanged {
    
    // Create a successful response (but not modified)
    NSDictionary *remoteDataDict = @{ @"type": @"test_data_type",
                                       @"timestamp":@"2017-01-01T12:00:00",
                                       @"data": @{ @"message_center" :
                                                       @{ @"background_color" : @"0000FF",
                                                          @"font" : @"Comic Sans"
                                                          }
                                                   }
                                       };
    NSData *responseData = [self createRemoteDataFromDictionaries:@[remoteDataDict]];
    NSString *expectedLastModifiedTimestamp = remoteDataDict[@"timestamp"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:304 HTTPVersion:nil headerFields:@{@"Last-Modified":expectedLastModifiedTimestamp}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        
        completionHandler(responseData, (NSURLResponse *)response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    
    // Make call
    [self.remoteDataAPIClient fetchRemoteData:^(NSUInteger statusCode, NSArray<UARemoteDataPayload *> *remoteData) {
        XCTAssertEqual(statusCode, 304);
        XCTAssertNil(remoteData);
        [refreshFinished fulfill];
    } onFailure:^() {
        XCTFail(@"Should not fail");
        [refreshFinished fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockSession verify];
    }];
    
}

/**
 * Test failure to refresh the remote data because of a gateway timeout
 */
- (void)testFailedRefreshRemoteDataDueToTimeout {
    
    // Create a successful response
    NSDictionary *remoteDataDict = @{ @"message_center" :
                                            @{ @"background_color" : @"0000FF",
                                               @"font" : @"Comic Sans"
                                               }
                                        };
    NSData *responseData = [self createRemoteDataFromDictionary:remoteDataDict ofType:@"test_data_type"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:504 HTTPVersion:nil headerFields:@{}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        
        completionHandler(responseData, (NSURLResponse *)response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    
    // Make call
    [self.remoteDataAPIClient fetchRemoteData:^(NSUInteger statusCode, NSArray<UARemoteDataPayload *> *remoteData) {
        XCTFail(@"Should not succeed");
    } onFailure:^() {
        [refreshFinished fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockSession verify];
    }];
    
}

/**
 * Test refresh the remote data when no remote data returned from cloud
 */
- (void)testRefreshRemoteDataWhenNoData {
    
    // Create a successful response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSDictionary *remoteDataDict = nil;
    
    NSData *responseData = [self createRemoteDataFromDictionary:remoteDataDict ofType:@"abcdefghi"];
    
    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        
        completionHandler(responseData, (NSURLResponse *)response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    
    // Make call
    [self.remoteDataAPIClient fetchRemoteData:^(NSUInteger statusCode, NSArray<UARemoteDataPayload *> *remoteData) {
        XCTAssertEqual(statusCode, 200);
        XCTAssertTrue(!remoteData || [remoteData count] == 0);
        [refreshFinished fulfill];
    } onFailure:^() {
        XCTFail(@"Should not fail");
        [refreshFinished fulfill];
    }];
    
    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockSession verify];
    }];
}

- (NSData *)createRemoteDataFromDictionary:(NSDictionary *)remoteDataDict ofType:(NSString *)type {
    NSDictionary *responseDict;
    if (remoteDataDict) {
        responseDict = @{ @"ok" : @YES,
                          @"payloads" : @[
                                  @{ @"type" : type,
                                     @"timestamp" : @"2017-01-01T12:00:00",
                                     @"data" : remoteDataDict
                                     }
                                  ]
                          };
    } else {
        responseDict = @{ @"ok" : @YES,
                          @"payloads" : @[]
                          };
    }
    NSError *error;
    NSData *remoteData = [NSJSONSerialization dataWithJSONObject:responseDict options:NSJSONWritingPrettyPrinted error:&error];
    
    XCTAssertNil(error,@"Error creating remote data of type %@ from dictionary %@: %@", type, remoteDataDict, error.localizedDescription);
    
    return remoteData;
}

- (NSData *)createRemoteDataFromDictionaries:(NSArray *)remoteDataDicts {
    
    NSMutableArray *payloads = [NSMutableArray array];
    for (NSDictionary *remoteDataDict in remoteDataDicts) {
        [payloads addObject:@{ @"type" : remoteDataDict[@"type"],
                     @"timestamp" : remoteDataDict[@"timestamp"],
                     @"data" : remoteDataDict[@"data"]
                     }
         ];
    }
    
    NSDictionary *responseDict = @{ @"ok" : @YES,
                                    @"payloads" : payloads
                                  };

    NSError *error;
    NSData *remoteData = [NSJSONSerialization dataWithJSONObject:responseDict options:NSJSONWritingPrettyPrinted error:&error];
    
    XCTAssertNil(error,@"Error creating remote data of from array %@: %@", remoteDataDicts, error.localizedDescription);
    
    return remoteData;
}



@end
