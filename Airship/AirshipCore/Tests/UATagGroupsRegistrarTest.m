/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagGroupsMutation+Internal.h"

@interface UATagGroupsRegistrarTest : UAAirshipBaseTest
@property (nonatomic, strong) UAPendingTagGroupStore *pendingTagGroupStore;
@property (nonatomic, strong) UATagGroupsRegistrar *registrar;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockApiClient;
@end

@implementation UATagGroupsRegistrarTest

- (void)setUp {
    [super setUp];
    
    self.mockApplication = [self mockForClass:[UIApplication class]];

    self.mockApiClient = [self mockForClass:[UATagGroupsAPIClient class]];

    self.pendingTagGroupStore = [UAPendingTagGroupStore channelHistoryWithDataStore:self.dataStore];

    self.registrar = [UATagGroupsRegistrar tagGroupsRegistrarWithPendingTagGroupStore:self.pendingTagGroupStore
                                                                            apiClient:self.mockApiClient
                                                                          application:self.mockApplication];

    [self.registrar setIdentifier:@"someID" clearPendingOnChange:NO];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test updating tag groups calls the tag client for every pending mutation.
 */

- (void)testUpdateTagGroups {
    // Background task
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Async update tag groups call"];

    // Expect a set mutation, return 200
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(NSUInteger) = (__bridge void (^)(NSUInteger))arg;
        completionHandler(200);
    }] updateTagGroupsForId:@"someID"
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
    }] updateTagGroupsForId:@"someID"
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group1": @[@"tag2"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];

    [[self.mockApplication expect] endBackgroundTask:30];
    
    [self.registrar addTags:@[@"tag1"] group:@"group1"];
    [self.registrar removeTags:@[@"tag2"] group:@"group1"];
    [self.registrar setTags:@[@"tag1"] group:@"group2"];
    
    [self.registrar updateTagGroups];

    [self waitForTestExpectations];
    
    [self.mockApiClient verify];
}

- (void)testUpdateTagGroupsWithInvalidBackground {
    // SETUP
    [self.registrar addTags:@[@"tag1"] group:@"group1"];
    
    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // EXPECTATIONS
    [[self.mockApiClient reject] updateTagGroupsForId:OCMOCK_ANY
                                    tagGroupsMutation:OCMOCK_ANY
                                    completionHandler:OCMOCK_ANY];

    // TEST
    [self.registrar updateTagGroups];
    
    // VERIFY
    [self.mockApiClient verify];
}

- (void)testSetEmptyTagListClearsTags {
    [self.registrar setTags:@[@"tag2", @"tag1"] group: @"group"];

    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [self.pendingTagGroupStore peekPendingMutation].payload);
}

- (void)testSetWithEmptyGroupDoesntSetTags {
    [self.registrar setTags:@[@"tag1"] group:@""];

    XCTAssertNil([self.pendingTagGroupStore peekPendingMutation]);
}

- (void)testAddEmptyTagListOrEmptyGroupDoesntAddTags {
    [self.registrar addTags:@[] group:@"group1"];
    [self.registrar addTags:@[@"tag1"] group:@""];

    XCTAssertNil([self.pendingTagGroupStore peekPendingMutation]);
}

- (void)testRemoveEmptyTagListOrEmptyGroupDoesntRemoveTags {
    [self.registrar setTags:@[@"tag2", @"tag1"] group:@"group"];
    [self.registrar removeTags:@[] group:@"group"];
    [self.registrar removeTags:@[@"tag1"] group:@""];

    // Should still only be the set mutation
    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [self.pendingTagGroupStore peekPendingMutation].payload);
}

- (void)testClearAllPendingUpdatesCancelsAndClearsMutations {
    [self.registrar setTags:@[@"tag2"] group:@"cool"];

    NSDictionary *expected = @{ @"set": @{ @"cool": @[@"tag2"] } };
    XCTAssertEqualObjects(expected, [self.pendingTagGroupStore peekPendingMutation].payload);

    [self.registrar clearPendingMutations];

    XCTAssertNil([self.pendingTagGroupStore peekPendingMutation]);
}

- (void)testEnabledByDefault {
    XCTAssertTrue(self.registrar.enabled);
}

- (void)testSetEnabled {
    [[self.mockApiClient expect] setEnabled:NO];
    self.registrar.enabled = NO;
    XCTAssertFalse(self.registrar.enabled);
    [self.mockApiClient verify];
}

- (void)testSetIdentifier {
    [self.registrar setTags:@[@"tag2", @"tag1"] group: @"group"];
    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1"] } };
    [self.registrar setIdentifier:@"cool" clearPendingOnChange:NO];
    XCTAssertEqual(self.registrar.pendingMutations.count, 1);
    XCTAssertEqualObjects(self.registrar.pendingMutations.firstObject.payload, expected);

}

- (void)testSetIdentifierClearPending {
    [self.registrar setTags:@[@"tag2", @"tag1"] group: @"group"];
    [self.registrar setIdentifier:@"cool" clearPendingOnChange:YES];
    XCTAssertEqual(self.registrar.pendingMutations.count, 0);
}

@end
