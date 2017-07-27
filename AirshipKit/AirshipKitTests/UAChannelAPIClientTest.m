/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import <OCMOCK/OCMock.h>
#import <Foundation/Foundation.h>
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAChannelAPIClient+Internal.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAAnalytics+Internal.h"

@interface UAChannelAPIClientTest : UABaseTest

@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UAChannelAPIClient *client;

@end

@implementation UAChannelAPIClientTest


- (void)setUp {
    [super setUp];
    self.config = [UAConfig config];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.client = [UAChannelAPIClient clientWithConfig:self.config session:self.mockSession];
}

- (void)tearDown {
    [self.mockSession stopMocking];
    [super tearDown];
}

/**
 * Test channel creation retries all 5xx failures except for 501.
 */
- (void)testChannelCreationRetry {

    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            if(!retryBlock(nil, response)) {
                return NO;
            }
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        // Check that it returns NO for 200 status codes
        response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        // Check that it returns NO for 201 status codes
        response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:201 HTTPVersion:nil headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                                onSuccess:^(NSString *channelID, NSString *channelLocation, BOOL existing){}
                                onFailure:^(NSUInteger statusCode) {}];

    [self.mockSession verify];
}

/**
 * Test create channel calls the onSuccessBlock with the response channel ID
 * and makes an analytics request when the request is successful.
 */
- (void)testCreateChannelOnSuccess {

    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{@"Location":@"someChannelLocation"}];
    NSData *responseData = [@"{ \"ok\":true, \"channel_id\": \"someChannelID\"}" dataUsingEncoding:NSUTF8StringEncoding];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block NSString *channelID;
    __block NSString *channelLocation;

    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                                onSuccess:^(NSString *cID, NSString *location, BOOL existing){
                                    channelID = cID;
                                    channelLocation = location;
                                }
                                onFailure:^(NSUInteger status) {
                                    XCTFail(@"Should not be called");
                                }];

    XCTAssertEqualObjects(@"someChannelID", channelID, @"Channel ID should match someChannelID from the response");
    XCTAssertEqualObjects(@"someChannelLocation", channelLocation, @"Channel location should match location header from the response");
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
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block NSUInteger failureCode = 0;
    [self.client createChannelWithPayload:[[UAChannelRegistrationPayload alloc] init]
                                onSuccess:^(NSString *channelID, NSString *channelLocation, BOOL existing){
                                    XCTFail(@"Should not be called");
                                }
                                onFailure:^(NSUInteger statusCode) {
                                    failureCode = statusCode;
                                }];

    XCTAssertEqual(failureCode, 400);
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

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [self.client createChannelWithPayload:payload
                                onSuccess:^(NSString *channelID, NSString *channelLocation, BOOL existing){}
                                onFailure:^(NSUInteger statusCode) {}];

    [self.mockSession verify];
}

/**
 * Test update channel retries on any 500 status code
 */
- (void)testUpdateChannelRetriesFailedRequests {

    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            // Allow it to retry on 5xx and error results
            if(!retryBlock(nil, response)) {
                return NO;
            }
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        // Check that it returns NO for 200 status codes
        response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        // Check that it returns NO for 201 status codes
        response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:201 HTTPVersion:nil headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client updateChannelWithLocation:@"someLocation"
                               withPayload:[[UAChannelRegistrationPayload alloc] init]
                                 onSuccess:^{}
                                 onFailure:^(NSUInteger statusCode) {}];
    [self.mockSession verify];
}

/**
 * Test update channel calls the onSuccessBlock when the request is successful.
 */
- (void)testUpdateChannelOnSuccess {
    // Create a success response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{@"Location":@"someChannelLocation"}];
    NSData *responseData = [@"{ \"ok\":true, \"channel_id\": \"someChannelID\"}" dataUsingEncoding:NSUTF8StringEncoding];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block BOOL  onSuccessCalled = NO;
    [self.client updateChannelWithLocation:@"someLocation"
                               withPayload:[[UAChannelRegistrationPayload alloc] init]
                                 onSuccess:^{
                                     onSuccessCalled = YES;
                                 }
                                 onFailure:^(NSUInteger status) {
                                     XCTFail(@"Should not be called");
                                 }];

    XCTAssertTrue(onSuccessCalled);
}

/**
 * Test update channel calls the onFailureBlock with the failed request when
 * the request fails.
 */
- (void)testUpdateChannelOnFailure {

    // Create a failure response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];

    // Stub the session to return a the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block NSUInteger failureCode = 0;
    [self.client updateChannelWithLocation:@"someLocation"
                               withPayload:[[UAChannelRegistrationPayload alloc] init]
                                 onSuccess:^{
                                     XCTFail(@"Should not be called");
                                 }
                                 onFailure:^(NSUInteger statusCode) {
                                     failureCode = statusCode;
                                 }];

    XCTAssertEqual(failureCode, 400);
}

/**
 * Test the request headers and body for an update channel request
 */
- (void)testUpdateChannelRequest {

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://device-api.urbanairship.com/someLocation"]) {
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

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [self.client updateChannelWithLocation:@"https://device-api.urbanairship.com/someLocation"
                               withPayload:payload
                                 onSuccess:^{}
                                 onFailure:^(NSUInteger statusCode){}];
    [self.mockSession verify];
}

@end
