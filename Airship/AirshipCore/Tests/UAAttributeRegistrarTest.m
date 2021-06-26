/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAAttributeRegistrar+Internal.h"
#import "UAUtils+Internal.h"
#import "UAAttributePendingMutations.h"
#import "UAPersistentQueue+Internal.h"
#import "UAAttributeMutations.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;


@interface UAAttributeRegistrarTest : UAAirshipBaseTest
@property (nonatomic, strong) UAAttributeRegistrar *registrar;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockApiClient;
@property (nonatomic, strong) UAPersistentQueue *persistentQueue;
@property (nonatomic, strong) UATestDate *testDate;
@end

@implementation UAAttributeRegistrarTest

- (void)setUp {
    self.testDate = [[UATestDate alloc] initWithOffset:0 dateOverride:[NSDate date]];
    self.mockApplication = [self mockForClass:[UIApplication class]];
    self.mockApiClient = [self mockForClass:[UAAttributeAPIClient class]];

    self.persistentQueue = [UAPersistentQueue persistentQueueWithDataStore:self.dataStore key:@"UAAttributeRegistrarTest"];

    self.registrar = [UAAttributeRegistrar registrarWithAPIClient:self.mockApiClient
                                                  persistentQueue:self.persistentQueue
                                                      application:self.mockApplication];

    [self.registrar setIdentifier:@"some id" clearPendingOnChange:NO];
}

