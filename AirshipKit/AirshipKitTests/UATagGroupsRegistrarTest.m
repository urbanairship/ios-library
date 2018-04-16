/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UAPreferenceDataStore+InternalTagGroupsMutation.h"
#import "UAAsyncOperation+Internal.h"

@interface UATagGroupsRegistrarTest : UABaseTest

@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UATagGroupsRegistrar *channelRegistrar;
@property (nonatomic, strong) UATagGroupsRegistrar *namedUserRegistrar;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockChannelTagGroupsAPIClient;
@property (nonatomic, strong) id mockNamedUserTagGroupsAPIClient;
@property (nonatomic, strong) id mockTagGroupClass;
@property (nonatomic, strong) id mockDataStore;
@property (nonatomic, strong) id mockOperationQueue;

@end

@implementation UATagGroupsRegistrarTest

- (void)setUp {
    [super setUp];
    
    self.mockApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
    
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"uataggroupsregistrar.test."];
    self.mockDataStore = [self partialMockForObject:self.dataStore];
    [self.dataStore removeAll];
    
    self.mockChannelTagGroupsAPIClient = [self mockForClass:[UATagGroupsAPIClient class]];
    self.mockNamedUserTagGroupsAPIClient = [self mockForClass:[UATagGroupsAPIClient class]];

    self.mockTagGroupClass = [self mockForClass:[UATagGroupsMutation class]];

    self.mockOperationQueue = [self partialMockForObject:[[NSOperationQueue alloc] init]];

    self.channelRegistrar =  [UATagGroupsRegistrar channelTagGroupsRegistrarWithDataStore:self.dataStore apiClient:self.mockChannelTagGroupsAPIClient operationQueue:self.mockOperationQueue];
    self.namedUserRegistrar =  [UATagGroupsRegistrar namedUserTagGroupsRegistrarWithDataStore:self.dataStore apiClient:self.mockNamedUserTagGroupsAPIClient operationQueue:self.mockOperationQueue];
}

