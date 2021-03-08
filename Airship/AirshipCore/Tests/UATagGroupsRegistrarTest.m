/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UATaskManager.h"

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
}

- (void)testUpdateTagGroups {
    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:200];

    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse *, NSError *) = (__bridge void (^)(UAHTTPResponse *, NSError *))arg;
        completionHandler(response, nil);
    }] updateTagGroupsForId:@"someID" tagGroupsMutation:[OCMArg checkWithBlock:^BOOL(id obj) {
        UATagGroupsMutation *mutation = (UATagGroupsMutation *)obj;
        NSDictionary *expectedPayload = @{@"set": @{ @"group2": @[@"tag1"] } };
        return [expectedPayload isEqualToDictionary:[mutation payload]];
    }] completionHandler:OCMOCK_ANY];

    [self.registrar addTags:@[@"tag1"] group:@"group1"];
    [self.registrar removeTags:@[@"tag2"] group:@"group1"];
    [self.registrar setTags:@[@"tag1"] group:@"group2"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback finished"];
    [self.registrar updateTagGroupsWithCompletionHandler:^(BOOL completed) {
        XCTAssertTrue(completed);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockApiClient verify];
}

- (void)testUpdateTagGroupsClientError {
    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:400];
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse *, NSError *) = (__bridge void (^)(UAHTTPResponse *, NSError *))arg;
        completionHandler(response, nil);
    }] updateTagGroupsForId:@"someID" tagGroupsMutation:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.registrar setTags:@[@"tag1"] group:@"group2"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback finished"];
    [self.registrar updateTagGroupsWithCompletionHandler:^(BOOL completed) {
        XCTAssertTrue(completed);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockApiClient verify];

    XCTAssertNil([self.pendingTagGroupStore peekPendingMutation]);
}

- (void)testUpdateTagGroupsServerError {
    NSDictionary *expectedPayload = @{@"set": @{ @"group2": @[@"tag1"] } };

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:500];
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(UAHTTPResponse *, NSError *) = (__bridge void (^)(UAHTTPResponse *, NSError *))arg;
        completionHandler(response, nil);
    }] updateTagGroupsForId:@"someID" tagGroupsMutation:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.registrar setTags:@[@"tag1"] group:@"group2"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback finished"];
    [self.registrar updateTagGroupsWithCompletionHandler:^(BOOL completed) {
        XCTAssertFalse(completed);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockApiClient verify];

    XCTAssertEqualObjects(expectedPayload, [self.pendingTagGroupStore peekPendingMutation].payload);
}

- (void)testUpdateTagGroups429 {
    NSDictionary *expectedPayload = @{@"set": @{ @"group2": @[@"tag1"] } };

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:429];
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(UAHTTPResponse *, NSError *) = (__bridge void (^)(UAHTTPResponse *, NSError *))arg;
        completionHandler(response, nil);
    }] updateTagGroupsForId:@"someID" tagGroupsMutation:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.registrar setTags:@[@"tag1"] group:@"group2"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback finished"];
    [self.registrar updateTagGroupsWithCompletionHandler:^(BOOL completed) {
        XCTAssertFalse(completed);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockApiClient verify];

    XCTAssertEqualObjects(expectedPayload, [self.pendingTagGroupStore peekPendingMutation].payload);
}

- (void)testUpdateTagGroupsError {
    NSDictionary *expectedPayload = @{@"set": @{ @"group2": @[@"tag1"] } };

    NSError *error = [[NSError alloc] initWithDomain:@"domain" code:1 userInfo:nil];

    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];

        void (^completionHandler)(UAHTTPResponse *, NSError *) = (__bridge void (^)(UAHTTPResponse *, NSError *))arg;
        completionHandler(nil, error);
    }] updateTagGroupsForId:@"someID" tagGroupsMutation:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.registrar setTags:@[@"tag1"] group:@"group2"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Callback finished"];
    [self.registrar updateTagGroupsWithCompletionHandler:^(BOOL completed) {
        XCTAssertFalse(completed);
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockApiClient verify];

    XCTAssertEqualObjects(expectedPayload, [self.pendingTagGroupStore peekPendingMutation].payload);
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
