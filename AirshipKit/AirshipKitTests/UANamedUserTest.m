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
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UANamedUser.h"
#import "UANamedUser+Internal.h"
#import "UANamedUserAPIClient+Internal.h"
#import "UAPush+Internal.h"
#import "UAConfig.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UATagGroupsMutation+Internal.h"


@interface UANamedUserTest : XCTestCase

@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) UANamedUser *namedUser;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) id mockedNamedUserClient;
@property (nonatomic, strong) id mockedUAPush;
@property (nonatomic, copy) NSString *pushChannelID;
@property (nonatomic, strong) id mockTagGroupsAPIClient;
@property (nonatomic, strong) NSMutableDictionary *addTagGroups;
@property (nonatomic, strong) NSMutableDictionary *removeTagGroups;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockConfig;

@end

@implementation UANamedUserTest

void (^namedUserSuccessDoBlock)(NSInvocation *);
void (^namedUserFailureDoBlock)(NSInvocation *);


- (void)setUp {
    [super setUp];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"uapush.test."];

    self.mockedUAPush = [OCMockObject niceMockForClass:[UAPush class]];
    [[[self.mockedUAPush stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&_pushChannelID];
    }] channelID];

    self.mockConfig = [OCMockObject niceMockForClass:[UAConfig class]];


    self.mockedAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockedAirship stub] andReturn:self.mockedAirship] shared];
    [[[self.mockedAirship stub] andReturn:self.mockedUAPush] push];

    self.pushChannelID = @"someChannel";

    self.namedUser = [UANamedUser namedUserWithPush:self.mockedUAPush config:self.mockConfig dataStore:self.dataStore];

    self.mockedNamedUserClient = [OCMockObject niceMockForClass:[UANamedUserAPIClient class]];
    self.namedUser.namedUserAPIClient = self.mockedNamedUserClient;
    self.mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];

    // set up the named user
    self.namedUser.identifier = @"fakeNamedUser";
    self.namedUser.changeToken = @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE";
    self.namedUser.lastUpdatedToken = @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE";

    namedUserSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UANamedUserAPIClientSuccessBlock successBlock = (__bridge UANamedUserAPIClientSuccessBlock)arg;
        successBlock();
    };

    namedUserFailureDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UANamedUserAPIClientFailureBlock failureBlock = (__bridge UANamedUserAPIClientFailureBlock)arg;
        failureBlock(400);
    };

    self.addTagGroups = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *tagsToAdd = [NSMutableDictionary dictionary];
    NSArray *addTagsArray = @[@"tag1", @"tag2", @"tag3"];
    [tagsToAdd setValue:addTagsArray forKey:@"tag_group"];
    self.addTagGroups = tagsToAdd;

    self.removeTagGroups = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *tagsToRemove = [NSMutableDictionary dictionary];
    NSArray *removeTagsArray = @[@"tag3", @"tag4", @"tag5"];
    [tagsToRemove setValue:removeTagsArray forKey:@"tag_group"];
    self.removeTagGroups = tagsToRemove;

    self.mockTagGroupsAPIClient = [OCMockObject niceMockForClass:[UATagGroupsAPIClient class]];
    self.namedUser.tagGroupsAPIClient = self.mockTagGroupsAPIClient;
}

- (void)tearDown {
    [self.dataStore removeAll];
    [self.mockedNamedUserClient stopMocking];
    [self.mockedAirship stopMocking];
    [self.mockedUAPush stopMocking];
    [self.mockTagGroupsAPIClient stopMocking];
    [self.mockApplication stopMocking];
    [self.mockConfig stopMocking];

    [super tearDown];
}

/**
 * Test set valid ID (associate).
 */
- (void)testSetIDValid {
    NSString *changeToken = self.namedUser.changeToken;
    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] associate:@"superFakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                         onSuccess:OCMOCK_ANY
                                                                         onFailure:OCMOCK_ANY];

    self.namedUser.identifier = @"superFakeNamedUser";

    XCTAssertEqualObjects(@"superFakeNamedUser", self.namedUser.identifier,
                          @"Named user ID should be set.");
    XCTAssertEqualObjects(@"superFakeNamedUser", [self.dataStore stringForKey:UANamedUserIDKey],
                          @"Named user ID should be stored in standardUserDefaults.");
    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change tokens should have changed.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be associated");
}

/**
 * Test set invalid ID.
 */
- (void)testSetIDInvalid {
    NSString *changeToken = self.namedUser.changeToken;
    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    NSString *currentID = self.namedUser.identifier;
    self.namedUser.identifier = @"         ";

    XCTAssertEqualObjects(currentID, self.namedUser.identifier,
                          @"Named user ID should not have changed.");
    XCTAssertEqualObjects(changeToken, self.namedUser.changeToken,
                          @"Change tokens should remain the same.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should not be associated");
}

/**
 * Test set nil ID (disassociate).
 */
- (void)testSetIDNil {
    NSString *changeToken = self.namedUser.changeToken;
    // Expect the named user client to disassociate and call the success block
    [[self.mockedNamedUserClient expect] disassociate:@"someChannel"
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];
    self.namedUser.identifier = nil;

    XCTAssertNil(self.namedUser.identifier, @"Named user ID should be nil.");
    XCTAssertNil([self.dataStore stringForKey:UANamedUserIDKey],
                 @"Named user ID should be able to be cleared in standardUserDefaults.");
    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change tokens should have changed.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be disassociated");
}

/**
 * Test set ID when channel doesn't exist sets ID, but fails to associate
 */
