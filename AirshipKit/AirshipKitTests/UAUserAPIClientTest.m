/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAUserAPIClient+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAUtils+Internal.h"
#import "UARuntimeConfig.h"
#import "UAirship+Internal.h"
#import "UAUserAPIClient+Internal.h"
#import "UAUser+Internal.h"
#import "UAUserData.h"
#import "UAJSONSerialization+Internal.h"

@interface UAUserAPIClientTest : UABaseTest
@property (nonatomic, strong) UAUserAPIClient *client;
@property (nonatomic, strong) id mockRequest;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) id mockUAUtils;
@property (nonatomic, strong) id mockUser;

@end

@implementation UAUserAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];

    self.mockRequest = [self mockForClass:[UARequest class]];
    self.client = [UAUserAPIClient clientWithConfig:self.config session:self.mockSession];

    self.mockUAUtils = [self mockForClass:[UAUtils class]];

    [[[self.mockUAUtils stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(NSString *)  = (__bridge void (^)(NSString *)) arg;
        completionHandler(@"deviceID");
    }] getDeviceID:OCMOCK_ANY dispatcher:OCMOCK_ANY] ;

    self.mockUser = [self mockForClass:[UAUser class]];

    UAUserData *userData = [UAUserData dataWithUsername:@"username" password:@"password" url:@"url"];

    [[[self.mockUser stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAUserData * _Nullable) = (__bridge void (^)(UAUserData * _Nullable)) arg;
        completionHandler(userData);
    }] getUserData:OCMOCK_ANY];
}

- (void)tearDown {
    [self.mockRequest stopMocking];
    [self.mockUAUtils stopMocking];
    [self.mockUser stopMocking];
    [self.mockSession stopMocking];

    [super tearDown];
}

/**
 * Test create user retry
 */
-(void)testCreateUserRetry {
    // Check that the retry block returns YES for any 5xx request other than 501
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            if (!retryBlock(OCMOCK_ANY, response)) {
                return NO;
            }
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(OCMOCK_ANY, response)) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data, NSDictionary *payload){
                                   XCTFail(@"Should not be called");
                               }
                               onFailure:^(NSUInteger statusCode){
                                   XCTFail(@"Should not be called");
                               }];


    XCTAssertNoThrow([self.mockSession verify], @"Create user should call retry on 5xx status codes");
}

/**
 * Test create user success
 */
-(void)testCreateUserSuccess {
    // Create a valid response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:201 HTTPVersion:nil headerFields:nil];

    NSDictionary *responseDict = @{@"user_id": @"someUserName", @"password": @"somePassword", @"user_url": @"http://url.com"};

    NSData *responseData =  [UAJSONSerialization dataWithJSONObject:responseDict
                                                            options:0
                                                              error:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    __block UAUserData *successData;

    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data, NSDictionary *payload){
                                   successData = data;
                               }
                               onFailure:^(NSUInteger statusCode){
                                   XCTFail(@"Should not be called");
                               }];

    XCTAssertNoThrow([self.mockSession verify], @"Create user should succeed on 201.");

    XCTAssertEqualObjects(successData.username, [responseDict valueForKey:@"user_id"]);
    XCTAssertEqualObjects(successData.password, [responseDict valueForKey:@"password"]);
    XCTAssertEqualObjects(successData.url, [responseDict valueForKey:@"user_url"]);
}

/**
 * Test create user failure
 */
-(void)testCreateUserFailure {
    // Create a valid response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];

    NSDictionary *responseDict = @{@"user_id": @"someUserName", @"password": @"somePassword", @"user_url": @"http://url.com"};

    NSData *responseData =  [UAJSONSerialization dataWithJSONObject:responseDict
                                                            options:0
                                                              error:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    __block NSUInteger failureStatusCode = 0;

    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data, NSDictionary *payload){
                                   XCTFail(@"Should not be called");
                               }
                               onFailure:^(NSUInteger statusCode){
                                   failureStatusCode = statusCode;
                               }];

    XCTAssertNoThrow([self.mockSession verify], @"Create user should fail on 400.");

    XCTAssertEqual(failureStatusCode, 400);
}

/**
 * Test create user request with a channel ID
 */
