
#import "UABaseTest.h"
#import "UAAuthTokenManager+Internal.h"
#import "UATestDate.h"
#import "UATestDispatcher.h"

@interface UAAuthTokenManagerTest : UABaseTest
@property(nonatomic, strong) UAAuthTokenManager *manager;
@property(nonatomic, strong) id mockClient;
@property(nonatomic, strong) id mockChannel;
@property(nonatomic, strong) NSString *channelID;
@property(nonatomic, strong) UATestDate *testDate;
@end

@implementation UAAuthTokenManagerTest

- (void)setUp {
    self.mockClient = [self mockForClass:[UAAuthTokenAPIClient class]];
    self.mockChannel = [self mockForClass:[UAChannel class]];

    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&self->_channelID];
    }] identifier];

    self.channelID = @"channel ID";

    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];
    self.manager = [UAAuthTokenManager authTokenManagerWithAPIClient:self.mockClient
                                                             channel:self.mockChannel
                                                                date:self.testDate
                                                          dispatcher:[UATestDispatcher testDispatcher]];
}

- (void)testTokenWithCompletionHandler {
    XCTestExpectation *tokenRetrieved = [self expectationWithDescription:@"token retrieved"];

    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAAuthTokenResponse * _Nullable, NSError * _Nullable) = (__bridge void(^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))arg;
        UAAuthToken *token = [UAAuthToken authTokenWithChannelID:self.channelID token:@"token" expiration:[NSDate distantFuture]];
        UAAuthTokenResponse *response = [[UAAuthTokenResponse alloc] initWithStatus:200 authToken:token];
        completionHandler(response, nil);
    }] tokenWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            [tokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];
}

- (void)testTokenWithCompletionHandlerNilChannelID {
    self.channelID = nil;
    XCTestExpectation *tokenRetrieved = [self expectationWithDescription:@"token retrieved"];

    [[self.mockClient reject] tokenWithChannelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (!token) {
            [tokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];
}

- (void)testTokenWithCompletionHandlerCachesTokens {
    XCTestExpectation *firstTokenRetrieved = [self expectationWithDescription:@"first token retrieved"];

    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAAuthTokenResponse * _Nullable, NSError * _Nullable) = (__bridge void(^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))arg;
        UAAuthToken *token = [UAAuthToken authTokenWithChannelID:self.channelID token:@"token" expiration:[NSDate distantFuture]];
        UAAuthTokenResponse *response = [[UAAuthTokenResponse alloc] initWithStatus:200 authToken:token];
        completionHandler(response, nil);
    }] tokenWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    __block NSString *firstToken;

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            firstToken = token;
            [firstTokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];

    XCTestExpectation *secondTokenRetrieved = [self expectationWithDescription:@"second token retrieved"];

    // On the subsequent lookup the token should be cached
    [[self.mockClient reject] tokenWithChannelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block NSString *secondToken;

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            secondToken = token;
            [secondTokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];

    XCTAssertEqualObjects(firstToken, secondToken);
}

- (void)testTokenWithCompletionHandlerError {
    XCTestExpectation *tokenRetrieved = [self expectationWithDescription:@"first token retrieved"];

    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAAuthToken * _Nullable, NSError * _Nullable) = (__bridge void(^)(UAAuthToken * _Nullable, NSError * _Nullable))arg;
        completionHandler(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{}]);
    }] tokenWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (!token) {
            [tokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];
}

- (void)testTokenWithCompletionHandlerCachedTokenExpired {
    XCTestExpectation *firstTokenRetrieved = [self expectationWithDescription:@"first token retrieved"];

    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAAuthTokenResponse * _Nullable, NSError * _Nullable) = (__bridge void(^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))arg;
        UAAuthToken *token = [UAAuthToken authTokenWithChannelID:self.channelID token:@"token"
                                                      expiration:[NSDate dateWithTimeInterval:24 * 60 * 60
                                                                                    sinceDate:self.testDate.now]];
        UAAuthTokenResponse *response = [[UAAuthTokenResponse alloc] initWithStatus:200 authToken:token];
        completionHandler(response, nil);
    }] tokenWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    __block NSString *firstToken;

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            firstToken = token;
            [firstTokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];

    XCTestExpectation *secondTokenRetrieved = [self expectationWithDescription:@"second token retrieved"];

    // Invalidate the cache "naturally"
    [self.testDate setAbsoluteTime:[NSDate dateWithTimeInterval:24 * 60 * 60 * 2
                                                      sinceDate:self.testDate.now]];

    // On the subsequent lookup the token should be re-fetched
    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAAuthTokenResponse * _Nullable, NSError * _Nullable) = (__bridge void(^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))arg;
        UAAuthToken *token = [UAAuthToken authTokenWithChannelID:self.channelID token:@"some other token" expiration:[NSDate distantFuture]];
        UAAuthTokenResponse *response = [[UAAuthTokenResponse alloc] initWithStatus:200 authToken:token];
        completionHandler(response, nil);
    }] tokenWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    __block NSString *secondToken;

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            secondToken = token;
            [secondTokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];

    XCTAssertNotEqualObjects(firstToken, secondToken);
}

