/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UATagGroupsLookupManager+Internal.h"
#import "UAirship.h"
#import "UAChannel.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UATagGroupsMutationHistory+Internal.h"
#import "UATestDate.h"

@interface UATagGroupsLookupManagerTest : UAAirshipBaseTest
@property (nonatomic, strong) UATagGroupsLookupManager *lookupManager;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockAPIClient;
@property (nonatomic, strong) id mockCache;
@property (nonatomic, strong) id mockTagGroupsHistory;
@property (nonatomic, strong) UATagGroups *requestedTagGroups;
@property (nonatomic, strong) UATestDate *testDate;
@property (nonatomic, strong) id mockDelegate;
@end

@implementation UATagGroupsLookupManagerTest

- (void)setUp {
    [super setUp];
    self.requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar", @"baz"]}];
    self.testDate = [[UATestDate alloc] init];

    self.mockDelegate = [self mockForProtocol:@protocol(UATagGroupsLookupManagerDelegate)];
    [[[self.mockDelegate stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UATagGroups *) = (__bridge void(^)(UATagGroups *))arg;
        completionHandler(self.requestedTagGroups);
    }] gatherTagGroupsWithCompletionHandler:OCMOCK_ANY];

    [self setupMocks:@"channel" channelTagsEnabled:NO];

    self.lookupManager.enabled = YES;
    self.lookupManager.delegate = self.mockDelegate;
}

- (void)setupMocks:(NSString *)channelID channelTagsEnabled:(BOOL)enabled {
    self.mockAirship = [self mockForClass:[UAirship class]];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockAPIClient = [self mockForClass:[UATagGroupsLookupAPIClient class]];
    self.mockTagGroupsHistory = [self mockForProtocol:@protocol(UATagGroupsHistory)];
    self.mockCache = [self mockForClass:[UATagGroupsLookupResponseCache class]];

    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];

    [[[self.mockChannel stub] andReturn:@[@"test"]] tags];
    [[[self.mockChannel stub] andReturn:channelID] identifier];
    [[[self.mockChannel stub] andReturnValue:@(enabled)] isChannelTagRegistrationEnabled];

    self.lookupManager = [UATagGroupsLookupManager lookupManagerWithAPIClient:self.mockAPIClient
                                                                    dataStore:self.dataStore
                                                                        cache:self.mockCache
                                                             tagGroupsHistory:self.mockTagGroupsHistory
                                                                  currentTime:self.testDate];
}

- (void)testGetTagsComponentDisabled {
    self.lookupManager.enabled = NO;

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertNil(tagGroups);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, UATagGroupsLookupManagerErrorCodeComponentDisabled);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetTagsNoChannel {
    [self setupMocks:nil channelTagsEnabled:NO];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertNil(tagGroups);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, UATagGroupsLookupManagerErrorCodeChannelRequired);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetOnlyDeviceTags {
    [self setupMocks:@"channel" channelTagsEnabled:YES];

    self.requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"device" : @[@"override"]}];

    [[self.mockAPIClient reject] lookupTagGroupsWithChannelID:OCMOCK_ANY requestedTagGroups:OCMOCK_ANY cachedResponse:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertEqualObjects(tagGroups, [UATagGroups tagGroupsWithTags:@{@"device" : @[@"test"]}]);
        XCTAssertNil(error);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];

    [self.mockAPIClient verify];
}

- (void)testGetTagsCachedResponse {

    UATagGroups *responseTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar"]}];

    UATagGroupsLookupResponse *response = [UATagGroupsLookupResponse responseWithTagGroups:responseTagGroups
                                                                                    status:200
                                                                     lastModifiedTimestamp:@"2018-03-02T22:56:09"];

    UATagGroups *tagGroupsWithLocalMutations = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar", @"baz"], @"bleep" : @[@"bloop"]}];

    NSDate *cacheRefreshDate = [NSDate dateWithTimeIntervalSinceNow:-60];

    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturn:self.requestedTagGroups] requestedTagGroups];
    [[[self.mockCache expect] andReturn:cacheRefreshDate] refreshDate];
    [[[self.mockCache expect] andReturnValue:@(NO)] needsRefresh];


    self.testDate.absoluteTime = [NSDate date];
    NSTimeInterval expectedMaxAge = [[self.testDate now] timeIntervalSinceDate:cacheRefreshDate] + self.lookupManager.preferLocalTagDataTime;

    [[[self.mockTagGroupsHistory expect] andReturn:tagGroupsWithLocalMutations] applyHistory:response.tagGroups maxAge:expectedMaxAge];

    [[self.mockAPIClient reject] lookupTagGroupsWithChannelID:OCMOCK_ANY requestedTagGroups:OCMOCK_ANY cachedResponse:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertEqualObjects(tagGroups, expectedTagGroups);
        XCTAssertNil(error);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCache verify];
    [self.mockTagGroupsHistory verify];
    [self.mockAPIClient verify];
}

