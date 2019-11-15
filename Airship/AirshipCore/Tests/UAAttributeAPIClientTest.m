/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import <Foundation/Foundation.h>
#import "UAAttributeAPIClient+Internal.h"
#import "UAirship.h"
#import "UARuntimeConfig.h"
#import "UAAnalytics+Internal.h"
#import "UAAttributePendingMutations+Internal.h"
#import "UAAttributeMutations+Internal.h"
#import "UAJSONSerialization.h"
#import "UAirship+Internal.h"
#import "UAChannel+Internal.h"

@interface UAAttributeAPIClientTest : UABaseTest
@property(nonatomic, strong) id mockSession;
@property(nonatomic, strong) UAAttributeAPIClient *client;
@property(nonatomic, strong) NSString *channelID;
@end

@implementation UAAttributeAPIClientTest

- (void)setUp {
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.client = [UAAttributeAPIClient clientWithConfig:self.config session:self.mockSession];
    self.channelID = @"avalidchannel";
}

/**
 Test mutation request retries on 5xx and 429 status codes.
 */
- (void)testMutationRetry {
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            if(!retryBlock(nil, response)) {
                return NO;
            }
        }

        // Check that it retrys for 429 status codes
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:429 HTTPVersion:nil headerFields:nil];
        if(!retryBlock(nil, response)) {
            return NO;
        }

        // Check that it returns NO for 400 status codes
        response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
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

    [self.client updateChannel:self.channelID withAttributePayload:@{}
                                                         onSuccess:^{}
                                                         onFailure:^(NSUInteger statusCode) {}];

    [self.mockSession verify];
}

/**
 Test mutation request failure returns correct status code.
*/
- (void)testMutationFailure{
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

    [self.client updateChannel:self.channelID withAttributePayload:@{}
                                                         onSuccess:^{
                                                            XCTFail(@"Should not be called");
                                                         }
                                                         onFailure:^(NSUInteger statusCode) {
                                                            failureCode = statusCode;
                                                         }];

    XCTAssertEqual(failureCode, 400);
}

/**
 Test the attribute mutation request is properly formed when given a valid payload
 */
- (void)testMutationRequest {
    NSArray *expectedMutationsPayload = @[
        @{
            @"action" : @"set",
            @"key" : @"jam",
            @"timestamp" : @"2017-01-01T12:00:00",
            @"value" : @"space"
        },
        @{
            @"action" : @"remove",
            @"timestamp" : @"2017-01-01T12:00:00",
            @"key" : @"game",
        }
    ];

    NSDictionary *expectedPayload = @{
        UAAttributePayloadKey : expectedMutationsPayload
    };

    NSData *expectedPayloadData = [UAJSONSerialization dataWithJSONObject:expectedPayload
                                                                  options:0
                                                                    error:nil];
    NSString *expectedUrl = [NSString stringWithFormat:@"https://device-api.urbanairship.com/api/channels/%@/attributes?platform=ios", self.channelID];

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UARequest *request = obj;

        // Check the url
        if (![[request.URL absoluteString] isEqualToString:expectedUrl]) {
            return NO;
        }

        // Check that its a POST
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

        if (![request.body isEqualToData:expectedPayloadData]) {
            return NO;
        }

        // Check the body contains the payload
        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [self.client updateChannel:self.channelID withAttributePayload:expectedPayload
                                                         onSuccess:^{}
                                                        onFailure:^(NSUInteger statusCode) {}];
    [self.mockSession verify];
}

@end
