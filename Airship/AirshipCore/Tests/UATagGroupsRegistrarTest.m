/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UATaskManager.h"

static NSString * const UATagGroupsUpdateTaskID = @"UATagGroups.update";

@interface UATagGroupsRegistrarTest : UAAirshipBaseTest
@property (nonatomic, strong) UAPendingTagGroupStore *pendingTagGroupStore;
@property (nonatomic, strong) UATagGroupsRegistrar *registrar;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockApiClient;
@property (nonatomic, strong) id mockTaskManager;
@property (nonatomic, strong) id mockTask;
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
    
    self.mockTask = [self mockForProtocol:@protocol(UATask)];
    
    self.mockTaskManager = [self mockForClass:[UATaskManager class]];
}

/**
 * Test updating tag groups calls the tag client for every pending mutation.
 */

- (void)testUpdateTagGroups {
    // Expect a set mutation, return 200
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(NSError *) = (__bridge void (^)(NSError *))arg;
        completionHandler(nil);
    }] updateTagGroupsForId:@"someID"
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"set": @{ @"group2": @[@"tag1"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];

    [[self.mockTask expect] taskCompleted];

    [self.registrar addTags:@[@"tag1"] group:@"group1"];
    [self.registrar removeTags:@[@"tag2"] group:@"group1"];
    [self.registrar setTags:@[@"tag1"] group:@"group2"];
    
    [self updateTagGroups];
    
    [self.mockApiClient verify];
    
    [self.mockTask verify];
}

- (void)testUpdateTagGroupsDoesNotPopOrContinueAfterUnsuccessfulStatus {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Async update tag groups call"];

    NSDictionary *expectedInitialPayload = @{@"set": @{ @"group2": @[@"tag1"] } };
    NSDictionary *expectedSecondPayload = @{@"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group1": @[@"tag2"] } };

    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(NSError *) = (__bridge void (^)(NSError *))arg;
        [expectation fulfill];
        completionHandler([NSError errorWithDomain:UATagGroupsAPIClientErrorDomain
                                              code:UATagGroupsAPIClientErrorUnsuccessfulStatus
                                          userInfo:@{}]);
    }] updateTagGroupsForId:@"someID"
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        return [expectedInitialPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];

    [[self.mockTask expect] taskFailed];
    
    [self.registrar addTags:@[@"tag1"] group:@"group1"];
    [self.registrar removeTags:@[@"tag2"] group:@"group1"];
    [self.registrar setTags:@[@"tag1"] group:@"group2"];

    [self updateTagGroups];

    [self waitForTestExpectations];

    [self.mockApiClient verify];
    
    [self.mockTask verify];

    XCTAssertEqualObjects([self.pendingTagGroupStore peekPendingMutation].payload, expectedInitialPayload);
    [self.pendingTagGroupStore popPendingMutation];
    XCTAssertEqualObjects([self.pendingTagGroupStore peekPendingMutation].payload, expectedSecondPayload);
}

- (void)testUpdateTagGroupsDoesNotPopOrContinueAfterError {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Async update tag groups call"];

    NSDictionary *expectedInitialPayload = @{@"set": @{ @"group2": @[@"tag1"] } };
    NSDictionary *expectedSecondPayload = @{@"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group1": @[@"tag2"] } };

    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(NSError *) = (__bridge void (^)(NSError *))arg;
        [expectation fulfill];
        completionHandler([NSError errorWithDomain:@"error" code:0 userInfo:@{}]);
    }] updateTagGroupsForId:@"someID"
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        return [expectedInitialPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];

    [[self.mockApiClient reject] updateTagGroupsForId:OCMOCK_ANY tagGroupsMutation:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.registrar addTags:@[@"tag1"] group:@"group1"];
    [self.registrar removeTags:@[@"tag2"] group:@"group1"];
    [self.registrar setTags:@[@"tag1"] group:@"group2"];

    [self updateTagGroups];

    [self waitForTestExpectations];

    [self.mockApiClient verify];

    XCTAssertEqualObjects([self.pendingTagGroupStore peekPendingMutation].payload, expectedInitialPayload);
    [self.pendingTagGroupStore popPendingMutation];
    XCTAssertEqualObjects([self.pendingTagGroupStore peekPendingMutation].payload, expectedSecondPayload);
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

- (void)updateTagGroups {
    __block UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend requiresNetwork:YES extras:nil];

    [[[self.mockTask stub] andReturn:UATagGroupsUpdateTaskID] taskID];
    [[[self.mockTask stub] andReturn:options] requestOptions];
    
    [self.registrar updateTagGroupsWithTask:self.mockTask completionHandler:^(BOOL completed) {}];
}

@end
