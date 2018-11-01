/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagGroupsMutation+Internal.h"

@interface UATagGroupsRegistrarTest : UABaseTest
@property (nonatomic, strong) UATagGroupsMutationHistory *mutationHistory;
@property (nonatomic, strong) UATagGroupsRegistrar *registrar;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockApiClient;
@end

@implementation UATagGroupsRegistrarTest

- (void)setUp {
    [super setUp];
    
    self.mockApplication = [self mockForClass:[UIApplication class]];

    self.mockApiClient = [self mockForClass:[UATagGroupsAPIClient class]];

    self.operationQueue = [[NSOperationQueue alloc] init];

    self.mutationHistory = [UATagGroupsMutationHistory historyWithDataStore:self.dataStore];

    self.registrar = [UATagGroupsRegistrar tagGroupsRegistrarWithDataStore:self.dataStore
                                                           mutationHistory:self.mutationHistory
                                                                 apiClient:self.mockApiClient
                                                            operationQueue:self.operationQueue
                                                               application:self.mockApplication];
}

- (void)tearDown {
    [self.operationQueue cancelAllOperations];
    [self.operationQueue waitUntilAllOperationsAreFinished];
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
        [invocation getArgument:&arg atIndex:5];

        void (^completionHandler)(NSUInteger) = (__bridge void (^)(NSUInteger))arg;
        completionHandler(200);
    }] updateTagGroupsForId:testID
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"set": @{ @"group2": @[@"tag1"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] type:UATagGroupsTypeChannel completionHandler:OCMOCK_ANY];

    // Expect Add & Remove mutations, return 200
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];

        [expectation fulfill];

        void (^completionHandler)(NSUInteger) = (__bridge void (^)(NSUInteger))arg;
        completionHandler(200);
    }] updateTagGroupsForId:testID
     tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"add": @{ @"group1": @[@"tag1"] }, @"remove": @{ @"group1": @[@"tag2"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] type:UATagGroupsTypeChannel completionHandler:OCMOCK_ANY];
    
    [self.registrar addTags:@[@"tag1"] group:@"group1" type:UATagGroupsTypeChannel];
    [self.registrar removeTags:@[@"tag2"] group:@"group1" type:UATagGroupsTypeChannel];
    [self.registrar setTags:@[@"tag1"] group:@"group2" type:UATagGroupsTypeChannel];
    
    [self.registrar updateTagGroupsForID:testID type:UATagGroupsTypeChannel];
    
    // wait until the queue clears
    XCTestExpectation *endBackgroundTaskExpecation = [self expectationWithDescription:@"End of background task"];
    [[[[self.mockApplication expect] ignoringNonObjectArgs] andDo:^(NSInvocation *invocation) {
        [endBackgroundTaskExpecation fulfill];
    }] endBackgroundTask:0];

    [self waitForTestExpectations];
    
    [self.mockApiClient verify];
}

- (void)testUpdateTagGroupsWithInvalidBackground {
    // SETUP
    [self.registrar addTags:@[@"tag1"] group:@"group1" type:UATagGroupsTypeChannel];
    
    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // EXPECTATIONS
    [[self.mockApiClient reject] updateTagGroupsForId:OCMOCK_ANY
                                    tagGroupsMutation:OCMOCK_ANY
                                                 type:UATagGroupsTypeChannel
                                    completionHandler:OCMOCK_ANY];

    // TEST
    [self.registrar updateTagGroupsForID:@"someID" type:UATagGroupsTypeChannel];
    
    // VERIFY
    [self.mockApiClient verify];
}

- (void)testSetEmptyTagListClearsTags {
    [self.registrar setTags:@[@"tag2", @"tag1"] group: @"group" type:UATagGroupsTypeChannel];
    [self.operationQueue waitUntilAllOperationsAreFinished];

    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [self.mutationHistory peekPendingMutation:UATagGroupsTypeChannel].payload);
}

- (void)testSetWithEmptyGroupDoesntSetTags {
    [self.registrar setTags:@[@"tag1"] group:@"" type:UATagGroupsTypeChannel];
    [self.operationQueue waitUntilAllOperationsAreFinished];

    XCTAssertNil([self.mutationHistory peekPendingMutation:UATagGroupsTypeChannel]);
}

- (void)testAddEmptyTagListOrEmptyGroupDoesntAddTags {
    [self.registrar addTags:@[] group:@"group1" type:UATagGroupsTypeChannel];
    [self.registrar addTags:@[@"tag1"] group:@"" type:UATagGroupsTypeChannel];
    [self.operationQueue waitUntilAllOperationsAreFinished];

    XCTAssertNil([self.mutationHistory peekPendingMutation:UATagGroupsTypeChannel]);
}

- (void)testRemoveEmptyTagListOrEmptyGroupDoesntRemoveTags {
    [self.registrar setTags:@[@"tag2", @"tag1"] group:@"group" type:UATagGroupsTypeChannel];
    [self.registrar removeTags:@[] group:@"group" type:UATagGroupsTypeChannel];
    [self.registrar removeTags:@[@"tag1"] group:@"" type:UATagGroupsTypeChannel];

    [self.operationQueue waitUntilAllOperationsAreFinished];

    // Should still only be the set mutation
    NSDictionary *expected = @{ @"set": @{ @"group": @[@"tag2", @"tag1"] } };
    XCTAssertEqualObjects(expected, [self.mutationHistory peekPendingMutation:UATagGroupsTypeChannel].payload);
}

- (void)testChannelAndNamedUserTagsAreIndependent {
    [self.registrar setTags:@[@"tag1"] group:@"cool" type:UATagGroupsTypeChannel];
    [self.registrar setTags:@[@"tag2"] group:@"cool" type:UATagGroupsTypeNamedUser];

    [self.operationQueue waitUntilAllOperationsAreFinished];

    NSDictionary *channelExpectedPayload = @{ @"set": @{ @"cool": @[@"tag1"] } };
    XCTAssertEqualObjects(channelExpectedPayload, [self.mutationHistory peekPendingMutation:UATagGroupsTypeChannel].payload);

    NSDictionary *namedUserExpectedPayload = @{ @"set": @{ @"cool": @[@"tag2"] } };
    XCTAssertEqualObjects(namedUserExpectedPayload, [self.mutationHistory peekPendingMutation:UATagGroupsTypeNamedUser].payload);
}

- (void)testClearAllPendingUpdatesCancelsAndClearsMutations {
    [self.registrar setTags:@[@"tag2"] group:@"cool" type:UATagGroupsTypeNamedUser];
    [self.operationQueue waitUntilAllOperationsAreFinished];

    NSDictionary *namedUserExpectedPayload = @{ @"set": @{ @"cool": @[@"tag2"] } };
    XCTAssertEqualObjects(namedUserExpectedPayload, [self.mutationHistory peekPendingMutation:UATagGroupsTypeNamedUser].payload);

    [self.registrar clearAllPendingTagUpdates:UATagGroupsTypeNamedUser];
    [self.operationQueue waitUntilAllOperationsAreFinished];

    XCTAssertNil([self.mutationHistory peekPendingMutation:UATagGroupsTypeNamedUser]);
}

@end