- (void)testGetTagsEmptyCache {

    [[[self.mockCache expect] andReturn:nil] response];
    [[[self.mockCache expect] andReturn:nil] refreshDate];

    UATagGroups *responseTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar"]}];

    UATagGroupsLookupResponse *response = [UATagGroupsLookupResponse responseWithTagGroups:responseTagGroups
                                                                                    status:200
                                                                     lastModifiedTimestamp:@"2018-03-02T22:56:09"];

    UATagGroups *tagGroupsWithLocalMutations = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar", @"baz"], @"bleep" : @[@"bloop"]}];

    XCTestExpectation *apiFetchCompleted = [self expectationWithDescription:@"API fetch completed"];

    [[self.mockCache expect] setResponse:response];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^completionHandler)(UATagGroupsLookupResponse *) = (__bridge void(^)(UATagGroupsLookupResponse *))arg;
        completionHandler(response);
        [apiFetchCompleted fulfill];
    }] lookupTagGroupsWithChannelID:OCMOCK_ANY requestedTagGroups:OCMOCK_ANY cachedResponse:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSDate *cacheRefreshDate = [NSDate date];

    [[[self.mockCache expect] andReturn:cacheRefreshDate] refreshDate];
    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturnValue:@(NO)] isStale];

    self.testDate.absoluteTime = [NSDate date];
    NSTimeInterval expectedMaxAge = [[self.testDate now] timeIntervalSinceDate:cacheRefreshDate] + self.lookupManager.preferLocalTagDataTime;
    [[[self.mockTagGroupsHistory expect] andReturn:tagGroupsWithLocalMutations] applyHistory:response.tagGroups maxAge:expectedMaxAge];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertEqualObjects(tagGroups, expectedTagGroups);
        XCTAssertNil(error);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCache verify];
    [self.mockTagGroupsHistory verify];
    [self.mockAPIClient verify];
}

- (void)testGetTagsCacheNeedsRefresh {

    UATagGroups *responseTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar"]}];

    UATagGroupsLookupResponse *response = [UATagGroupsLookupResponse responseWithTagGroups:responseTagGroups
                                                                                    status:200
                                                                     lastModifiedTimestamp:@"2018-03-02T22:56:09"];

    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturn:self.requestedTagGroups] requestedTagGroups];
    [[[self.mockCache expect] andReturn:[NSDate distantPast]] refreshDate];
    [[[self.mockCache expect] andReturnValue:@(YES)] needsRefresh];

    XCTestExpectation *apiFetchCompleted = [self expectationWithDescription:@"API fetch completed"];

    [[self.mockCache expect] setResponse:response];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^completionHandler)(UATagGroupsLookupResponse *) = (__bridge void(^)(UATagGroupsLookupResponse *))arg;
        [[[self.mockCache expect] andReturn:response] response];
        completionHandler(response);
        [apiFetchCompleted fulfill];
    }] lookupTagGroupsWithChannelID:OCMOCK_ANY requestedTagGroups:OCMOCK_ANY cachedResponse:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    NSDate *cacheRefreshDate = [NSDate date];

    [[[self.mockCache expect] andReturn:cacheRefreshDate] refreshDate];
    [[[self.mockCache expect] andReturnValue:@(NO)] isStale];

    self.testDate.absoluteTime = [NSDate date];
    NSTimeInterval expectedMaxAge = [[self.testDate now] timeIntervalSinceDate:cacheRefreshDate] + self.lookupManager.preferLocalTagDataTime;
    UATagGroups *tagGroupsWithLocalMutations = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar", @"baz"], @"bleep" : @[@"bloop"]}];
    [[[self.mockTagGroupsHistory expect] andReturn:tagGroupsWithLocalMutations] applyHistory:response.tagGroups maxAge:expectedMaxAge];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertEqualObjects(tagGroups, expectedTagGroups);
        XCTAssertNil(error);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCache verify];
    [self.mockTagGroupsHistory verify];
    [self.mockAPIClient verify];
}

