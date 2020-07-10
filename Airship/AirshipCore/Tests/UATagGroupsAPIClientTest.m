/* Copyright Airship and Contributors */


#import "UAAirshipBaseTest.h"
#import <UIKit/UIKit.h>

#import "UARuntimeConfig.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UATagGroupsMutation+Internal.h"

@interface UATagGroupsAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) UATagGroupsAPIClient *channelClient;
@property (nonatomic, strong) UATagGroupsAPIClient *namedUserClient;

@end

@implementation UATagGroupsAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.channelClient = [UATagGroupsAPIClient clientWithConfig:self.config session:self.mockSession storeKey:UATagGroupsChannelStoreKey];
    self.namedUserClient = [UATagGroupsAPIClient clientWithConfig:self.config session:self.mockSession storeKey:UATagGroupsNamedUserStoreKey];
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

    // Verify update
    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.channelClient updateTagGroupsForId:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
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

    [self.channelClient updateTagGroupsForId:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                    tagGroupsMutation:mutation
                    completionHandler:^(NSUInteger status) {
                        channelTagResponseCode = status;
                    }];

    XCTAssertEqual(channelTagResponseCode, response.statusCode);


    // Verify named user
    __block NSUInteger namedUserTagResponseCode = 0;

    [self.namedUserClient updateTagGroupsForId:@"named_user"
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

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler) arg;
        if (completionHandler) {
            completionHandler(nil,nil,nil);
        }
    }] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
                retryWhere:OCMOCK_ANY
         completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];

    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"Completion handler called"];

    // test
    [self.channelClient updateTagGroupsForId:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                    tagGroupsMutation:mutation
                    completionHandler:^(NSUInteger statusCode){
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

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler) arg;
        if (completionHandler) {
            completionHandler(nil,nil,nil);
        }
    }] dataTaskWithRequest:[OCMArg checkWithBlock:checkRequestBlock]
     retryWhere:OCMOCK_ANY
     completionHandler:OCMOCK_ANY];
    

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];
    
    XCTestExpectation *completionHandlerCalledExpectation = [self expectationWithDescription:@"Completion handler called"];
    
    // test
    [self.namedUserClient updateTagGroupsForId:@"cool"
                    tagGroupsMutation:mutation
                    completionHandler:^(NSUInteger statusCode){
                        [completionHandlerCalledExpectation fulfill];
                    }];
    
    // verify
    [self waitForTestExpectations];
    
    [self.mockSession verify];
}

/**
 * Test channel request when disabled.
 */
- (void)testChannelRequestWhenDisabled {
    //setup
    self.channelClient.enabled = NO;
    
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler) arg;
        if (completionHandler) {
            completionHandler(nil,nil,nil);
        }
    }] dataTaskWithRequest:OCMOCK_ANY
     retryWhere:OCMOCK_ANY
     completionHandler:OCMOCK_ANY];
    
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];
    
    // test
    [self.channelClient updateTagGroupsForId:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                    tagGroupsMutation:mutation
                    completionHandler:^(NSUInteger statusCode){
                        XCTFail(@"Completion Handler should not be called");
                    }];
    
    // verify
    [self.mockSession verify];
}

/**
 * Test named user request when disabled
 */
- (void)testNamedUserRequestWhenDisabled {
    //setup
    self.namedUserClient.enabled = NO;
   
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler) arg;
        if (completionHandler) {
            completionHandler(nil,nil,nil);
        }
    }] dataTaskWithRequest:OCMOCK_ANY
     retryWhere:OCMOCK_ANY
     completionHandler:OCMOCK_ANY];
    
    
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"tag1"]
                                                                     group:@"tag group"];
    
    // test
    [self.namedUserClient updateTagGroupsForId:@"cool"
                    tagGroupsMutation:mutation
                    completionHandler:^(NSUInteger statusCode){
                        XCTFail(@"Completion Handler should not be called");
                    }];
    
    // verify
    [self.mockSession verify];
}

@end