- (void)testSetIDNoChannel {
    self.pushChannelID = nil;

    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    NSString *changeToken = self.namedUser.changeToken;
    NSString *lastUpdatedToken = self.namedUser.lastUpdatedToken;

    self.namedUser.identifier = @"kindaFakeNamedUser";

    XCTAssertEqualObjects(@"kindaFakeNamedUser", self.namedUser.identifier,
                          @"Named user ID should match.");
    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Named user change token should not remain the same.");
    XCTAssertEqualObjects(lastUpdatedToken, self.namedUser.lastUpdatedToken,
                          @"Named user last updated token should remain the same.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should not be associated");
}

/**
 * Test when IDs match, don't update named user
 */
- (void)testIDsMatchNoUpdate {
    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    NSString *currentID = self.namedUser.identifier;
    NSString *changeToken = self.namedUser.changeToken;
    NSString *lastUpdatedToken = self.namedUser.lastUpdatedToken;

    self.namedUser.identifier = currentID;

    XCTAssertEqualObjects(currentID, self.namedUser.identifier,
                          @"Named user ID should match.");
    XCTAssertEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Named user change token should remain the same.");
    XCTAssertEqualObjects(lastUpdatedToken, self.namedUser.lastUpdatedToken,
                          @"Named user last updated token should remain the same.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should not be associated");
}

/**
 * Test set change token.
 */
- (void)testSetChangeToken {
    self.namedUser.changeToken = @"fakeChangeToken";
    XCTAssertEqualObjects(@"fakeChangeToken", self.namedUser.changeToken,
                          @"Named user change token should be set.");
    XCTAssertEqualObjects(@"fakeChangeToken", [self.dataStore stringForKey:UANamedUserChangeTokenKey],
                          @"Named user change token should be stored in standardUserDefaults.");
}

/**
 * Test set last updated token.
 */
- (void)testSetLastUpdatedToken {
    self.namedUser.lastUpdatedToken = @"fakeLastUpdatedToken";
    XCTAssertEqualObjects(@"fakeLastUpdatedToken", self.namedUser.lastUpdatedToken,
                          @"Named user lsat updated token should be set.");
    XCTAssertEqualObjects(@"fakeLastUpdatedToken", [self.dataStore stringForKey:UANamedUserLastUpdatedTokenKey],
                          @"Named user last updated token should be stored in standardUserDefaults.");
}

/**
 * Test update will skip update on a new or re-install.
 */
- (void)testUpdateSkipUpdateOnNewInstall {
    self.namedUser.changeToken = nil;
    self.namedUser.lastUpdatedToken = nil;

    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];

    [self.namedUser update];

    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user client should not associate or disassociate.");
}

/**
 * Test update will skip update when named user already updated.
 */
- (void)testUpdateSkipUpdateSameNamedUser {
    self.namedUser.changeToken = @"AbcToken";
    self.namedUser.lastUpdatedToken = @"AbcToken";

    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];

    [self.namedUser update];

    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user client should not associate or disassociate.");
}

/**
 * Test update will skip update when channel ID doesn't exist.
 */
- (void)testUpdateSkipUpdateNoChannel {
    self.pushChannelID = nil;

    self.namedUser.changeToken = @"AbcToken";
    self.namedUser.lastUpdatedToken = @"XyzToken";

    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];

    [self.namedUser update];

    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user client should not associate or disassociate.");
}

/**
 * Test disassociateNamedUserIfNil when named user is nil.
 */
- (void)testDisassociateNamedUserNil {
    self.namedUser.identifier = nil;

    // Expect the named user client to disassociate
    [[self.mockedNamedUserClient expect] disassociate:@"someChannel"
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];


    self.namedUser.changeToken = nil;
    [self.namedUser disassociateNamedUserIfNil];

    XCTAssertNil(self.namedUser.identifier, @"Named user ID should remain nil.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user should be disassociated");
}

/**
 * Test disassociateNamedUserIfNil when named user is not nil.
 */
- (void)testDisassociateNamedUserNonNil {

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];

    [self.namedUser disassociateNamedUserIfNil];

    XCTAssertEqualObjects(@"fakeNamedUser", self.namedUser.identifier,
                          @"Named user ID should remain the same.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user should not be disassociated");
}

/**
 * Test force update changes the current token and updates named user.
 */
- (void)testForceUpdate {
    NSString *changeToken = self.namedUser.changeToken;

    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                         onSuccess:OCMOCK_ANY
                                                                         onFailure:OCMOCK_ANY];

    [self.namedUser forceUpdate];

    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change token should have changed.");
    XCTAssertEqualObjects(self.namedUser.changeToken, self.namedUser.lastUpdatedToken,
                          @"Tokens should match.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be associated");
}

/**
 * Test updating tag groups calls the tag client for every pending mutation.
 */
- (void)testUpdateTagGroups {
    // Background task
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    // Channel
    self.namedUser.identifier = @"named_user";

    // Expect a set mutation, return 200
    [[[self.mockTagGroupsAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(NSUInteger) = (__bridge void (^)(NSUInteger))arg;
        completionHandler(200);
    }] updateNamedUser:@"named_user"
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"set": @{ @"group2": @[@"tag1"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];


    // Expect Add & Remove mutations, return 200
    [[[self.mockTagGroupsAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(NSUInteger) = (__bridge void (^)(NSUInteger))arg;
        completionHandler(200);
    }] updateNamedUser:@"named_user"
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group1": @[@"tag2"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];

    [self.namedUser addTags:@[@"tag1"] group:@"group1"];
    [self.namedUser removeTags:@[@"tag2"] group:@"group1"];
    [self.namedUser setTags:@[@"tag1"] group:@"group2"];

    [self.namedUser updateTags];
    
    [self.mockTagGroupsAPIClient verify];
}

@end
