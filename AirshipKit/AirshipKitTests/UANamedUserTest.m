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
#import "UAHTTPRequest+Internal.h"

@interface UANamedUserTest : XCTestCase

@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) UANamedUser *namedUser;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) id mockedNamedUserClient;
@property (nonatomic, strong) id mockedUAPush;
@property (nonatomic, strong) UAHTTPRequest *namedUserFailureRequest;
@property (nonatomic, copy) NSString *pushChannelID;

@property (nonatomic, strong) id mockTagGroupsAPIClient;
@property (nonatomic, strong) NSMutableDictionary *addTagGroups;
@property (nonatomic, strong) NSMutableDictionary *removeTagGroups;
@property (nonatomic, strong) UAHTTPRequest *tagsFailureRequest;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockConfig;


@end

@implementation UANamedUserTest

void (^namedUserSuccessDoBlock)(NSInvocation *);
void (^namedUserFailureDoBlock)(NSInvocation *);

void (^updateTagsSuccessDoBlock)(NSInvocation *);
void (^updateTagsFailureDoBlock)(NSInvocation *);

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

    self.namedUserFailureRequest = [[UAHTTPRequest alloc] init];

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
        failureBlock(self.namedUserFailureRequest);
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

    self.tagsFailureRequest = [[UAHTTPRequest alloc] init];

    updateTagsSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UATagGroupsAPIClientSuccessBlock successBlock = (__bridge UATagGroupsAPIClientSuccessBlock)arg;
        successBlock();
    };

    updateTagsFailureDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:6];
        UATagGroupsAPIClientFailureBlock failureBlock = (__bridge UATagGroupsAPIClientFailureBlock)arg;
        failureBlock(self.tagsFailureRequest);
    };
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
 * Tests tag group addition when tag group contains white space
 */
- (void)testAddTagGroupWhitespaceRemoval {
    NSArray *tags = @[@"   tag-one   ", @"tag-two   "];
    NSArray *tagsNoSpaces = @[@"tag-one", @"tag-two"];
    NSString *groupID = @"test_group_id";

    [self.namedUser addTags:tags group:groupID];

    XCTAssertEqualObjects(tagsNoSpaces, [self.namedUser.pendingAddTags valueForKey:groupID], @"whitespace was not trimmed from tags");

    NSArray *moreTags = @[@"   tag-two   ", @"tag-three   "];

    [self.namedUser addTags:moreTags group:groupID];

    NSMutableArray *combinedTags = [NSMutableArray arrayWithArray:@[@"tag-one", @"tag-two", @"tag-three"]];

    [combinedTags removeObjectsInArray:[self.namedUser.pendingAddTags valueForKey:groupID]];

    XCTAssertTrue(combinedTags.count == 0, @"whitespace was not trimmed from tags");
}

/**
 * Tests tag group removal when tag group contains white space
 */
- (void)testRemoveTagGroupWhitespaceRemoval {
    NSArray *tags = @[@"   tag-one   ", @"tag-two   "];
    NSArray *tagsNoSpaces = @[@"tag-one", @"tag-two"];
    NSString *groupID = @"test_group_id";

    [self.namedUser removeTags:tags group:groupID];

    XCTAssertEqualObjects(tagsNoSpaces, [self.namedUser.pendingRemoveTags valueForKey:groupID], @"whitespace was not trimmed from tags");

    NSArray *moreTags = @[@"   tag-two   ", @"tag-three   "];

    [self.namedUser removeTags:moreTags group:groupID];

    NSMutableArray *combinedTags = [NSMutableArray arrayWithArray:@[@"tag-one", @"tag-two", @"tag-three"]];

    [combinedTags removeObjectsInArray:[self.namedUser.pendingRemoveTags valueForKey:groupID]];

    XCTAssertTrue(combinedTags.count == 0, @"whitespace was not trimmed from tags");
}

/**
 * Test pendingAddTags.
 */
