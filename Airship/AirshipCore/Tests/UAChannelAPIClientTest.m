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

/**
 * Test create channel calls the onSuccessBlock with the response channel ID
 * and makes an analytics request when the request is successful.
 */
- (void)testCreateChannelOnSuccess {

    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{ \"ok\":true, \"channel_id\": \"someChannelID\"}" dataUsingEncoding:NSUTF8StringEncoding];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                        completionHandler:^(NSString *channelID, BOOL existing, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqualObjects(@"someChannelID", channelID);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test create channel calls the onFailureBlock with the status code when
 * the request fails.
 */
- (void)testCreateChannelOnFailure {

    // Create a failure response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];

    // Stub the session to return a the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                        completionHandler:^(NSString *channelID, BOOL existing, NSError *error){
        XCTAssertEqualObjects(error.domain, UAChannelAPIClientErrorDomain);
        XCTAssertEqual(error.code, UAChannelAPIClientErrorUnsuccessfulStatus);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test the request headers and body for a create channel request
 */
- (void)testCreateChannelRequest {

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
        completionHandler(nil, nil, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                        completionHandler:^(NSString *channelID, BOOL existing, NSError *error){
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

/**
 * Test update channel completes with no errors on success
 */
- (void)testUpdateChannelSuccess {
    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{ \"ok\":true, \"channel_id\": \"someChannelID\"}" dataUsingEncoding:NSUTF8StringEncoding];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateChannelWithID:@"someChannelID"
                         withPayload:[[UAChannelRegistrationPayload alloc] init]
                   completionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test update channel completes with an unsuccessful status error on non-conflict failures
 */
- (void)testUpdateChannelFailure {

    // Create a failure response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];

    // Stub the session to return a the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateChannelWithID:@"someChannelID"
                         withPayload:[[UAChannelRegistrationPayload alloc] init]
                   completionHandler:^(NSError * _Nullable error) {
        XCTAssertEqualObjects(error.domain, UAChannelAPIClientErrorDomain);
        XCTAssertEqual(error.code, UAChannelAPIClientErrorUnsuccessfulStatus);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
}

/**
 * Test update channel completes with a conflict error on HTTP conflict
 */
- (void)testUpdateChannelFailureConflict {

    // Create a failure response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:409 HTTPVersion:nil headerFields:nil];

    // Stub the session to return a the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateChannelWithID:@"someChannelID"
                         withPayload:[[UAChannelRegistrationPayload alloc] init]
                   completionHandler:^(NSError * _Nullable error) {
        XCTAssertEqualObjects(error.domain, UAChannelAPIClientErrorDomain);
        XCTAssertEqual(error.code, UAChannelAPIClientErrorConflict);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];

}

/**
 * Test the request headers and body for an update channel request
 */
- (void)testUpdateChannelRequest {

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

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock] completionHandler:OCMOCK_ANY];

    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called"];
    [self.client updateChannelWithID:@"someChannelID"
                         withPayload:[[UAChannelRegistrationPayload alloc] init]
                   completionHandler:^(NSError * _Nullable error) {
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

@end


