/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import <Foundation/Foundation.h>
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAChannelAPIClient+Internal.h"
#import "UAirship.h"
#import "UARuntimeConfig.h"
#import "UAAnalytics+Internal.h"

@interface UAChannelAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) UAChannelAPIClient *client;
@end

@implementation UAChannelAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.client = [UAChannelAPIClient clientWithConfig:self.config session:self.mockSession];
}

- (void)testCreateChannel {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{ \"ok\":true, \"channel_id\": \"someChannelID\"}" dataUsingEncoding:NSUTF8StringEncoding];
    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://device-api.urbanairship.com/api/channels/"]) {
            return NO;
        }

        // check that its a POST
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

        if (![request.body isEqualToData:[payload asJSONData]]) {
            return NO;
        }

        // Check the body contains the payload
        return YES;
    };

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock] completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:payload
                        completionHandler:^(UAChannelCreateResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqualObjects(@"someChannelID", response.channelID);
        XCTAssertEqual(200, response.status);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testCreateChannelParseError {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{ \"ok\":true }" dataUsingEncoding:NSUTF8StringEncoding];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                        completionHandler:^(UAChannelCreateResponse *response, NSError *error){
        XCTAssertNotNil(error);
        XCTAssertNil(response);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCreateChannelFailure {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:@{}];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                        completionHandler:^(UAChannelCreateResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertNil(response.channelID);
        XCTAssertEqual(400, response.status);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testCreateChannelError {
    NSError *responseError = [[NSError alloc] initWithDomain:@"neat" code:1 userInfo:nil];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, responseError);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                        completionHandler:^(UAChannelCreateResponse *response, NSError *error){
        XCTAssertEqual(responseError, error);
        XCTAssertNil(response);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testUpdateChannel {
    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://device-api.urbanairship.com/api/channels/someChannelID"]) {
            return NO;
        }

        // check that its a POST
        if (![request.method isEqualToString:@"PUT"]) {
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

        if (![request.body isEqualToData:[payload asJSONData]]) {
            return NO;
        }

        // Check the body contains the payload
        return YES;
    };

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock] completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateChannelWithID:@"someChannelID"
                         withPayload:[[UAChannelRegistrationPayload alloc] init]
                   completionHandler:^(UAHTTPResponse *response, NSError * _Nullable error) {
        XCTAssertEqual(200, response.status);
        XCTAssertNil(error);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testUpdateChannelFailure {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:@{}];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateChannelWithID:@"some-payload"
                         withPayload:[[UAChannelRegistrationPayload alloc] init]
                   completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqual(400, response.status);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testUpdateChannelError {
    NSError *responseError = [[NSError alloc] initWithDomain:@"neat" code:1 userInfo:nil];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, responseError);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateChannelWithID:@"some-payload"
                         withPayload:[[UAChannelRegistrationPayload alloc] init]
                   completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertEqual(responseError, error);
        XCTAssertNil(response);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

@end

