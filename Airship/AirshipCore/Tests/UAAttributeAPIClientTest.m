/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import <Foundation/Foundation.h>
#import "UAAttributeAPIClient+Internal.h"
#import "UAirship.h"
#import "UARuntimeConfig.h"
#import "UAAnalytics+Internal.h"
#import "UAAttributePendingMutations.h"
#import "UAAttributeMutations+Internal.h"
#import "UAJSONSerialization.h"
#import "UAirship+Internal.h"
#import "UAChannel+Internal.h"

@interface UAAttributeAPIClientTest : UAAirshipBaseTest
@property(nonatomic, strong) id mockSession;
@property(nonatomic, strong) UAAttributeAPIClient *client;
@end

@implementation UAAttributeAPIClientTest

- (void)setUp {
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.client = [UAAttributeAPIClient clientWithConfig:self.config
                                                 session:self.mockSession
                                         URLFactoryBlock:^NSURL * _Nonnull(UARuntimeConfig *config, NSString *identifier) {
        return [NSURL URLWithString:[NSString stringWithFormat:@"https://test/%@", identifier]];
    }];
}

/**
 * Test request
 */
- (void)testResponse {
    // Create a response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    id mockMutation = [self mockForClass:[UAAttributePendingMutations class]];
    [[[mockMutation stub] andReturn:@{@"neat": @"payload"}] payload];

    // Stub the session to return a the response
    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = (UARequest *)obj;
        id body = [UAJSONSerialization dataWithJSONObject:@{@"neat": @"payload"}
                                                  options:0
                                                    error:nil];

        return [request.method isEqualToString:@"POST"] &&
        [request.body isEqualToData:body] &&
        [request.URL isEqual:[NSURL URLWithString:@"https://test/bobby"]];
    }] completionHandler:OCMOCK_ANY];


    XCTestExpectation *callback = [self expectationWithDescription:@"callback"];
    [self.client updateWithIdentifier:@"bobby"
                   attributeMutations:mockMutation
                    completionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [callback fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testUnsuccessfulResponse {
    // Create a response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:420
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    id mockMutation = [self mockForClass:[UAAttributePendingMutations class]];
    [[[mockMutation stub] andReturn:@{@"neat": @"payload"}] payload];

    // Stub the session to return a the response
    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = (UARequest *)obj;
        id body = [UAJSONSerialization dataWithJSONObject:@{@"neat": @"payload"}
                                                  options:0
                                                    error:nil];

        return [request.method isEqualToString:@"POST"] &&
        [request.body isEqualToData:body] &&
        [request.URL isEqual:[NSURL URLWithString:@"https://test/bobby"]];
    }] completionHandler:OCMOCK_ANY];


    XCTestExpectation *callback = [self expectationWithDescription:@"callback"];
    [self.client updateWithIdentifier:@"bobby"
                   attributeMutations:mockMutation
                    completionHandler:^(NSError * _Nullable error) {
        XCTAssertEqualObjects(error.domain, UAAttributeAPIClientErrorDomain);
        XCTAssertEqual(error.code, UAAttributeAPIClientErrorUnsuccessfulStatus);
        [callback fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testUnrecoverableResponse {
    // Create a response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:400
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    id mockMutation = [self mockForClass:[UAAttributePendingMutations class]];
    [[[mockMutation stub] andReturn:@{@"neat": @"payload"}] payload];

    // Stub the session to return a the response
    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = (UARequest *)obj;
        id body = [UAJSONSerialization dataWithJSONObject:@{@"neat": @"payload"}
                                                  options:0
                                                    error:nil];

        return [request.method isEqualToString:@"POST"] &&
        [request.body isEqualToData:body] &&
        [request.URL isEqual:[NSURL URLWithString:@"https://test/bobby"]];
    }] completionHandler:OCMOCK_ANY];


    XCTestExpectation *callback = [self expectationWithDescription:@"callback"];
    [self.client updateWithIdentifier:@"bobby"
                   attributeMutations:mockMutation
                    completionHandler:^(NSError * _Nullable error) {
        XCTAssertEqualObjects(error.domain, UAAttributeAPIClientErrorDomain);
        XCTAssertEqual(error.code, UAAttributeAPIClientErrorUnrecoverableStatus);
        [callback fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testError {
    NSError *expectedError = [NSError errorWithDomain:@"some domain" code:20000 userInfo:nil];

    id mockMutation = [self mockForClass:[UAAttributePendingMutations class]];
    [[[mockMutation stub] andReturn:@{@"neat": @"payload"}] payload];

    // Stub the session to return a the response
    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, nil, expectedError);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *callback = [self expectationWithDescription:@"callback"];
    [self.client updateWithIdentifier:@"bobby"
                   attributeMutations:mockMutation
                    completionHandler:^(NSError * _Nullable error) {
        XCTAssertEqual(expectedError, error);
        [callback fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockSession verify];
}

@end