- (void)testGetTagsCacheErrorMissingResponse {
    UATagGroups *responseTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar"]}];

    UATagGroupsLookupResponse *response = [UATagGroupsLookupResponse responseWithTagGroups:responseTagGroups
                                                                                    status:200
                                                                     lastModifiedTimestamp:@"2018-03-02T22:56:09"];

    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturn:self.requestedTagGroups] requestedTagGroups];
    [[[self.mockCache expect] andReturn:[NSDate distantPast]] refreshDate];
    [[[self.mockCache expect] andReturnValue:@(YES)] needsRefresh];

    XCTestExpectation *apiFetchCompleted = [self expectationWithDescription:@"API fetch completed"];

    [[self.mockCache expect] setResponse:response];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^completionHandler)(UATagGroupsLookupResponse *) = (__bridge void(^)(UATagGroupsLookupResponse *))arg;
        [[[self.mockCache expect] andReturn:nil] response];
        completionHandler(response);
        [apiFetchCompleted fulfill];
    }] lookupTagGroupsWithChannelID:OCMOCK_ANY requestedTagGroups:OCMOCK_ANY cachedResponse:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertNil(tagGroups);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, UATagGroupsLookupManagerErrorCodeCacheRefresh);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCache verify];
    [self.mockAPIClient verify];
}

- (void)testGetTagsCacheErrorStaleRead {
    UATagGroups *responseTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar"]}];

    UATagGroupsLookupResponse *response = [UATagGroupsLookupResponse responseWithTagGroups:responseTagGroups
                                                                                    status:200
                                                                     lastModifiedTimestamp:@"2018-03-02T22:56:09"];

    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturn:self.requestedTagGroups] requestedTagGroups];
    [[[self.mockCache expect] andReturn:[NSDate distantPast]] refreshDate];
    [[[self.mockCache expect] andReturnValue:@(YES)] needsRefresh];

    XCTestExpectation *apiFetchCompleted = [self expectationWithDescription:@"API fetch completed"];

    [[self.mockCache expect] setResponse:response];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^completionHandler)(UATagGroupsLookupResponse *) = (__bridge void(^)(UATagGroupsLookupResponse *))arg;
        [[[self.mockCache expect] andReturn:response] response];
        completionHandler(response);
        [apiFetchCompleted fulfill];
    }] lookupTagGroupsWithChannelID:OCMOCK_ANY requestedTagGroups:OCMOCK_ANY cachedResponse:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockCache expect] andReturn:[NSDate dateWithTimeIntervalSinceNow:(-90 * 60)]] refreshDate];
    [[[self.mockCache expect] andReturnValue:@(YES)] isStale];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertNil(tagGroups);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, UATagGroupsLookupManagerErrorCodeCacheRefresh);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCache verify];
    [self.mockAPIClient verify];
}

- (void)testTagGroupsDelegate {
    UATagGroups *requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"hi"]}];

    UATagGroups *expectedMergedGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"hi", @"bar", @"baz"]}];

    UATagGroupsLookupResponse *response = [UATagGroupsLookupResponse responseWithTagGroups:requestedTagGroups
                                                                                    status:200
                                                                     lastModifiedTimestamp:@"2018-03-02T22:56:09"];
    XCTestExpectation *mergedTagsCached = [self expectationWithDescription:@"merged tags cached"];

    [[self.mockCache expect] setResponse:response];

    // Expect properly merged tag groups to be set as requestedTagGroups in cache
    [[[self.mockCache expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UATagGroups *mergedGroups = (__bridge UATagGroups *)arg;

        XCTAssertEqualObjects(mergedGroups, expectedMergedGroups);
        [mergedTagsCached fulfill];
    }] setRequestedTagGroups:OCMOCK_ANY];

    XCTestExpectation *apiFetchCompleted = [self expectationWithDescription:@"API fetch completed"];

    [[[self.mockAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^completionHandler)(UATagGroupsLookupResponse *) = (__bridge void(^)(UATagGroupsLookupResponse *))arg;
        [[[self.mockCache expect] andReturn:response] response];
        completionHandler(response);
        [apiFetchCompleted fulfill];
    }] lookupTagGroupsWithChannelID:OCMOCK_ANY requestedTagGroups:OCMOCK_ANY cachedResponse:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCache verify];
    [self.mockAPIClient verify];
}

@end