- (void)testPendingAddTags {
    self.namedUser.pendingAddTags = self.addTagGroups;

    XCTAssertEqual((NSUInteger)1, self.namedUser.pendingAddTags.count, @"should contain 1 tag group");
    XCTAssertEqualObjects(self.addTagGroups, self.namedUser.pendingAddTags, @"pendingAddTags are not stored correctly");
    XCTAssertEqualObjects([self.dataStore valueForKey:UANamedUserAddTagGroupsSettingsKey], self.namedUser.pendingAddTags,
                          @"pendingAddTags are not stored correctly in standardUserDefaults");

    // Test addTags
    NSArray *tags = @[@"tag1", @"tag2", @"tag3"];
    [self.namedUser addTags:tags group:@"another-tag-group"];

    XCTAssertEqual((NSUInteger)2, self.namedUser.pendingAddTags.count, @"should contain 2 tag groups");

    // Test addTags with overlapping tags in same group
    NSArray *tags2 = @[@"tag3", @"tag4", @"tag5"];
    [self.namedUser addTags:tags2 group:@"another-tag-group"];
    XCTAssertEqual((NSUInteger)2, self.namedUser.pendingAddTags.count, @"should contain 2 tag groups");
    NSArray *anotherTagArray = [self.namedUser.pendingAddTags objectForKey:@"another-tag-group"];
    XCTAssertEqual((NSUInteger)5, anotherTagArray.count, @"should contain 5 tags in array");

    // Test addTags with empty tags
    NSArray *emptyTagsArray = @[];
    [self.namedUser addTags:emptyTagsArray group:@"some-tag-group"];
    XCTAssertEqual((NSUInteger)2, self.namedUser.pendingAddTags.count, @"should still contain 2 tag groups");

    // Test addTags with tags with whitespace
    NSArray *whitespaceTags = @[@" tag1 ", @" tag2 ", @" tag3 "];
    [self.namedUser addTags:whitespaceTags group:@"another-tag-group"];
    XCTAssertEqual((NSUInteger)2, self.namedUser.pendingAddTags.count, @"should contain 2 tag groups");

    self.namedUser.pendingAddTags = nil;
    XCTAssertEqual((NSUInteger)0, self.namedUser.pendingAddTags.count, @"pendingAddTags should return an empty dictionary when set to nil");
    XCTAssertEqual((NSUInteger)0, [[self.dataStore valueForKey:UANamedUserAddTagGroupsSettingsKey] count],
                   @"pendingAddTags not being cleared in standardUserDefaults");
}

/**
 * Test pendingAddTags when pendingRemoveTags overlap.
 */
- (void)testAddTagGroupsOverlap {
    self.namedUser.pendingAddTags = nil;
    self.namedUser.pendingRemoveTags = self.removeTagGroups;
    NSArray *removeTagsArray = [self.namedUser.pendingRemoveTags objectForKey:@"tag_group"];
    XCTAssertEqual((NSUInteger)3, removeTagsArray.count, @"should contain 3 tags in array");

    NSArray *tags = @[@"tag1", @"tag2", @"tag3"];
    [self.namedUser addTags:tags group:@"tag_group"];
    NSArray *updatedRemoveTagsArray = [self.namedUser.pendingRemoveTags objectForKey:@"tag_group"];
    XCTAssertEqual((NSUInteger)2, updatedRemoveTagsArray.count, @"should contain 2 tags in array");

    NSArray *addTagsArray = [self.namedUser.pendingAddTags objectForKey:@"tag_group"];
    XCTAssertEqual((NSUInteger)3, addTagsArray.count, @"should contain 3 tags in array");
}

/**
 * Test pendingRemoveTags.
 */
- (void)testRemoveTagGroups {
    self.namedUser.pendingRemoveTags = self.removeTagGroups;

    XCTAssertEqual((NSUInteger)1, self.namedUser.pendingRemoveTags.count, @"should contain 1 tag group");
    XCTAssertEqualObjects(self.removeTagGroups, self.namedUser.pendingRemoveTags, @"pendingRemoveTags are not stored correctly");
    XCTAssertEqualObjects([self.dataStore valueForKey:UANamedUserRemoveTagGroupsSettingsKey], self.namedUser.pendingRemoveTags,
                          @"pendingRemoveTags are not stored correctly in standardUserDefaults");

    // test removeTags
    NSArray *tags = @[@"tag1", @"tag2", @"tag3"];
    [self.namedUser removeTags:tags group:@"another-tag-group"];

    XCTAssertEqual((NSUInteger)2, self.namedUser.pendingRemoveTags.count, @"should contain 2 tag groups");

    // test removeTags with overlapping tags in same group
    NSArray *tags2 = @[@"tag3", @"tag4", @"tag5"];
    [self.namedUser removeTags:tags2 group:@"another-tag-group"];
    XCTAssertEqual((NSUInteger)2, self.namedUser.pendingRemoveTags.count, @"should contain 2 tag groups");
    NSArray *anotherTagArray = [self.namedUser.pendingRemoveTags objectForKey:@"another-tag-group"];
    XCTAssertEqual((NSUInteger)5, anotherTagArray.count, @"should contain 5 tags");

    // test removeTags with empty tags
    NSArray *emptyTagsArray = @[];
    [self.namedUser removeTags:emptyTagsArray group:@"some-tag-group"];
    XCTAssertEqual((NSUInteger)2, self.namedUser.pendingRemoveTags.count, @"should still contain 2 tag groups");

    // test removeTags with empty group ID
    [self.namedUser addTags:tags2 group:@""];
    XCTAssertEqual((NSUInteger)2, self.namedUser.pendingRemoveTags.count, @"should still contain 2 tag groups");

    self.namedUser.pendingRemoveTags = nil;
    XCTAssertEqual((NSUInteger)0, self.namedUser.pendingRemoveTags.count, @"pendingRemoveTags should return an empty dictionary when set to nil");
    XCTAssertEqual((NSUInteger)0, [[self.dataStore valueForKey:UANamedUserRemoveTagGroupsSettingsKey] count],
                   @"pendingRemoveTags not being cleared in standardUserDefaults");
}

