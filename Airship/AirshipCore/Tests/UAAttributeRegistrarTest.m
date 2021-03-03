/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAAttributeRegistrar+Internal.h"
#import "UAAttributeAPIClient+Internal.h"
#import "UAUtils+Internal.h"
#import "UATestDate.h"
#import "UAAttributePendingMutations.h"
#import "UAPersistentQueue+Internal.h"
#import "UAAttributeMutations.h"
#import "UATaskManager.h"

static NSString * const UAAttributesUpdateTaskID = @"UAAttributes.update";

@interface UAAttributeRegistrarTest : UAAirshipBaseTest
@property (nonatomic, strong) UAAttributeRegistrar *registrar;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockApiClient;
@property (nonatomic, strong) UAPersistentQueue *persistentQueue;
@property (nonatomic, strong) UATestDate *testDate;
@property (nonatomic, strong) id mockTaskManager;
@property (nonatomic, strong) id mockTask;
@end

@implementation UAAttributeRegistrarTest

- (void)setUp {
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];
    self.mockApplication = [self mockForClass:[UIApplication class]];
    self.mockApiClient = [self mockForClass:[UAAttributeAPIClient class]];

    self.persistentQueue = [UAPersistentQueue persistentQueueWithDataStore:self.dataStore key:@"UAAttributeRegistrarTest"];

    self.registrar = [UAAttributeRegistrar registrarWithAPIClient:self.mockApiClient
                                                  persistentQueue:self.persistentQueue
                                                      application:self.mockApplication];

    [self.registrar setIdentifier:@"some id" clearPendingOnChange:NO];
    
    self.mockTask = [self mockForProtocol:@protocol(UATask)];
    
    self.mockTaskManager = [self mockForClass:[UATaskManager class]];
}

- (void)testUpdateAttributes {
    // Background task
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

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

    XCTestExpectation *apiClientResponse = [self expectationWithDescription:@"client finished"];
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(NSError *) = (__bridge void (^)(NSError *))arg;
        completionHandler(nil);
        [apiClientResponse fulfill];
    }] updateWithIdentifier:self.registrar.identifier attributeMutations:expectedMutations completionHandler:OCMOCK_ANY];

    [self updateAttributes];

    [self waitForTestExpectations];
    [self.mockApiClient verify];
    XCTAssertNil([self.persistentQueue peekObject]);
}

- (void)testUpdateAttributesContinuesUploadsAfterSuccess {
    UAAttributeMutations *breakfastDrink = [UAAttributeMutations mutations];
    [breakfastDrink setString:@"coffee" forAttribute:@"breakfastDrink"];
    UAAttributePendingMutations *breakfastMutations = [UAAttributePendingMutations pendingMutationsWithMutations:breakfastDrink
                                                                                                            date:self.testDate];

    UAAttributeMutations *lunchDrink = [UAAttributeMutations mutations];
    [lunchDrink setString:@"Code Red" forAttribute:@"lunchDrink"];
    UAAttributePendingMutations *lunchDrinkMutations = [UAAttributePendingMutations pendingMutationsWithMutations:lunchDrink
                                                                                                             date:self.testDate];

    UAAttributeMutations *teaTimeDrink = [UAAttributeMutations mutations];
    [teaTimeDrink setString:@"tea" forAttribute:@"teaTimeDrink"];
    UAAttributePendingMutations *teaTimeMutations = [UAAttributePendingMutations pendingMutationsWithMutations:teaTimeDrink
                                                                                                          date:self.testDate];
    // Save initial mutations
    [self.registrar savePendingMutations:breakfastMutations];
    [self.registrar savePendingMutations:lunchDrinkMutations];

    UAAttributePendingMutations *initialMutations = [UAAttributePendingMutations collapseMutations:@[breakfastMutations, lunchDrinkMutations]];

    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(NSError *) = (__bridge void (^)(NSError *))arg;
        // Save new mutations while the client is still working
        [self.registrar savePendingMutations:teaTimeMutations];

        completionHandler(nil);
    }] updateWithIdentifier:self.registrar.identifier attributeMutations:initialMutations completionHandler:OCMOCK_ANY];

    [[self.mockTask expect] taskCompleted];

    [self updateAttributes];

    [self.mockApiClient verify];
    
    [self.mockTask verify];
  
}

