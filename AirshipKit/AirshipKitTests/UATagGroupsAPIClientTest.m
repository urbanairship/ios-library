/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMOCK/OCMock.h>
#import "UAConfig.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UAirship.h"
#import "UAHTTPRequestEngine+Internal.h"
#import "UAHTTPRequest+Internal.h"

@interface UATagGroupsAPIClientTest : XCTestCase

@property (nonatomic, strong) id mockRequestEngine;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UATagGroupsAPIClient *client;
@property (nonatomic, strong) NSMutableDictionary *addTags;
@property (nonatomic, strong) NSMutableDictionary *removeTags;

@end

@implementation UATagGroupsAPIClientTest

- (void)setUp {
    [super setUp];

    self.config = [UAConfig config];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.config] config];


    self.mockRequestEngine = [OCMockObject niceMockForClass:[UAHTTPRequestEngine class]];


    self.addTags = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *tagsToAdd = [NSMutableDictionary dictionary];
    NSArray *addTagsArray = @[@"tag1", @"tag2", @"tag3"];
    [tagsToAdd setValue:addTagsArray forKey:@"tag_group"];
    self.addTags = tagsToAdd;

    self.removeTags = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *tagsToRemove = [NSMutableDictionary dictionary];
    NSArray *removeTagsArray = @[@"tag3", @"tag4", @"tag5"];
    [tagsToRemove setValue:removeTagsArray forKey:@"tag_group"];
    self.removeTags = tagsToRemove;

    self.client = [UATagGroupsAPIClient clientWithConfig:self.config];
    self.client.requestEngine = self.mockRequestEngine;
}

- (void)tearDown {
    [self.mockRequestEngine stopMocking];
    [self.mockAirship stopMocking];
    [super tearDown];
}

/**
 * Test update channel tags retries on 5xx status codes.
 */
- (void)testUpdateChannelTagsRetriesFailedRequest {
    // Check that the retry block returns YES for any 5xx request
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
            request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            // If shouldRetryOnConnection is NO, never retry
            self.client.shouldRetryOnConnectionError = NO;
            if (retryBlock(request)) {
                return NO;
            }

            // Allow it to retry on 5xx and error results
            self.client.shouldRetryOnConnectionError = YES;
            BOOL retryResult = retryBlock(request);

            if (retryResult) {
                continue;
            }

            return NO;
        }

        // Check that it returns NO for 400 status codes
        UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
        request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(request)) {
            return NO;
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:OCMOCK_ANY
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:self.addTags
                            remove:self.removeTags
                         onSuccess:^{
                             XCTFail(@"Success block should not be called on retry");
                         }
                         onFailure:^(UAHTTPRequest *request) {
                             XCTFail(@"Failure block should not be called on retry");
                         }];

    XCTAssertNoThrow([self.mockRequestEngine verify],
                     @"Update channel tag groups should call retry on 5xx status codes.");
}

/**
 * Test update channel tags succeeds request when status is 2xx.
 */
- (void)testUpdateChannelTagsSucceedsRequest {
    BOOL (^whereBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock whereBlock = obj;

        for (NSInteger i = 200; i < 300; i++) {
            UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
            request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];
            if (!whereBlock(request)) {
                return NO;
            }
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:OCMOCK_ANY
                                   succeedWhere:[OCMArg checkWithBlock:whereBlockCheck]
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:self.addTags
                            remove:self.removeTags
                         onSuccess:^(){}
                         onFailure:^(UAHTTPRequest *request){}];
    XCTAssertNoThrow([self.mockRequestEngine verify],
                     @"Update channel tag groups should succeed on 2xx status codes.");
}

/**
 * Test update channel tags calls the onSuccessBlock when the request is successful.
 */
- (void)testUpdateChannelTagsOnSuccess {
    __block BOOL onSuccessCalled = NO;

    // Set up a request with a valid response body
    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    NSString *response = @"{ \"ok\":true }";
    request.responseData = [response dataUsingEncoding:NSUTF8StringEncoding];

    // Expect the run request and call the success block
    [[[self.mockRequestEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UAHTTPRequestEngineSuccessBlock successBlock = (__bridge UAHTTPRequestEngineSuccessBlock)arg;

        successBlock(request, 0);
    }] runRequest:OCMOCK_ANY succeedWhere:OCMOCK_ANY retryWhere:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:self.addTags
                            remove:self.removeTags
                         onSuccess:^{
                             onSuccessCalled = YES;
                         } onFailure:^(UAHTTPRequest *request){}];

    XCTAssertTrue(onSuccessCalled, @"Update channel tag groups should call onSuccess block when its successful.");
}

/**
 * Test update channel tags calls the onFailureBlock with the failed request
 * when the request fails.
 */
