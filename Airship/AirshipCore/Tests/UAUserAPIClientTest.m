/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAUserAPIClient+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAUtils+Internal.h"
#import "UARuntimeConfig.h"
#import "UAirship+Internal.h"
#import "UAUserAPIClient+Internal.h"
#import "UAUser+Internal.h"
#import "UAUserData+Internal.h"
#import "UAJSONSerialization.h"

@interface UAUserAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) UAUserAPIClient *client;
@property (nonatomic, strong) id mockRequest;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) UAUserData *userData;
@end

@implementation UAUserAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];

    self.mockRequest = [self mockForClass:[UARequest class]];
    self.client = [UAUserAPIClient clientWithConfig:self.config session:self.mockSession];

    self.userData = [UAUserData dataWithUsername:@"username" password:@"password"];
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
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createUserWithChannelID:@"channelID"
                               onSuccess:^(UAUserData *data){

        XCTAssertEqualObjects(data.username, [responseDict valueForKey:@"user_id"]);
        XCTAssertEqualObjects(data.password, [responseDict valueForKey:@"password"]);
        [callbackCalled fulfill];
    } onFailure:^(NSUInteger statusCode){
        XCTFail(@"Should not be called");
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
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
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createUserWithChannelID:@"channelID" onSuccess:^(UAUserData *data) {
        XCTFail(@"Should not be called");
    } onFailure:^(NSUInteger statusCode) {
        XCTAssertEqual(statusCode, 400);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    XCTAssertNoThrow([self.mockSession verify], @"Create user should fail on 400.");
}

/**
 * Test create user request with a channel ID
 */
-(void)testCreateUserRequestChannelID {
    NSDictionary *expectedRequestBody = @{@"ios_channels": @[@"channelID"]};

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


    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock] completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createUserWithChannelID:@"channelID" onSuccess:^(UAUserData * _Nonnull data) {
    } onFailure:^(NSUInteger statusCode) {
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
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
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateUserWithData:self.userData channelID:@"channelID" onSuccess:^(){
        [callbackCalled fulfill];
    } onFailure:^(NSUInteger statusCode){
        XCTFail(@"Should not be called");
    }];

    [self waitForTestExpectations];
    XCTAssertNoThrow([self.mockSession verify], @"Update user should succeed on 200.");

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
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateUserWithData:self.userData channelID:@"channelID" onSuccess:^(){
        XCTFail(@"Should not be called");
    } onFailure:^(NSUInteger statusCode){
        XCTAssertEqual(statusCode, 400);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    XCTAssertNoThrow([self.mockSession verify], @"Update user should fail on 400.");
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
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://device-api.urbanairship.com/api/user/username/"]
                                                                  statusCode:200 HTTPVersion:@"1.1"
                                                                headerFields:nil];
        completionHandler(nil, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock] completionHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"update succeeded"];

    [self.client updateUserWithData:self.userData channelID:@"channelID" onSuccess:^() {
        [expectation fulfill];
    } onFailure:^(NSUInteger statusCode) {
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    [self.mockSession verify];
}

@end