- (void)testUpdateAttributesContinuesUploadsAfterUnrecoverableStatus {
    UAAttributeMutations *breakfastDrink = [UAAttributeMutations mutations];
    [breakfastDrink setString:@"coffee" forAttribute:@"breakfastDrink"];
    UAAttributePendingMutations *breakfastMutations = [UAAttributePendingMutations pendingMutationsWithMutations:breakfastDrink
                                                                                                            date:self.testDate];

    UAAttributeMutations *lunchDrink = [UAAttributeMutations mutations];
    [lunchDrink setString:@"Code Red" forAttribute:@"lunchDrink"];
    UAAttributePendingMutations *lunchDrinkMutations = [UAAttributePendingMutations pendingMutationsWithMutations:lunchDrink
                                                                                                             date:self.testDate];

    UAAttributeMutations *teaTimeDrink = [UAAttributeMutations mutations];
    [teaTimeDrink setString:@"tea" forAttribute:@"teaTimeDrink"];
    UAAttributePendingMutations *teaTimeMutations = [UAAttributePendingMutations pendingMutationsWithMutations:teaTimeDrink
                                                                                                          date:self.testDate];
    // Save initial mutations
    [self.registrar savePendingMutations:breakfastMutations];
    [self.registrar savePendingMutations:lunchDrinkMutations];

    UAAttributePendingMutations *initialMutations = [UAAttributePendingMutations collapseMutations:@[breakfastMutations, lunchDrinkMutations]];

    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(NSError *) = (__bridge void (^)(NSError *))arg;

        // Save new mutations while the client is still working
        [self.registrar savePendingMutations:teaTimeMutations];

        completionHandler([NSError errorWithDomain:UAAttributeAPIClientErrorDomain
                                              code:UAAttributeAPIClientErrorUnrecoverableStatus
                                          userInfo:@{}]);
    }] updateWithIdentifier:self.registrar.identifier attributeMutations:initialMutations completionHandler:OCMOCK_ANY];

    [[self.mockTask expect] taskCompleted];

    [self updateAttributes];

    [self.mockApiClient verify];
    [self.mockTask verify];
}

- (void)testUpdateAttributesDoesNotPopOrContinueAfterUnsuccessfulStatus {
    // Background task
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    UAAttributeMutations *breakfastDrink = [UAAttributeMutations mutations];
    [breakfastDrink setString:@"coffee" forAttribute:@"breakfastDrink"];
    UAAttributePendingMutations *breakfastMutations = [UAAttributePendingMutations pendingMutationsWithMutations:breakfastDrink
                                                                                                            date:self.testDate];

    UAAttributeMutations *lunchDrink = [UAAttributeMutations mutations];
    [lunchDrink setString:@"Code Red" forAttribute:@"lunchDrink"];
    UAAttributePendingMutations *lunchDrinkMutations = [UAAttributePendingMutations pendingMutationsWithMutations:lunchDrink
                                                                                                             date:self.testDate];

    UAAttributeMutations *teaTimeDrink = [UAAttributeMutations mutations];
    [teaTimeDrink setString:@"tea" forAttribute:@"teaTimeDrink"];
    UAAttributePendingMutations *teaTimeMutations = [UAAttributePendingMutations pendingMutationsWithMutations:teaTimeDrink
                                                                                                          date:self.testDate];
    // Save initial mutations
    [self.registrar savePendingMutations:breakfastMutations];
    [self.registrar savePendingMutations:lunchDrinkMutations];

    UAAttributePendingMutations *initialMutations = [UAAttributePendingMutations collapseMutations:@[breakfastMutations, lunchDrinkMutations]];

    XCTestExpectation *apiClientResponse = [self expectationWithDescription:@"client finished"];
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(NSError *) = (__bridge void (^)(NSError *))arg;

        // Save new mutations while the client is still working
        [self.registrar savePendingMutations:teaTimeMutations];

        completionHandler([NSError errorWithDomain:UAAttributeAPIClientErrorDomain
                                              code:UAAttributeAPIClientErrorUnsuccessfulStatus
                                          userInfo:@{}]);
        [apiClientResponse fulfill];
    }] updateWithIdentifier:self.registrar.identifier attributeMutations:initialMutations completionHandler:OCMOCK_ANY];

    [[self.mockApiClient reject] updateWithIdentifier:OCMOCK_ANY attributeMutations:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self updateAttributes];

    [self waitForTestExpectations];
    [self.mockApiClient verify];
    XCTAssertEqualObjects(self.persistentQueue.peekObject, initialMutations);
    [self.persistentQueue popObject];
    XCTAssertEqualObjects(self.persistentQueue.peekObject, teaTimeMutations);
}