- (void)tearDown {
    [super tearDown];
    [self.dataStore removeAll];
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
    [[[self.mockChannelTagGroupsAPIClient expect] andDo:^(NSInvocation *invocation) {
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
    [[[self.mockChannelTagGroupsAPIClient expect] andDo:^(NSInvocation *invocation) {
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
    [[self.mockNamedUserTagGroupsAPIClient reject] updateTagGroupsForId:OCMOCK_ANY tagGroupsMutation:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    [self.channelRegistrar addTags:@[@"tag1"] group:@"group1"];
    [self.channelRegistrar removeTags:@[@"tag2"] group:@"group1"];
    [self.channelRegistrar setTags:@[@"tag1"] group:@"group2"];
    
    [self.channelRegistrar updateTagGroupsForID:testID];
    
    // wait until the queue clears
    XCTestExpectation *endBackgroundTaskExpecation = [self expectationWithDescription:@"End of background task"];
    [[[[self.mockApplication expect] ignoringNonObjectArgs] andDo:^(NSInvocation *invocation) {
        [endBackgroundTaskExpecation fulfill];
    }] endBackgroundTask:0];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [self.mockChannelTagGroupsAPIClient verify];
    [self.mockNamedUserTagGroupsAPIClient verify];
}

- (void)testUpdateTagGroupsWithInvalidBackground {
    // SETUP
    [self.channelRegistrar addTags:@[@"tag1"] group:@"group1"];
    
    // Prevent beginRegistrationBackgroundTask early return
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIBackgroundTaskInvalid)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];
    
    // EXPECTATIONS
    [[self.mockChannelTagGroupsAPIClient reject] updateTagGroupsForId:OCMOCK_ANY tagGroupsMutation:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockNamedUserTagGroupsAPIClient reject] updateTagGroupsForId:OCMOCK_ANY tagGroupsMutation:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // TEST
    [self.channelRegistrar updateTagGroupsForID:@"someID"];
    
    // VERIFY
    [self.mockChannelTagGroupsAPIClient verify];
    [self.mockNamedUserTagGroupsAPIClient verify];
}

- (void)testSetEmptyTagListClearsTags {
    // SETUP
    NSArray *emptyArray = @[];
    NSString *group = @"group1";
    
    // EXPECTATIONS
    [[[self.mockTagGroupClass expect] andReturn:[[UATagGroupsMutation alloc] init]] mutationToSetTags:[OCMArg isEqual:emptyArray] group:[OCMArg isEqual:group]];
    XCTestExpectation *expectation = [self expectationWithDescription:@"addTagGroupsMutation call"];
    [[[self.mockDataStore expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] addTagGroupsMutation:OCMOCK_ANY forKey:@"UAPushTagGroupsMutations"];
    
    // TEST
    [self.channelRegistrar setTags:emptyArray group:group];

    // VERIFY
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    [self.mockTagGroupClass verify];
    [self.mockDataStore verify];
}

- (void)testSetWithEmptyGroupDoesntSetTags {
    // SETUP
    
    // EXPECTATIONS
    [[self.mockTagGroupClass reject] mutationToSetTags:OCMOCK_ANY group:OCMOCK_ANY];
    [[self.mockDataStore reject] addTagGroupsMutation:OCMOCK_ANY forKey:OCMOCK_ANY];
    [[self.mockOperationQueue reject] addOperation:OCMOCK_ANY];
    
    // TEST
    [self.channelRegistrar setTags:@[@"tag1"] group:@""];
    
    // VERIFY
    [self.mockTagGroupClass verify];
    [self.mockDataStore verify];
}

- (void)testAddEmptyTagListOrEmptyGroupDoesntAddTags {
    // SETUP
    
    // EXPECTATIONS
    [[self.mockTagGroupClass reject] mutationToSetTags:OCMOCK_ANY group:OCMOCK_ANY];
    [[self.mockDataStore reject] addTagGroupsMutation:OCMOCK_ANY forKey:OCMOCK_ANY];
    [[self.mockOperationQueue reject] addOperation:OCMOCK_ANY];

    // TEST
    [self.channelRegistrar addTags:@[] group:@"group1"];
    [self.channelRegistrar addTags:@[@"tag1"] group:@""];
    
    // VERIFY
    [self.mockTagGroupClass verify];
    [self.mockDataStore verify];
}

- (void)testRemoveEmptyTagListOrEmptyGroupDoesntRemoveTags {
    // SETUP
    XCTestExpectation *expectation = [self expectationWithDescription:@"Async addTagGroupsMutation call"];
    [[[self.mockDataStore expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] addTagGroupsMutation:OCMOCK_ANY forKey:@"UAPushTagGroupsMutations"];

    [self.channelRegistrar addTags:@[@"tag1"] group:@"device"];
    
    // wait until tags have been added
    [self waitForExpectationsWithTimeout:1 handler:nil];

    // EXPECTATIONS
    [[self.mockTagGroupClass reject] mutationToSetTags:OCMOCK_ANY group:OCMOCK_ANY];
    [[self.mockDataStore reject] addTagGroupsMutation:OCMOCK_ANY forKey:OCMOCK_ANY];
    [[self.mockOperationQueue reject] addOperation:OCMOCK_ANY];

    // TEST
    [self.channelRegistrar removeTags:@[] group:@"group1"];
    [self.channelRegistrar removeTags:@[@"tag1"] group:@""];
    
    // VERIFY
    [self.mockTagGroupClass verify];
    [self.mockDataStore verify];
}

- (void)testChannelAndNamedUserTagsAreIndependent {
    // SETUP
    NSMutableArray<NSString *> *keys = [NSMutableArray arrayWithCapacity:2];
    
    // EXPECTATIONS
    XCTestExpectation *expectation = [self expectationWithDescription:@"addTagGroupsMutation call"];
    [[[self.mockDataStore stub] andDo:^(NSInvocation *invocation) {
        if (keys.count == 2) {
            [expectation fulfill];
        }
    }] addTagGroupsMutation:OCMOCK_ANY forKey:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *key = (NSString *)obj;
        [keys addObject:key];
        return YES;
    }]];

    // TEST
    [self.channelRegistrar addTags:@[@"tag1"] group:@"someDevice"];
    [self.namedUserRegistrar addTags:@[@"tag2"] group:@"someUser"];

    // WAIT
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // VERIFY
    XCTAssertNotEqual(keys[0],keys[1]);

    [self.mockDataStore verify];
}

- (void)testClearAllPendingUpdatesCancelsAndClearsMutations {
    // EXPECTATIONS
    [[self.mockOperationQueue expect] cancelAllOperations];
    XCTestExpectation *expectation = [self expectationWithDescription:@"remove object for key"];
    [[[self.mockDataStore expect] andDo:^(NSInvocation *invocation) {
        [expectation fulfill];
    }] removeObjectForKey:@"UANamedUserTagGroupsMutations"];

    // TEST
    [self.namedUserRegistrar clearAllPendingTagUpdates];
    
    // WAIT
    [self waitForExpectationsWithTimeout:1 handler:nil];

    // VERIFY
    [self.mockOperationQueue verify];
    [self.mockDataStore verify];
}

@end