- (void)testUpdateChannelTagsOnFailure {
    __block UAHTTPRequest *failedRequest;

    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];

    // Expect the run request and call the failure block
    [[[self.mockRequestEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:6];
        UAHTTPRequestEngineFailureBlock failureBlock = (__bridge UAHTTPRequestEngineFailureBlock)arg;
        failureBlock(request, 0);
    }] runRequest:OCMOCK_ANY succeedWhere:OCMOCK_ANY retryWhere:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:self.addTags
                            remove:self.removeTags
                         onSuccess:^{}
                         onFailure:^(UAHTTPRequest *request) {
                             failedRequest = request;
    }];

    XCTAssertEqualObjects(request, failedRequest, @"Failure block should return the failed request.");
}

/**
 * Test payload does not contain empty addTags for updateChannelTags.
 */
- (void)testUpdateChannelEmptyAddTags {
    NSMutableDictionary *emptyAddTags = [[NSMutableDictionary alloc] init];

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UAHTTPRequest *request = obj;
        NSMutableDictionary *audience = [NSMutableDictionary dictionary];
        [audience setValue:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" forKey:@"ios_channel"];

        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setValue:audience forKey:@"audience"];
        [payload setValue:self.removeTags forKey:@"remove"];

        // Check the body does not contain empty addTags in the payload
        if (![request.body isEqualToData:[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]]) {
            return NO;
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:emptyAddTags
                            remove:self.removeTags
                         onSuccess:^{}
                         onFailure:^(UAHTTPRequest *request){}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Update channel tags should run with valid payload.");
}

/**
 * Test payload does not contain empty removeTags for updateChannelTags.
 */
- (void)testUpdateChannelEmptyRemoveTags {
    NSMutableDictionary *emptyRemoveTags = [[NSMutableDictionary alloc] init];

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UAHTTPRequest *request = obj;
        NSMutableDictionary *audience = [NSMutableDictionary dictionary];
        [audience setValue:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" forKey:@"ios_channel"];

        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setValue:audience forKey:@"audience"];
        [payload setValue:self.addTags forKey:@"add"];

        // Check the body does not contain empty removeTags in the payload
        if (![request.body isEqualToData:[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]]) {
            return NO;
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:self.addTags
                            remove:emptyRemoveTags
                         onSuccess:^{}
                         onFailure:^(UAHTTPRequest *request){}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Update channel tags should run with valid payload.");
}


/**
 * Test updateChannelTags with empty addTags and removeTags skips request.
 */
- (void)testUpdateChannelEmptyTags {
    NSMutableDictionary *emptyAddTags = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *emptyRemoveTags = [[NSMutableDictionary alloc] init];

    [[self.mockRequestEngine reject] runRequest:OCMOCK_ANY
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:emptyAddTags
                            remove:emptyRemoveTags
                         onSuccess:^{}
                         onFailure:^(UAHTTPRequest *request){}];
    XCTAssertNoThrow([self.mockRequestEngine verify], @"Update channel tags should not make a request with both empty tags.");
}

/**
 * Test update named user tags retries on 5xx status codes.
 */
- (void)testUpdateNamedUserTagsRetriesFailedRequest {
    // Check that the retry block returns YES for any 5xx request
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
            request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            // If shouldRetryOnConnection is NO, never retry
            self.client.shouldRetryOnConnectionError = NO;
            if (retryBlock(request)) {
                return NO;
            }

            // Allow it to retry on 5xx and error results
            self.client.shouldRetryOnConnectionError = YES;
            BOOL retryResult = retryBlock(request);

            if (retryResult) {
                continue;
            }

            return NO;
        }

        // Check that it returns NO for 400 status codes
        UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
        request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:400 HTTPVersion:nil headerFields:nil];
        if (retryBlock(request)) {
            return NO;
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:OCMOCK_ANY
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                                 add:self.addTags
                              remove:self.removeTags
                           onSuccess:^{}
                           onFailure:^(UAHTTPRequest *request){}];
    XCTAssertNoThrow([self.mockRequestEngine verify],
                     @"Update named user tags should call retry on 5xx status codes.");
}

/**
 * Test update named user tags succeeds request when status is 2xx.
 */
- (void)testUpdateNamedUserTagsSucceedsRequest {
    BOOL (^whereBlockCheck)(id obj) = ^(id obj) {
        UAHTTPRequestEngineWhereBlock whereBlock = obj;

        for (NSInteger i = 200; i < 300; i++) {
            UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
            request.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];
            if (!whereBlock(request)) {
                return NO;
            }
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:OCMOCK_ANY
                                   succeedWhere:[OCMArg checkWithBlock:whereBlockCheck]
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                                 add:self.addTags
                              remove:self.removeTags
                           onSuccess:^{}
                           onFailure:^(UAHTTPRequest *request){}];
    XCTAssertNoThrow([self.mockRequestEngine verify],
                     @"Update named user tags should succeed on 2xx status codes.");
}