- (void)testUpdateAttributesDoesNotPopOrContinueAfterError{
    // Background task
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    UAAttributeMutations *breakfastDrink = [UAAttributeMutations mutations];
    [breakfastDrink setString:@"coffee" forAttribute:@"breakfastDrink"];
    UAAttributePendingMutations *breakfastMutations = [UAAttributePendingMutations pendingMutationsWithMutations:breakfastDrink
                                                                                                            date:self.testDate];

    UAAttributeMutations *lunchDrink = [UAAttributeMutations mutations];
    [lunchDrink setString:@"Code Red" forAttribute:@"lunchDrink"];
    UAAttributePendingMutations *lunchDrinkMutations = [UAAttributePendingMutations pendingMutationsWithMutations:lunchDrink
                                                                                                             date:self.testDate];

    UAAttributeMutations *teaTimeDrink = [UAAttributeMutations mutations];
    [teaTimeDrink setString:@"tea" forAttribute:@"teaTimeDrink"];
    UAAttributePendingMutations *teaTimeMutations = [UAAttributePendingMutations pendingMutationsWithMutations:teaTimeDrink
                                                                                                          date:self.testDate];
    // Save initial mutations
    [self.registrar savePendingMutations:breakfastMutations];
    [self.registrar savePendingMutations:lunchDrinkMutations];

    UAAttributePendingMutations *initialMutations = [UAAttributePendingMutations collapseMutations:@[breakfastMutations, lunchDrinkMutations]];

    XCTestExpectation *apiClientResponse = [self expectationWithDescription:@"client finished"];
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(NSError *) = (__bridge void (^)(NSError *))arg;

        // Save new mutations while the client is still working
        [self.registrar savePendingMutations:teaTimeMutations];

        completionHandler([NSError errorWithDomain:@"error" code:0 userInfo:@{}]);
        [apiClientResponse fulfill];
    }] updateWithIdentifier:self.registrar.identifier attributeMutations:initialMutations completionHandler:OCMOCK_ANY];

    [[self.mockApiClient reject] updateWithIdentifier:OCMOCK_ANY attributeMutations:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self updateAttributes];

    [self waitForTestExpectations];
    [self.mockApiClient verify];
    XCTAssertEqualObjects(self.persistentQueue.peekObject, initialMutations);
    [self.persistentQueue popObject];
    XCTAssertEqualObjects(self.persistentQueue.peekObject, teaTimeMutations);
}

- (void)testUpdateAttributesError {
    // Background task
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    UAAttributeMutations *breakfastDrink = [UAAttributeMutations mutations];
    [breakfastDrink setString:@"coffee" forAttribute:@"breakfastDrink"];
    UAAttributePendingMutations *breakfastMutations = [UAAttributePendingMutations pendingMutationsWithMutations:breakfastDrink
                                                                                                            date:self.testDate];
    [self.registrar savePendingMutations:breakfastMutations];

    NSError *error = [NSError errorWithDomain:@"test" code:20000 userInfo:nil];
    XCTestExpectation *apiClientResponse = [self expectationWithDescription:@"client finished"];
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(NSError *) = (__bridge void (^)(NSError *))arg;
        completionHandler(error);
        [apiClientResponse fulfill];
    }] updateWithIdentifier:self.registrar.identifier attributeMutations:breakfastMutations completionHandler:OCMOCK_ANY];

    [self updateAttributes];

    [self waitForTestExpectations];
    [self.mockApiClient verify];
    XCTAssertEqualObjects(breakfastMutations, [self.persistentQueue peekObject]);
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

- (void)testEnabledByDefault {
    XCTAssertTrue(self.registrar.enabled);
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

- (void)updateAttributes {
    __block UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend requiresNetwork:YES extras:nil];

    [[[self.mockTask stub] andReturn:UAAttributesUpdateTaskID] taskID];
    [[[self.mockTask stub] andReturn:options] requestOptions];
    
    [self.registrar updateAttributesWithTask:self.mockTask completionHandler:^(BOOL completed) {}];
}

@end