- (void)testExpireToken {
    XCTestExpectation *firstTokenRetrieved = [self expectationWithDescription:@"first token retrieved"];

    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAAuthTokenResponse * _Nullable, NSError * _Nullable) = (__bridge void(^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))arg;
        UAAuthToken *token = [UAAuthToken authTokenWithChannelID:self.channelID token:@"token" expiration:[NSDate distantFuture]];
        UAAuthTokenResponse *response = [[UAAuthTokenResponse alloc] initWithStatus:200 authToken:token];
        completionHandler(response, nil);
    }] tokenWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    __block NSString *firstToken;

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            firstToken = token;
            [firstTokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];

    XCTestExpectation *secondTokenRetrieved = [self expectationWithDescription:@"second token retrieved"];

    // Invalidate the token manually
    [self.manager expireToken:firstToken];

    // On the subsequent lookup the token should be re-fetched
    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAAuthTokenResponse * _Nullable, NSError * _Nullable) = (__bridge void(^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))arg;
        UAAuthToken *token = [UAAuthToken authTokenWithChannelID:self.channelID token:@"some other token" expiration:[NSDate distantFuture]];
        UAAuthTokenResponse *response = [[UAAuthTokenResponse alloc] initWithStatus:200 authToken:token];
        completionHandler(response, nil);
    }] tokenWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    __block NSString *secondToken;

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            secondToken = token;
            [secondTokenRetrieved fulfill];
        }
    }];

    [self waitForTestExpectations];

    XCTAssertNotEqualObjects(firstToken, secondToken);
}

- (void)testTokenWithCompletionHandlerQueueing {
    XCTestExpectation *tokenRetrieved = [self expectationWithDescription:@"token retrieved"];
    XCTestExpectation *tokenRetrievedAgain = [self expectationWithDescription:@"token retrieved"];

    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAAuthTokenResponse * _Nullable, NSError * _Nullable) = (__bridge void(^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))arg;
        UAAuthToken *token = [UAAuthToken authTokenWithChannelID:self.channelID token:@"token" expiration:[NSDate distantFuture]];
        UAAuthTokenResponse *response = [[UAAuthTokenResponse alloc] initWithStatus:200 authToken:token];
        completionHandler(response, nil);
    }] tokenWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    [[self.mockClient reject] tokenWithChannelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block NSString *token1;
    __block NSString *token2;

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            token1 = token;
            [tokenRetrieved fulfill];
        }
    }];

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            token2 = token;
            [tokenRetrievedAgain fulfill];
        }
    }];

    [self waitForTestExpectations];
    [self.mockClient verify];

    XCTAssertEqualObjects(token1, token2);
}

- (void)testExpireTokenQueueing {
    XCTestExpectation *firstTokenRetrieved = [self expectationWithDescription:@"first token retrieved"];

    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAAuthTokenResponse * _Nullable, NSError * _Nullable) = (__bridge void(^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))arg;
        UAAuthToken *token = [UAAuthToken authTokenWithChannelID:self.channelID token:@"token" expiration:[NSDate dateWithTimeInterval:24 * 60 * 60
                                                                                                                             sinceDate:self.testDate.now]];
        UAAuthTokenResponse *response = [[UAAuthTokenResponse alloc] initWithStatus:200 authToken:token];
        completionHandler(response, nil);
    }] tokenWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    __block NSString *firstToken;

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            firstToken = token;
            [firstTokenRetrieved fulfill];
        }
    }];

    // Allow the request to complete
    [self waitForTestExpectations];

    // Make the cached auth naturally expired
    self.testDate.absoluteTime = [NSDate dateWithTimeInterval:24 * 60 * 60 * 2
                                                    sinceDate:self.testDate.now];

    __block NSString *secondToken;

    XCTestExpectation *secondTokenRetrieved = [self expectationWithDescription:@"second token retrieved"];

    // On the subsequent lookup the token should be re-fetched
    [[[self.mockClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAAuthTokenResponse * _Nullable, NSError * _Nullable) = (__bridge void(^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))arg;

        // Complete with a fresh token
        UAAuthToken *token = [UAAuthToken authTokenWithChannelID:self.channelID token:@"some other token" expiration:[NSDate dateWithTimeInterval:24 * 60 * 60 * 3
                                                                                                                                        sinceDate:self.testDate.now]];
        UAAuthTokenResponse *response = [[UAAuthTokenResponse alloc] initWithStatus:200 authToken:token];
        completionHandler(response, nil);
    }] tokenWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    [self.manager tokenWithCompletionHandler:^(NSString * _Nullable token) {
        if (token) {
            secondToken = token;
            [secondTokenRetrieved fulfill];
        }
    }];

    // Try to expire the first token in the meanwhile
    [self.manager expireToken:firstToken];

    [self waitForTestExpectations];

    XCTAssertNotNil(secondToken);
    XCTAssertNotEqualObjects(firstToken, secondToken);
}

@end