/**
 * Test pendingRemoveTags when pendingAddTags overlap.
 */
- (void)testRemoveTagGroupsOverlap {
    self.namedUser.pendingRemoveTags = nil;
    self.namedUser.pendingAddTags = self.addTagGroups;
    NSArray *addTagsArray = [self.namedUser.pendingAddTags objectForKey:@"tag_group"];
    XCTAssertEqual((NSUInteger)3, addTagsArray.count, @"should contain 3 tags in array");

    NSArray *tags = @[@"tag3", @"tag4", @"tag5"];
    [self.namedUser removeTags:tags group:@"tag_group"];
    NSArray *updatedAddTagsArray = [self.namedUser.pendingAddTags objectForKey:@"tag_group"];
    XCTAssertEqual((NSUInteger)2, updatedAddTagsArray.count, @"should contain 2 tags in array");

    NSArray *removeTagsArray = [self.namedUser.pendingRemoveTags objectForKey:@"tag_group"];
    XCTAssertEqual((NSUInteger)3, removeTagsArray.count, @"should contain 3 tags in array");
}

/**
 * Test pending tags intersect.
 */
- (void)testRemoveTagGroupsIntersect {
    self.namedUser.pendingRemoveTags = nil;
    self.namedUser.pendingAddTags = nil;

    NSArray *tags = @[@"tag1", @"tag2", @"tag3"];

    [self.namedUser addTags:tags group:@"tagGroup"];

    NSArray *addTags = [self.namedUser.pendingAddTags objectForKey:@"tagGroup"];
    XCTAssertEqual((NSUInteger)3, addTags.count, @"should contain 3 tags in array");

    [self.namedUser removeTags:tags group:@"tagGroup"];
    XCTAssertNil([self.namedUser.pendingAddTags objectForKey:@"tagGroup"], @"tags should be nil");
    NSArray *removeTags = [self.namedUser.pendingRemoveTags objectForKey:@"tagGroup"];
    XCTAssertEqual((NSUInteger)3, removeTags.count, @"should contain 3 tags in array");

    [self.namedUser addTags:tags group:@"tagGroup"];
    XCTAssertNil([self.namedUser.pendingRemoveTags objectForKey:@"tagGroup"], @"tags should be nil");
    addTags = [self.namedUser.pendingAddTags objectForKey:@"tagGroup"];
    XCTAssertEqual((NSUInteger)3, addTags.count, @"should contain 3 tags in array");
}

/**
 * Test successful update named user tags.
 */
- (void)testUpdateTags {
    self.namedUser.identifier = @"fakeNamedUser";
    self.namedUser.pendingAddTags = self.addTagGroups;
    self.namedUser.pendingRemoveTags = self.removeTagGroups;

    // Expect the tagGroupsAPIClient to update named user tags and call the success block
    [[[self.mockTagGroupsAPIClient expect] andDo:updateTagsSuccessDoBlock] updateNamedUserTags:OCMOCK_ANY
                                                                                           add:OCMOCK_ANY
                                                                                        remove:OCMOCK_ANY
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.namedUser updateTags];

    XCTAssertNoThrow([self.mockTagGroupsAPIClient verify], @"Update named user tag groups should succeed.");
    XCTAssertEqual((NSUInteger)0, self.namedUser.pendingAddTags.count, @"pendingAddTags should return an empty dictionary");
    XCTAssertEqual((NSUInteger)0, self.namedUser.pendingRemoveTags.count, @"pendingRemoveTags should return an empty dictionary");
}

/**
 * Test update named user tags fails and restores original pending tags.
 */
- (void)testUpdateTagGroupsFails {
    self.namedUser.identifier = nil;
    self.namedUser.pendingAddTags = self.addTagGroups;
    self.namedUser.pendingRemoveTags = self.removeTagGroups;

    // Expect the tagGroupsAPIClient to fail to update named user tags and call the failure block
    [[[self.mockTagGroupsAPIClient expect] andDo:updateTagsFailureDoBlock] updateNamedUserTags:OCMOCK_ANY
                                                                                           add:OCMOCK_ANY
                                                                                        remove:OCMOCK_ANY
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.namedUser updateTags];

    XCTAssertNoThrow([self.mockTagGroupsAPIClient verify], @"Update named user tag groups should fail.");
    XCTAssertEqual((NSUInteger)1, self.namedUser.pendingAddTags.count, @"should contain 1 tag group");
    XCTAssertEqual((NSUInteger)1, self.namedUser.pendingRemoveTags.count, @"should contain 1 tag group");
}

