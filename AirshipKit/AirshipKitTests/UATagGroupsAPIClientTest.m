/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <OCMOCK/OCMock.h>

#import "UAConfig.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UATagGroupsMutation+Internal.h"

@interface UATagGroupsAPIClientTest : XCTestCase
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UATagGroupsAPIClient *client;

@end

@implementation UATagGroupsAPIClientTest

- (void)setUp {
    [super setUp];

    self.config = [UAConfig config];

    self.mockSession = [OCMockObject niceMockForClass:[UARequestSession class]];
    self.client = [UATagGroupsAPIClient clientWithConfig:self.config session:self.mockSession];
}

- (void)tearDown {
    [self.mockSession stopMocking];
    [super tearDown];
}

/**
 * Test tag groups retry for 5xx response codes.
 */
- (void)testRetryBlock {
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];

    // Check that the retry block returns YES for any 5xx request
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            if (retryBlock(nil, response)) {
                continue;
            }

            return NO;
        }

        // Check that it returns NO for 400 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(nil, response)) {
            return NO;
        }

        return YES;
    };

    // Verify channel
    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client updateChannel:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
             tagGroupsMutation:mutation
             completionHandler:^(NSUInteger statusCode){}];

    [self.mockSession verify];


    // Verify named user
    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];


    [self.client updateNamedUser:@"named_user"
             tagGroupsMutation:mutation
             completionHandler:^(NSUInteger statusCode){}];

    [self.mockSession verify];
}

/**
 * Test completion handler is called with the response status code.
 */
- (void)testCompletionHandler {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:222 HTTPVersion:nil headerFields:nil];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];


    // Stub the sesion to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Verify channel tags
    __block NSUInteger channelTagResponseCode = 0;

    [self.client updateChannel:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
               tagGroupsMutation:mutation
               completionHandler:^(NSUInteger status) {
                   channelTagResponseCode = status;
               }];

    XCTAssertEqual(channelTagResponseCode, response.statusCode);


    // Verify named user
    __block NSUInteger namedUserTagResponseCode = 0;

    [self.client updateNamedUser:@"named_user"
               tagGroupsMutation:mutation
               completionHandler:^(NSUInteger status) {
                   namedUserTagResponseCode = status;
               }];

    XCTAssertEqual(namedUserTagResponseCode, response.statusCode);
}

/**
 * Test channel request.
 */
- (void)testChannelRequest {

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://device-api.urbanairship.com/api/channels/tags/"]) {
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

        NSDictionary *expectedPayload = @{ @"audience": @{ @"ios_channel": @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" },
                                           @"add": @{ @"tag group": @[@"tag1"] } };

        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.body options:0 error:nil];
        if (![body isEqualToDictionary:expectedPayload]) {
            return NO;
        }

        // Check the body contains the payload
        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];


    [self.client updateChannel:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
             tagGroupsMutation:mutation
             completionHandler:^(NSUInteger statusCode){}];

    [self.mockSession verify];
}


/**
 * Test named user request.
 */
- (void)testNamedUserRequest {

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // check the url
        if (![[request.URL absoluteString] isEqualToString:@"https://device-api.urbanairship.com/api/named_users/tags/"]) {
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

        NSDictionary *expectedPayload = @{ @"audience": @{ @"named_user_id": @"cool" },
                                           @"add": @{ @"tag group": @[@"tag1"] } };

        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.body options:0 error:nil];
        if (![body isEqualToDictionary:expectedPayload]) {
            return NO;
        }

        // Check the body contains the payload
        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];

    [self.client updateNamedUser:@"cool"
               tagGroupsMutation:mutation
               completionHandler:^(NSUInteger statusCode){}];
    
    [self.mockSession verify];
}

@end
