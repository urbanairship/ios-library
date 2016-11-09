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

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockSession;
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

    self.mockSession = [OCMockObject niceMockForClass:[UARequestSession class]];
    self.client = [UATagGroupsAPIClient clientWithConfig:self.config session:self.mockSession];

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
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [super tearDown];
}

/**
 * Test update channel tags retries on 5xx status codes.
 */
- (void)testUpdateChannelTagsRetriesFailedRequest {
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

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:self.addTags
                            remove:self.removeTags
                         onSuccess:^{
                             XCTFail(@"Success block should not be called on retry");
                         }
                         onFailure:^(NSUInteger status) {
                             XCTFail(@"Failure block should not be called on retry");
                         }];

    [self.mockSession verify];
}

/**
 * Test update channel tags succeeds request when status is 2xx.
 */
- (void)testUpdateChannelTagsSucceedsRequest {
    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 200; i < 300; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    __block int successBlockCalls = 0;

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:self.addTags
                            remove:self.removeTags
                         onSuccess:^(){
                             successBlockCalls++;
                         }
                         onFailure:^(NSUInteger status){
                             XCTFail(@"Failure block should not be called");
                         }];

    // Success block should be called once for every HTTP status from 200 to 299
    XCTAssert(successBlockCalls == 100);
    [self.mockSession verify];
}

/**
 * Test update channel tags calls the onFailureBlock with the failed request
 * when the request fails.
 */
- (void)testUpdateChannelTagsOnFailure {
    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 400; i < 499; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    __block int failureBlockCalls = 0;

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:self.addTags
                            remove:self.removeTags
                         onSuccess:^(){
                             XCTFail(@"Success block should not be called");
                         }
                         onFailure:^(NSUInteger status){
                             failureBlockCalls++;
                         }];

    // Failure block should be called once for every HTTP status from 400 to 499
    XCTAssert(failureBlockCalls == 99);

    [self.mockSession verify];
}

/**
 * Test payload does not contain empty removeTags for updateChannelTags.
 */
- (void)testUpdateChannelEmptyRemoveTags {

    NSMutableDictionary *emptyRemoveTags = [[NSMutableDictionary alloc] init];

    BOOL (^requestBlockCheck)(id obj) = ^(id obj) {
        UARequest *request = obj;

        NSMutableDictionary *audience = [NSMutableDictionary dictionary];
        [audience setValue:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" forKey:@"ios_channel"];
        NSDictionary *payload = [NSMutableDictionary dictionary];
        [payload setValue:audience forKey:@"audience"];
        [payload setValue:self.addTags forKey:@"add"];

        return [request.body isEqualToData:[NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil]];
    };

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:requestBlockCheck]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:self.addTags
                            remove:emptyRemoveTags
                         onSuccess:^{
                         }
                         onFailure:^(NSUInteger status) {
                         }];

    [self.mockSession verify];
}

/**
 * Test updateChannelTags with empty addTags and removeTags skips request.
 */
