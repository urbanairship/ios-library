/* Copyright Airship and Contributors */


#import "UAAirshipBaseTest.h"
#import <UIKit/UIKit.h>

#import "UARuntimeConfig.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UATagGroupsMutation+Internal.h"

@interface UATagGroupsAPIClient()

@property(nonatomic) NSString *path;

@end

@interface UATagGroupsAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) UATagGroupsAPIClient *channelClient;
@property (nonatomic, strong) UATagGroupsAPIClient *namedUserClient;

@end

@implementation UATagGroupsAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.channelClient = [UATagGroupsAPIClient channelClientWithConfig:self.config session:self.mockSession];
    self.namedUserClient = [UATagGroupsAPIClient namedUserClientWithConfig:self.config session:self.mockSession];
}

- (void)testTagGroupApiClientPath {
    XCTAssertEqualObjects(self.channelClient.path, @"/api/channels/tags/");
    XCTAssertEqualObjects(self.namedUserClient.path, @"/api/named_users/tags/");
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

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler) arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock]
     completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"Completion handler called"];

    // test
    [self.channelClient updateTagGroupsForId:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                           tagGroupsMutation:mutation
                           completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqual(200, response.status);
        [completionHandlerCalledExpectation fulfill];
    }];

    // verify
    [self waitForTestExpectations];

    [self.mockSession verify];
}

/**
 * Test named user request.
 */
- (void)testNamedUserRequest {
    // setup
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

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler) arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:checkRequestBlock]
     completionHandler:OCMOCK_ANY];


    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"Completion handler called"];

    // test
    [self.namedUserClient updateTagGroupsForId:@"cool"
                             tagGroupsMutation:mutation
                             completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqual(200, response.status);
        [completionHandlerCalledExpectation fulfill];
    }];

    // verify
    [self waitForTestExpectations];

    [self.mockSession verify];
}

- (void)testUnsuccessfulStatus {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:420
                                                             HTTPVersion:nil
                                                            headerFields:nil];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler) arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"Completion handler called"];

    // test
    [self.namedUserClient updateTagGroupsForId:@"cool"
                             tagGroupsMutation:mutation
                             completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertNil(error);
        XCTAssertEqual(420, response.status);
        [completionHandlerCalledExpectation fulfill];
    }];

    // verify
    [self waitForTestExpectations];

    [self.mockSession verify];
}

- (void)testUpdateError {
    NSError *responseError = [[NSError alloc] initWithDomain:@"whatever" code:1 userInfo:nil];
    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler) arg;
        completionHandler(nil, nil, responseError);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"Completion handler called"];

    // test
    [self.namedUserClient updateTagGroupsForId:@"cool"
                             tagGroupsMutation:mutation
                             completionHandler:^(UAHTTPResponse *response, NSError *error){
        XCTAssertEqual(responseError, error);
        XCTAssertNil(response);
        [completionHandlerCalledExpectation fulfill];
    }];

    // verify
    [self waitForTestExpectations];

    [self.mockSession verify];
}

@end


