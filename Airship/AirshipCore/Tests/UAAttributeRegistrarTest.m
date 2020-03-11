/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UABaseTest.h"
#import "UAAttributeRegistrar+Internal.h"
#import "UAAttributeAPIClient+Internal.h"
#import "UAUtils+Internal.h"
#import "UAChannel.h"
#import "UATestDate.h"
#import "UAAttributePendingMutations+Internal.h"

@interface UAAttributeRegistrarTest : UABaseTest
@property (nonatomic, strong) UAAttributeRegistrar *registrar;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockApiClient;
@property (nonatomic, strong) UATestDate *testDate;
@property(nonatomic, copy) NSString *channelID;
@end

@implementation UAAttributeRegistrarTest

- (void)setUp {
    self.mockApplication = [self mockForClass:[UIApplication class]];

    self.mockApiClient = [self mockForClass:[UAAttributeAPIClient class]];

    self.operationQueue = [[NSOperationQueue alloc] init];

    self.registrar = [UAAttributeRegistrar registrarWithDataStore:self.dataStore
                                                        apiClient:self.mockApiClient
                                                   operationQueue:self.operationQueue
                                                      application:self.mockApplication
                                                             date:self.testDate];

    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];
    
    self.channelID = @"avalidchannel";
}

- (void)tearDown {
    [self.operationQueue cancelAllOperations];
    [self.operationQueue waitUntilAllOperationsAreFinished];
    [super tearDown];
}

/**
 Test mutating attributes calls the attribute API client with a compressed payload and ends its background task correctly.
*/
- (void)testMutationUpdate {
    // Mock background task
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Async call to update attributes"];
    
    NSDateFormatter *isoDateFormatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];
    NSString *timestamp = [isoDateFormatter stringFromDate:self.testDate.now];

    NSDictionary *expectedPayload = @{
        @"attributes" : @[
            @{
                @"action" : @"set",
                @"key" : @"cup",
                @"timestamp" : timestamp,
                @"value" : @"coffee"
            }
        ]
    };

    // Create a success response
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAAttributeAPIClientSuccessBlock onSuccess = (__bridge UAAttributeAPIClientSuccessBlock)arg;
        onSuccess();
        [expectation fulfill];
    }] updateChannel:self.channelID withAttributePayload:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSDictionary *payload = (NSDictionary *)obj;
        return [expectedPayload isEqualToDictionary:payload];
    }] onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    // wait until the queue clears
    XCTestExpectation *endBackgroundTaskExpecation = [self expectationWithDescription:@"End of background task"];
    [[[[self.mockApplication expect] ignoringNonObjectArgs] andDo:^(NSInvocation *invocation) {
        [endBackgroundTaskExpecation fulfill];
    }] endBackgroundTask:0];

    // Test set and replacement
    UAAttributeMutations *beverageMutations = [UAAttributeMutations mutations];
    [beverageMutations setString:@"coffee" forAttribute:@"cup"];

    UAAttributePendingMutations *pendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:beverageMutations date:self.testDate];

    [self.registrar savePendingMutations:pendingMutations];
    [self.registrar updateAttributesForChannel:self.channelID];

    [self waitForTestExpectations];

    [self.mockApiClient verify];
}

/**
 Test mutating attributes call the attribute API client with the correct payload.
*/
- (void)testMultipleMutationUpdate {
    // Mock background task
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE((NSUInteger)30)] beginBackgroundTaskWithExpirationHandler:OCMOCK_ANY];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Async call to update attributes"];

    NSDateFormatter *isoDateFormatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];
    NSString *timestamp = [isoDateFormatter stringFromDate:self.testDate.now];

    NSDictionary *expectedPayload = @{
        @"attributes" : @[
            @{
                @"action" : @"set",
                @"key" : @"cup",
                @"timestamp" : timestamp,
                @"value" : @"coffee"
            },
            @{
                @"action" : @"set",
                @"key" : @"can",
                @"timestamp" : timestamp,
                @"value" : @"tea"
            }
        ]
    };

    // Create a success response
    [[[self.mockApiClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UAAttributeAPIClientSuccessBlock onSuccess = (__bridge UAAttributeAPIClientSuccessBlock)arg;
        onSuccess();
        [expectation fulfill];
    }] updateChannel:self.channelID withAttributePayload:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSDictionary *payload = (NSDictionary *)obj;
        return [expectedPayload isEqualToDictionary:payload];
    }] onSuccess:OCMOCK_ANY onFailure:OCMOCK_ANY];

    // wait until the queue clears
    XCTestExpectation *endBackgroundTaskExpecation = [self expectationWithDescription:@"End of background task"];
    [[[[self.mockApplication expect] ignoringNonObjectArgs] andDo:^(NSInvocation *invocation) {
        [endBackgroundTaskExpecation fulfill];
    }] endBackgroundTask:0];

    // Test set and replacement
    UAAttributeMutations *firstBeverageMutation = [UAAttributeMutations mutations];
    [firstBeverageMutation setString:@"coffee" forAttribute:@"cup"];
    [firstBeverageMutation setString:@"coffee" forAttribute:@"cup"];

    UAAttributeMutations *secondBeverageMutation = [UAAttributeMutations mutations];
    [secondBeverageMutation removeAttribute:@"can"];
    [secondBeverageMutation setString:@"tea" forAttribute:@"can"];
    [secondBeverageMutation setString:@"tea" forAttribute:@"can"];

    UAAttributePendingMutations *firstPendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:firstBeverageMutation date:self.testDate];

    UAAttributePendingMutations *secondPendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:secondBeverageMutation date:self.testDate];

    [self.registrar savePendingMutations:firstPendingMutations];
    [self.registrar savePendingMutations:secondPendingMutations];

    [self.registrar updateAttributesForChannel:self.channelID];

    [self waitForTestExpectations];

    [self.mockApiClient verify];
}

@end