/**
 * Test update named user tags calls the onSuccessBlock when the request is successful.
 */
- (void)testUpdateNamedUserTagsOnSuccess {
    __block BOOL onSuccessCalled = NO;

    // Set up a request with a valid response body
    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    NSString *response = @"{ \"ok\":true }";
    request.responseData = [response dataUsingEncoding:NSUTF8StringEncoding];

    // Expect the run request and call the success block
    [[[self.mockRequestEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UAHTTPRequestEngineSuccessBlock successBlock = (__bridge UAHTTPRequestEngineSuccessBlock)arg;

        successBlock(request, 0);
    }] runRequest:OCMOCK_ANY succeedWhere:OCMOCK_ANY retryWhere:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                                 add:self.addTags
                              remove:self.removeTags
                           onSuccess:^{
                               onSuccessCalled = YES;
                           } onFailure:^(UAHTTPRequest *request){}];

    XCTAssertTrue(onSuccessCalled, @"Update named user tags should call onSuccess block when its successful.");
}

/**
 * Test update named user tags calls the onFailureBlock with the failed request
 * when the request fails.
 */
- (void)testUpdateNamedUserTagsOnFailure {
    __block UAHTTPRequest *failedRequest;

    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];

    // Expect the run request and call the failure block.
    [[[self.mockRequestEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:6];
        UAHTTPRequestEngineFailureBlock failureBlock = (__bridge UAHTTPRequestEngineFailureBlock)arg;
        failureBlock(request, 0);
    }] runRequest:OCMOCK_ANY succeedWhere:OCMOCK_ANY retryWhere:OCMOCK_ANY onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                                 add:self.addTags
                              remove:self.removeTags
                           onSuccess:^{}
                           onFailure:^(UAHTTPRequest *request) {
                               failedRequest = request;
    }];

    XCTAssertEqualObjects(request, failedRequest, @"Failure block should return the failed request.");
}

/**
 * Test payload does not contain empty addTags for updateNamedUserTags.
 */
- (void)testUpdateNamedUserEmptyAddTags {
    NSMutableDictionary *emptyAddTags = [[NSMutableDictionary alloc] init];

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UAHTTPRequest *request = obj;
        NSMutableDictionary *audience = [NSMutableDictionary dictionary];
        [audience setValue:@"fake-named-user" forKey:@"named_user_id"];

        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setValue:audience forKey:@"audience"];
        [payload setValue:self.removeTags forKey:@"remove"];

        // Check the body does not contain empty addTags in the payload
        if (![request.body isEqualToData:[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]]) {
            return NO;
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                               add:emptyAddTags
                            remove:self.removeTags
                           onSuccess:^{}
                         onFailure:^(UAHTTPRequest *request){}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Update named user tags should run with valid payload.");
}

/**
 * Test payload does not contain empty removeTags for updateNamedUserTags.
 */
- (void)testUpdateNamedUserEmptyRemoveTags {
    NSMutableDictionary *emptyRemoveTags = [[NSMutableDictionary alloc] init];

    BOOL (^checkRequestBlock)(id obj) = ^(id obj) {
        UAHTTPRequest *request = obj;
        NSMutableDictionary *audience = [NSMutableDictionary dictionary];
        [audience setValue:@"fake-named-user" forKey:@"named_user_id"];

        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        [payload setValue:audience forKey:@"audience"];
        [payload setValue:self.addTags forKey:@"add"];

        // Check the body does not contain empty removeTags in the payload
        if (![request.body isEqualToData:[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]]) {
            return NO;
        }

        return YES;
    };

    [[self.mockRequestEngine expect] runRequest:[OCMArg checkWithBlock:checkRequestBlock]
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                               add:self.addTags
                            remove:emptyRemoveTags
                           onSuccess:^{}
                         onFailure:^(UAHTTPRequest *request){}];

    XCTAssertNoThrow([self.mockRequestEngine verify], @"Update named user tags should run with valid payload.");
}

/**
 * Test updateNamedUserTags with empty addTags and removeTags skips request.
 */
- (void)testUpdateNamedUserEmptyTags {
    NSMutableDictionary *emptyAddTags = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *emptyRemoveTags = [[NSMutableDictionary alloc] init];

    [[self.mockRequestEngine reject] runRequest:OCMOCK_ANY
                                   succeedWhere:OCMOCK_ANY
                                     retryWhere:OCMOCK_ANY
                                      onSuccess:OCMOCK_ANY
                                      onFailure:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                               add:emptyAddTags
                            remove:emptyRemoveTags
                           onSuccess:^{}
                         onFailure:^(UAHTTPRequest *request){}];
    XCTAssertNoThrow([self.mockRequestEngine verify], @"Update named user tags should not make a request with both empty tags.");
}

@end