-(void)testCreateUserRequestChannelID {
    NSDictionary *expectedRequestBody = @{@"ua_device_id": @"deviceID", @"ios_channels": @[@"channelID"]};

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // Check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://device-api.urbanairship.com/api/user/"]) {
            return NO;
        }

        // Check that it's a POST
        if (![request.method isEqualToString:@"POST"]) {
            return NO;
        }

        // Check that it contains an accept header
        if (![[request.headers valueForKey:@"Accept"] isEqualToString:@"application/vnd.urbanairship+json; version=3;"]) {
            return NO;
        }

        // Check that it contains an content type header
        if (![[request.headers valueForKey:@"Content-Type"] isEqualToString:@"application/json"]) {
            return NO;
        }

        if (![request.body isEqualToData:[UAJSONSerialization dataWithJSONObject:expectedRequestBody options:0 error:nil]]) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];


    [self.client createUserWithChannelID:@"channelID" onSuccess:^(UAUserData * _Nonnull data, NSDictionary * _Nonnull payload) {
    } onFailure:^(NSUInteger statusCode) {
    }];
    
    [self.mockSession verify];
}

/**
 * Test update user retry
 */
-(void)testUpdateUserRetry {
    // Check that the retry block returns YES for any 5xx request other than 501
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            if (!retryBlock(OCMOCK_ANY, response)) {
                return NO;
            }
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(OCMOCK_ANY, response)) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client updateUser:self.mockUser
                  channelID:@"channelID"
                  onSuccess:^(){
                      XCTFail(@"Should not be called");
                  }
                  onFailure:^(NSUInteger statusCode){
                      XCTFail(@"Should not be called");
                  }];


    XCTAssertNoThrow([self.mockSession verify], @"Update user should call retry on 5xx status codes");
}

/**
 * Test update user success
 */
-(void)testUpdateUserSuccess {
    // Create a valid response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];

    NSDictionary *responseDict = @{@"user_id": @"someUserName", @"password": @"somePassword", @"user_url": @"http://url.com"};

    NSData *responseData =  [UAJSONSerialization dataWithJSONObject:responseDict
                                                            options:0
                                                              error:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    __block BOOL successBlockCalled = false;

    [self.client updateUser:self.mockUser
                  channelID:@"channelID"
                  onSuccess:^(){
                      successBlockCalled = YES;
                  }
                  onFailure:^(NSUInteger statusCode){
                      XCTFail(@"Should not be called");
                  }];

    XCTAssertNoThrow([self.mockSession verify], @"Update user should succeed on 200.");

    XCTAssertTrue(successBlockCalled);
}

/**
 * Test update user failure
 */
-(void)testUpdateUserFailure {
    // Create a valid response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];

    NSDictionary *responseDict = @{@"user_id": @"someUserName", @"password": @"somePassword", @"user_url": @"http://url.com"};

    NSData *responseData =  [UAJSONSerialization dataWithJSONObject:responseDict
                                                            options:0
                                                              error:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    __block NSUInteger failureStatusCode = 0;

    [self.client updateUser:self.mockUser
                  channelID:@"channelID"
                  onSuccess:^(){
                      XCTFail(@"Should not be called");
                  }
                  onFailure:^(NSUInteger statusCode){
                      failureStatusCode = statusCode;
                  }];

    XCTAssertNoThrow([self.mockSession verify], @"Update user should fail on 400.");

    XCTAssertEqual(failureStatusCode, 400);
}

/**
 * Test update user request payload adds the right things.
 */
-(void)testUpdateUserRequest {
    NSDictionary *expectedRequestBody = @{@"ios_channels": @{@"add" : @[@"channelID"]}};


    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // Check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://device-api.urbanairship.com/api/user/username/"]) {
            return NO;
        }

        // Check that it's a POST
        if (![request.method isEqualToString:@"POST"]) {
            return NO;
        }

        // Check that it contains an accept header
        if (![[request.headers valueForKey:@"Accept"] isEqualToString:@"application/vnd.urbanairship+json; version=3;"]) {
            return NO;
        }

        // Check that it contains an content type header
        if (![[request.headers valueForKey:@"Content-Type"] isEqualToString:@"application/json"]) {
            return NO;
        }

        if (![request.body isEqualToData:[UAJSONSerialization dataWithJSONObject:expectedRequestBody options:0 error:nil]]) {
            return NO;
        }

        return YES;
    };

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://device-api.urbanairship.com/api/user/username/"]
                                                                  statusCode:200 HTTPVersion:@"1.1"
                                                                headerFields:nil];
        completionHandler(nil, (NSURLResponse *)response, nil);
    }] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock] retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"update succeeded"];

    [self.client updateUser:self.mockUser channelID:@"channelID" onSuccess:^() {
        [expectation fulfill];
    } onFailure:^(NSUInteger statusCode) {
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
    [self.mockSession verify];
}

@end
