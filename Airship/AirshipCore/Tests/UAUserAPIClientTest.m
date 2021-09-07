/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAUserAPIClient+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAUserAPIClient+Internal.h"
#import "UAUser+Internal.h"
#import "UAUserData+Internal.h"

@import AirshipCore;


typedef void (^UAHTTPRequestCompletionHandler)(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error);

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

- (void)testCreateUser {
    // Create a valid response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:201 HTTPVersion:nil headerFields:nil];

    NSDictionary *responseDict = @{@"user_id": @"someUserName", @"password": @"somePassword", @"user_url": @"http://url.com"};

    NSData *responseData =  [UAJSONSerialization dataWithJSONObject:responseDict
                                                            options:0
                                                              error:nil];

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // Check the url
        if (![[request.url absoluteString] isEqualToString:@"https://device-api.urbanairship.com/api/user/"]) {
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

        if (![request.body isEqualToData:[UAJSONSerialization dataWithJSONObject:@{@"ios_channels": @[@"channelID"]} options:0 error:nil]]) {
            return NO;
        }

        return YES;
    };

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock] completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createUserWithChannelID:@"channelID"
                       completionHandler:^(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(response.userData.username, [responseDict valueForKey:@"user_id"]);
        XCTAssertEqualObjects(response.userData.password, [responseDict valueForKey:@"password"]);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testCreateUserFailureUnrecoverableStatus {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:400
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];

    [self.client createUserWithChannelID:@"channelID" completionHandler:^(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(response.status, 400);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testCreateUserFailureRecoverableStatus {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:500
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];

    [self.client createUserWithChannelID:@"channelID" completionHandler:^(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(response.status, 500);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testCreateUserFailureJSONParseError {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    NSDictionary *responseDict = @{};

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

    [self.client createUserWithChannelID:@"channelID" completionHandler:^(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNotNil(response);
        XCTAssertNotNil(error);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testCreateUserFailureSessionError {
    NSError *error = [NSError errorWithDomain:@"some-domain" code:100 userInfo:@{}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, error);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];

    [self.client createUserWithChannelID:@"channelID" completionHandler:^(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

-(void)testUpdateUser {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // Check the url
        if (![[request.url absoluteString] isEqualToString:@"https://device-api.urbanairship.com/api/user/username/"]) {
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

        if (![request.body isEqualToData:[UAJSONSerialization dataWithJSONObject:@{@"ios_channels": @{@"add" : @[@"channelID"]}} options:0 error:nil]]) {
            return NO;
        }

        return YES;
    };

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock] completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];

    [self.client updateUserWithData:self.userData channelID:@"channelID" completionHandler:^(UAHTTPResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertEqual(response.status, 200);
        XCTAssertNil(error);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testUpdateUserFailureUnrecoverableStatus {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:400
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];

    [self.client updateUserWithData:self.userData channelID:@"channelID" completionHandler:^(UAHTTPResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(response.status, 400);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testUpdateUserFailureRecoverableStatus {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:500
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];

    [self.client updateUserWithData:self.userData channelID:@"channelID" completionHandler:^(UAHTTPResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(response.status, 500);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testUpdateUserFailureSessionError {
    NSError *error = [NSError errorWithDomain:@"some-domain" code:100 userInfo:@{}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, error);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];

    [self.client updateUserWithData:self.userData channelID:@"channelID" completionHandler:^(UAHTTPResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertNil(response);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

@end