/**
 * Test failed update named user tags restores original pending tags and current pending tags.
 */
- (void)testUpdateTagGroupsFailsPendingTags {
    self.namedUser.identifier = @"fakeNamedUser";
    self.namedUser.pendingAddTags = self.addTagGroups;
    self.namedUser.pendingRemoveTags = self.removeTagGroups;

    // Expect the tagGroupsAPIClient to fail to update named user tags and call the failure block
    [[[self.mockTagGroupsAPIClient expect] andDo:updateTagsFailureDoBlock] updateNamedUserTags:OCMOCK_ANY
                                                                                           add:OCMOCK_ANY
                                                                                        remove:OCMOCK_ANY
                                                                                     onSuccess:OCMOCK_ANY
                                                                                     onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.namedUser updateTags];

    XCTAssertNoThrow([self.mockTagGroupsAPIClient verify], @"Update named user tag groups should fail.");
    XCTAssertEqual((NSUInteger)1, self.namedUser.pendingAddTags.count, @"should contain 1 tag group");
    XCTAssertEqual((NSUInteger)1, self.namedUser.pendingRemoveTags.count, @"should contain 1 tag group");
}

/**
 * Test update named user tags with both empty add and remove tags skips request.
 */
- (void)testUpdateTagGroupsEmptyTags {
    self.namedUser.identifier = @"fakeNamedUser";

    // Should not call updateNamedUserTags
    [[self.mockTagGroupsAPIClient reject] updateNamedUserTags:OCMOCK_ANY
                                                          add:OCMOCK_ANY
                                                       remove:OCMOCK_ANY
                                                    onSuccess:OCMOCK_ANY
                                                    onFailure:OCMOCK_ANY];

    [self.namedUser updateTags];

    XCTAssertNoThrow([self.mockTagGroupsAPIClient verify], @"Should skip updateNamedUserTags request.");
}

/**
 * Test update named user tags with empty add tags still makes request.
 */
- (void)testUpdateTagGroupsEmptyAddTags {
    self.namedUser.identifier = @"fakeNamedUser";
    self.namedUser.pendingAddTags = self.addTagGroups;

    // Call updateNamedUserTags
    [[self.mockTagGroupsAPIClient expect] updateNamedUserTags:OCMOCK_ANY
                                                          add:OCMOCK_ANY
                                                       remove:OCMOCK_ANY
                                                    onSuccess:OCMOCK_ANY
                                                    onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.namedUser updateTags];

    XCTAssertNoThrow([self.mockTagGroupsAPIClient verify], @"Should call updateNamedUserTags request.");
}

/**
 * Test update named user tags with empty remove tags still makes request.
 */
- (void)testUpdateTagGroupsEmptyRemoveTags {
    self.namedUser.identifier = @"fakeNamedUser";
    self.namedUser.pendingRemoveTags = self.removeTagGroups;

    // Call updateNamedUserTags
    [[self.mockTagGroupsAPIClient expect] updateNamedUserTags:OCMOCK_ANY
                                                          add:OCMOCK_ANY
                                                       remove:OCMOCK_ANY
                                                    onSuccess:OCMOCK_ANY
                                                    onFailure:OCMOCK_ANY];

    // Mock background task so background task check passes
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)1)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    [self.namedUser updateTags];

    XCTAssertNoThrow([self.mockTagGroupsAPIClient verify], @"Should call updateNamedUserTags request.");
}

/**
 * Test clear pending named user tags when named user ID changes.
 */
- (void)testNamedUserIDChangeClearPendingTags {
    self.namedUser.identifier = @"fakeNamedUser";
    self.namedUser.pendingAddTags = self.addTagGroups;
    self.namedUser.pendingRemoveTags = self.removeTagGroups;

    XCTAssertEqual((NSUInteger)1, self.namedUser.pendingAddTags.count, @"Should contain 1 tag group");
    XCTAssertEqual((NSUInteger)1, self.namedUser.pendingRemoveTags.count, @"Should contain 1 tag group");

    // Change named user ID should clear the pending tags
    self.namedUser.identifier = @"anotherNamedUser";

    XCTAssertNil(self.namedUser.pendingAddTags, @"Pending add tags should be nil");
    XCTAssertNil(self.namedUser.pendingRemoveTags, @"Pending remove tags should be nil");
}

@end