- (void)testUpdateChannelEmptyTags {
    NSMutableDictionary *emptyAddTags = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *emptyRemoveTags = [[NSMutableDictionary alloc] init];

    [[self.mockSession reject] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [self.client updateChannelTags:@"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                               add:emptyAddTags
                            remove:emptyRemoveTags
                         onSuccess:^{}
                         onFailure:^(NSUInteger status){}];
    [self.mockSession verify];
}

/**
 * Test update named user tags retries on 5xx status codes.
 */
- (void)testUpdateNamedUserTagsRetriesFailedRequest {
    // Check that the retry block returns YES for any 5xx request
    BOOL (^retryBlockCheck)(id obj) = ^(id obj) {
        UARequestRetryBlock retryBlock = obj;

        for (NSInteger i = 500; i < 600; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            BOOL retryResult = retryBlock(nil, response);

            if (retryResult) {
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

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:[OCMArg checkWithBlock:retryBlockCheck]
                                 completionHandler:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                                 add:self.addTags
                              remove:self.removeTags
                           onSuccess:^{
                               XCTFail(@"Success block should not be called on retry");
                           }
                           onFailure:^(NSUInteger status) {
                               XCTFail(@"Failure block should not be called on retry");
                           }];

    [self.mockSession verify];
}

/**
 * Test update named user tags succeeds request when status is 2xx.
 */
- (void)testUpdateNamedUserTagsSucceedsRequest {
    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 200; i < 300; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    __block int successBlockCalls = 0;

    [self.client updateNamedUserTags:@"fake-named-user"
                                 add:self.addTags
                              remove:self.removeTags
                           onSuccess:^(){
                               successBlockCalls++;
                           }
                           onFailure:^(NSUInteger status){
                               XCTFail(@"Failure block should not be called");
                           }];

    // Success block should be called once for every HTTP status from 200 to 299
    XCTAssert(successBlockCalls == 100);
    [self.mockSession verify];
}

/**
 * Test update named user tags calls the onFailureBlock with the failed request
 * when the request fails.
 */
- (void)testUpdateNamedUserTagsOnFailure {
    BOOL (^completionBlockCheck)(id obj) = ^(id obj) {
        UARequestCompletionHandler completion = obj;

        for (NSInteger i = 400; i < 499; i++) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:i HTTPVersion:nil headerFields:nil];

            completion(OCMOCK_ANY, response, nil);
        }

        return YES;
    };

    [[self.mockSession expect] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:completionBlockCheck]];

    __block int failureBlockCalls = 0;

    [self.client updateNamedUserTags:@"fake-named-user"
                                 add:self.addTags
                              remove:self.removeTags
                           onSuccess:^(){
                               XCTFail(@"Success block should not be called");
                           }
                           onFailure:^(NSUInteger status){
                               failureBlockCalls++;
                           }];

    // Failure block should be called once for every HTTP status from 400 to 499
    XCTAssert(failureBlockCalls == 99);

    [self.mockSession verify];
}

/**
 * Test payload does not contain empty addTags for updateNamedUserTags.
 */
- (void)testUpdateNamedUserEmptyAddTags {
    NSMutableDictionary *emptyAddTags = [[NSMutableDictionary alloc] init];

    BOOL (^requestBlockCheck)(id obj) = ^(id obj) {
        UARequest *request = obj;

        NSMutableDictionary *audience = [NSMutableDictionary dictionary];
        [audience setValue:@"fake-named-user" forKey:@"named_user_id"];

        NSDictionary *payload = [NSMutableDictionary dictionary];
        [payload setValue:audience forKey:@"audience"];
        [payload setValue:self.removeTags forKey:@"remove"];

        return [request.body isEqualToData:[NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil]];
    };

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:requestBlockCheck]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                                 add:emptyAddTags
                              remove:self.removeTags
                           onSuccess:^{
                           }
                           onFailure:^(NSUInteger status) {
                           }];

    [self.mockSession verify];
}

/**
 * Test payload does not contain empty removeTags for updateNamedUserTags.
 */
- (void)testUpdateNamedUserEmptyRemoveTags {
    NSMutableDictionary *emptyRemoveTags = [[NSMutableDictionary alloc] init];

    BOOL (^requestBlockCheck)(id obj) = ^(id obj) {
        UARequest *request = obj;

        NSMutableDictionary *audience = [NSMutableDictionary dictionary];
        [audience setValue:@"fake-named-user" forKey:@"named_user_id"];

        NSDictionary *payload = [NSMutableDictionary dictionary];
        [payload setValue:audience forKey:@"audience"];
        [payload setValue:self.addTags forKey:@"add"];

        return [request.body isEqualToData:[NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil]];
    };

    [[self.mockSession expect] dataTaskWithRequest:[OCMArg checkWithBlock:requestBlockCheck]
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                                 add:self.addTags
                              remove:emptyRemoveTags
                           onSuccess:^{
                           }
                           onFailure:^(NSUInteger status) {
                           }];

    [self.mockSession verify];
}

/**
 * Test updateNamedUserTags with empty addTags and removeTags skips request.
 */
- (void)testUpdateNamedUserEmptyTags {
    NSMutableDictionary *emptyAddTags = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *emptyRemoveTags = [[NSMutableDictionary alloc] init];

    [[self.mockSession reject] dataTaskWithRequest:OCMOCK_ANY
                                        retryWhere:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [self.client updateNamedUserTags:@"fake-named-user"
                                 add:emptyAddTags
                              remove:emptyRemoveTags
                           onSuccess:^{}
                           onFailure:^(NSUInteger status){}];

    [self.mockSession verify];
}

@end
