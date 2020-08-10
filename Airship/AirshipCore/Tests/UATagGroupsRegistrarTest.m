/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagGroupsMutation+Internal.h"

@interface UATagGroupsRegistrarTest : UAAirshipBaseTest
@property (nonatomic, strong) UAPendingTagGroupStore *channelPendingTagGroupStore;
@property (nonatomic, strong) UAPendingTagGroupStore *namedPendingTagGroupStore;
@property (nonatomic, strong) UATagGroupsRegistrar *channelRegistrar;
@property (nonatomic, strong) UATagGroupsRegistrar *namedUserRegistrar;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockApiClient;
@end

@implementation UATagGroupsRegistrarTest

- (void)setUp {
    [super setUp];
    
    self.mockApplication = [self mockForClass:[UIApplication class]];

    self.mockApiClient = [self mockForClass:[UATagGroupsAPIClient class]];

    self.channelPendingTagGroupStore = [UAPendingTagGroupStore channelHistoryWithDataStore:self.dataStore];
    
    self.namedPendingTagGroupStore = [UAPendingTagGroupStore namedUserHistoryWithDataStore:self.dataStore];

    self.channelRegistrar = [UATagGroupsRegistrar tagGroupsRegistrarWithPendingTagGroupStore:self.channelPendingTagGroupStore
                                                                                   apiClient:self.mockApiClient
                                                                                 application:self.mockApplication];
    
    self.namedUserRegistrar = [UATagGroupsRegistrar tagGroupsRegistrarWithPendingTagGroupStore:self.namedPendingTagGroupStore
                                                                                     apiClient:self.mockApiClient
                                                                                   application:self.mockApplication];

    [self.channelRegistrar setIdentifier:@"someID" clearPendingOnChange:NO];
    [self.namedUserRegistrar setIdentifier:@"someID" clearPendingOnChange:NO];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test updating tag groups calls the tag client for every pending mutation.
 */

- (void)testUpdateTagGroupsForAnID {
    NSString *testID = @"someID";
    // Background task
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Async update tag groups call"];

    // Expect a set mutation, return 200
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(NSUInteger) = (__bridge void (^)(NSUInteger))arg;
        completionHandler(200);
    }] updateTagGroupsForId:testID
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"set": @{ @"group2": @[@"tag1"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];

    // Expect Add & Remove mutations, return 200
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        [expectation fulfill];

        void (^completionHandler)(NSUInteger) = (__bridge void (^)(NSUInteger))arg;
        completionHandler(200);
    }] updateTagGroupsForId:testID
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group1": @[@"tag2"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];

    [[self.mockApplication expect] endBackgroundTask:30];
    
    [self.channelRegistrar addTags:@[@"tag1"] group:@"group1"];
    [self.channelRegistrar removeTags:@[@"tag2"] group:@"group1"];
    [self.channelRegistrar setTags:@[@"tag1"] group:@"group2"];
    
    [self.channelRegistrar updateTagGroupsForID:testID];

    [self waitForTestExpectations];
    
    [self.mockApiClient verify];
}

- (void)testUpdateTagGroupsWithInvalidBackground {
    // SETUP
    [self.channelRegistrar addTags:@[@"tag1"] group:@"group1"];
    
    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // EXPECTATIONS
    [[self.mockApiClient reject] updateTagGroupsForId:OCMOCK_ANY
                                    tagGroupsMutation:OCMOCK_ANY
                                    completionHandler:OCMOCK_ANY];

    // TEST
    [self.channelRegistrar updateTagGroupsForID:@"someID"];
    
    // VERIFY
    [self.mockApiClient verify];
}

- (void)testSetEmptyTagListClearsTags {
    [self.channelRegistrar setTags:@[@"tag2", @"tag1"] group: @"group"];

    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [self.channelPendingTagGroupStore peekPendingMutation].payload);
}

- (void)testSetWithEmptyGroupDoesntSetTags {
    [self.channelRegistrar setTags:@[@"tag1"] group:@""];

    XCTAssertNil([self.channelPendingTagGroupStore peekPendingMutation]);
}

- (void)testAddEmptyTagListOrEmptyGroupDoesntAddTags {
    [self.channelRegistrar addTags:@[] group:@"group1"];
    [self.channelRegistrar addTags:@[@"tag1"] group:@""];

    XCTAssertNil([self.channelPendingTagGroupStore peekPendingMutation]);
}

- (void)testRemoveEmptyTagListOrEmptyGroupDoesntRemoveTags {
    [self.channelRegistrar setTags:@[@"tag2", @"tag1"] group:@"group"];
    [self.channelRegistrar removeTags:@[] group:@"group"];
    [self.channelRegistrar removeTags:@[@"tag1"] group:@""];

    // Should still only be the set mutation
    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [self.channelPendingTagGroupStore peekPendingMutation].payload);
}

- (void)testChannelAndNamedUserTagsAreIndependent {
    [self.channelRegistrar setTags:@[@"tag1"] group:@"cool"];
    [self.namedUserRegistrar setTags:@[@"tag2"] group:@"cool"];

    NSDictionary *channelExpectedPayload = @{ @"set": @{ @"cool": @[@"tag1"] } };
    XCTAssertEqualObjects(channelExpectedPayload, [self.channelPendingTagGroupStore peekPendingMutation].payload);

    NSDictionary *namedUserExpectedPayload = @{ @"set": @{ @"cool": @[@"tag2"] } };
    XCTAssertEqualObjects(namedUserExpectedPayload, [self.namedPendingTagGroupStore peekPendingMutation].payload);
}

- (void)testClearAllPendingUpdatesCancelsAndClearsMutations {
    [self.namedUserRegistrar setTags:@[@"tag2"] group:@"cool"];

    NSDictionary *namedUserExpectedPayload = @{ @"set": @{ @"cool": @[@"tag2"] } };
    XCTAssertEqualObjects(namedUserExpectedPayload, [self.namedPendingTagGroupStore peekPendingMutation].payload);

    [self.namedUserRegistrar clearPendingMutations];

    XCTAssertNil([self.namedPendingTagGroupStore peekPendingMutation]);
}

- (void)testEnabledByDefault {
    XCTAssertTrue(self.channelRegistrar.enabled);
}

- (void)testSetEnabled {
    [[self.mockApiClient expect] setEnabled:NO];
    self.channelRegistrar.enabled = NO;
    XCTAssertFalse(self.channelRegistrar.enabled);
    [self.mockApiClient verify];
}

- (void)testSetIdentifier {
    [self.channelRegistrar setTags:@[@"tag2", @"tag1"] group: @"group"];
    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1"] } };
    [self.channelRegistrar setIdentifier:@"cool" clearPendingOnChange:NO];
    XCTAssertEqual(self.channelRegistrar.pendingMutations.count, 1);
    XCTAssertEqualObjects(self.channelRegistrar.pendingMutations.firstObject.payload, expected);

}

- (void)testSetIdentifierClearPending {
    [self.channelRegistrar setTags:@[@"tag2", @"tag1"] group: @"group"];
    [self.channelRegistrar setIdentifier:@"cool" clearPendingOnChange:YES];
    XCTAssertEqual(self.channelRegistrar.pendingMutations.count, 0);
}

@end