- (void)testUpdateAttributes {
    UAAttributeMutations *breakfastDrink = [UAAttributeMutations mutations];
    [breakfastDrink setString:@"coffee" forAttribute:@"breakfastDrink"];
    UAAttributePendingMutations *breakfastMutations = [UAAttributePendingMutations pendingMutationsWithMutations:breakfastDrink
                                                                                                            date:self.testDate];

    UAAttributeMutations *lunchDrink = [UAAttributeMutations mutations];
    [lunchDrink setString:@"Code Red" forAttribute:@"lunchDrink"];
    UAAttributePendingMutations *lunchDrinkMutations = [UAAttributePendingMutations pendingMutationsWithMutations:lunchDrink
                                                                                                             date:self.testDate];

    [self.registrar savePendingMutations:breakfastMutations];
    [self.registrar savePendingMutations:lunchDrinkMutations];

    UAAttributePendingMutations *expectedMutations = [UAAttributePendingMutations collapseMutations:@[breakfastMutations, lunchDrinkMutations]];

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:200];

    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse *, NSError *) = (__bridge void (^)(UAHTTPResponse *, NSError *))arg;
        completionHandler(response, nil);
    }] updateWithIdentifier:self.registrar.identifier mutations:expectedMutations completionHandler:OCMOCK_ANY];

    XCTestExpectation *updateCompleted = [self expectationWithDescription:@"updateCompleted"];
    [self.registrar updateAttributesWithCompletionHandler:^(UAAttributeUploadResult result) {
        XCTAssertEqual(UAAttributeUploadResultFinished, result);
        [updateCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockApiClient verify];
    XCTAssertNil([self.persistentQueue peekObject]);
}

- (void)testUpdateTagGroupsClientError {
    UAAttributeMutations *attributes = [UAAttributeMutations mutations];
    [attributes setString:@"Code Red" forAttribute:@"drink"];
    UAAttributePendingMutations *pending = [UAAttributePendingMutations pendingMutationsWithMutations:attributes
                                                                                                 date:self.testDate];
    [self.registrar savePendingMutations:pending];

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:400];

    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse *, NSError *) = (__bridge void (^)(UAHTTPResponse *, NSError *))arg;
        completionHandler(response, nil);
    }] updateWithIdentifier:self.registrar.identifier mutations:pending completionHandler:OCMOCK_ANY];

    XCTestExpectation *updateCompleted = [self expectationWithDescription:@"updateCompleted"];
    [self.registrar updateAttributesWithCompletionHandler:^(UAAttributeUploadResult result) {
        XCTAssertEqual(UAAttributeUploadResultFinished, result);
        [updateCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockApiClient verify];

    XCTAssertNil([self.persistentQueue peekObject]);
}

- (void)testUpdateTagGroupsServerError {
    UAAttributeMutations *attributes = [UAAttributeMutations mutations];
    [attributes setString:@"Code Red" forAttribute:@"drink"];
    UAAttributePendingMutations *pending = [UAAttributePendingMutations pendingMutationsWithMutations:attributes
                                                                                                 date:self.testDate];
    [self.registrar savePendingMutations:pending];

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:500];

    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse *, NSError *) = (__bridge void (^)(UAHTTPResponse *, NSError *))arg;
        completionHandler(response, nil);
    }] updateWithIdentifier:self.registrar.identifier mutations:pending completionHandler:OCMOCK_ANY];

    XCTestExpectation *updateCompleted = [self expectationWithDescription:@"updateCompleted"];
    [self.registrar updateAttributesWithCompletionHandler:^(UAAttributeUploadResult result) {
        XCTAssertEqual(UAAttributeUploadResultFailed, result);
        [updateCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockApiClient verify];

    XCTAssertEqualObjects(self.persistentQueue.peekObject, pending);
}

- (void)testUpdateTagGroupsError {
    UAAttributeMutations *attributes = [UAAttributeMutations mutations];
    [attributes setString:@"Code Red" forAttribute:@"drink"];
    UAAttributePendingMutations *pending = [UAAttributePendingMutations pendingMutationsWithMutations:attributes
                                                                                                 date:self.testDate];
    [self.registrar savePendingMutations:pending];

    NSError *error = [NSError errorWithDomain:@"test" code:20000 userInfo:nil];

    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse *, NSError *) = (__bridge void (^)(UAHTTPResponse *, NSError *))arg;
        completionHandler(nil, error);
    }] updateWithIdentifier:self.registrar.identifier mutations:pending completionHandler:OCMOCK_ANY];

    XCTestExpectation *updateCompleted = [self expectationWithDescription:@"updateCompleted"];
    [self.registrar updateAttributesWithCompletionHandler:^(UAAttributeUploadResult result) {
        XCTAssertEqual(UAAttributeUploadResultFailed, result);
        [updateCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockApiClient verify];

    XCTAssertEqualObjects(self.persistentQueue.peekObject, pending);
}

- (void)testUpdateTagGroupsNoPendingMutations{
    XCTestExpectation *updateCompleted = [self expectationWithDescription:@"updateCompleted"];
    [self.registrar updateAttributesWithCompletionHandler:^(UAAttributeUploadResult result) {
        XCTAssertEqual(UAAttributeUploadResultUpToDate, result);
        [updateCompleted fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testClearAllPendingUpdatesCancelsAndClearsMutations {
    UAAttributeMutations *mutations = [UAAttributeMutations mutations];
    [mutations setString:@"coffee" forAttribute:@"cup"];
    UAAttributePendingMutations *pending = [UAAttributePendingMutations pendingMutationsWithMutations:mutations date:self.testDate];
    [self.registrar savePendingMutations:pending];
    XCTAssertEqualObjects(pending, [self.persistentQueue peekObject]);

    [self.registrar clearPendingMutations];
    XCTAssertNil([self.persistentQueue peekObject]);
}

- (void)testSetIdentifier {
    UAAttributeMutations *mutations = [UAAttributeMutations mutations];
    [mutations setString:@"coffee" forAttribute:@"cup"];
    UAAttributePendingMutations *pending = [UAAttributePendingMutations pendingMutationsWithMutations:mutations date:self.testDate];
    [self.registrar savePendingMutations:pending];
    XCTAssertEqualObjects(pending, [self.persistentQueue peekObject]);

    [self.registrar setIdentifier:@"cool" clearPendingOnChange:NO];
    XCTAssertEqualObjects(pending, [self.persistentQueue peekObject]);
}

- (void)testSetIdentifierClearPending {
    UAAttributeMutations *mutations = [UAAttributeMutations mutations];
    [mutations setString:@"coffee" forAttribute:@"cup"];
    UAAttributePendingMutations *pending = [UAAttributePendingMutations pendingMutationsWithMutations:mutations date:self.testDate];
    [self.registrar savePendingMutations:pending];
    XCTAssertEqualObjects(pending, [self.persistentQueue peekObject]);

    [self.registrar setIdentifier:@"cool" clearPendingOnChange:YES];
    XCTAssertNil([self.persistentQueue peekObject]);
}

- (void)testPendingAttributes {
    UAAttributeMutations *breakfastDrink = [UAAttributeMutations mutations];
    [breakfastDrink setString:@"coffee" forAttribute:@"breakfastDrink"];
    UAAttributePendingMutations *breakfastMutations = [UAAttributePendingMutations pendingMutationsWithMutations:breakfastDrink
                                                                                                            date:self.testDate];

    UAAttributeMutations *lunchDrink = [UAAttributeMutations mutations];
    [lunchDrink setString:@"Code Red" forAttribute:@"lunchDrink"];
    UAAttributePendingMutations *lunchDrinkMutations = [UAAttributePendingMutations pendingMutationsWithMutations:lunchDrink
                                                                                                             date:self.testDate];
    [self.registrar savePendingMutations:breakfastMutations];
    [self.registrar savePendingMutations:lunchDrinkMutations];

    UAAttributePendingMutations *expected = [UAAttributePendingMutations collapseMutations:@[breakfastMutations, lunchDrinkMutations]];
    XCTAssertEqualObjects(expected, self.registrar.pendingMutations);
}

@end
