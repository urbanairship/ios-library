/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UATagGroupsLookupManager+Internal.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UATagGroupsMutationHistory+Internal.h"
#import "UATestDate.h"

@interface UATagGroupsLookupManagerTest : UABaseTest
@property (nonatomic, strong) UATagGroupsLookupManager *lookupManager;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockAPIClient;
@property (nonatomic, strong) id mockCache;
@property (nonatomic, strong) id mockMutationHistory;
@property (nonatomic, strong) UATagGroups *requestedTagGroups;
@property (nonatomic, strong) UATestDate *testDate;
@end

@implementation UATagGroupsLookupManagerTest

- (void)setUp {
    [super setUp];
    self.requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar", @"baz"]}];
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"UATagGroupsLookupManagerTest"];
    self.testDate = [[UATestDate alloc] init];

    [self setupMocks:@"channel" channelTagsEnabled:NO];

    self.lookupManager.componentEnabled = YES;
}

- (void)tearDown {
    [self.dataStore removeAll];
    [super tearDown];
}

- (void)setupMocks:(NSString *)channelID channelTagsEnabled:(BOOL)enabled {
    self.mockAirship = [self mockForClass:[UAirship class]];
    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockAPIClient = [self mockForClass:[UATagGroupsLookupAPIClient class]];
    self.mockMutationHistory = [self mockForClass:[UATagGroupsMutationHistory class]];
    self.mockCache = [self mockForClass:[UATagGroupsLookupResponseCache class]];

    [[[self.mockAirship stub] andReturn:self.mockPush] push];

    [[[self.mockPush stub] andReturn:@[@"test"]] tags];
    [[[self.mockPush stub] andReturn:channelID] channelID];
    [[[self.mockPush stub] andReturnValue:@(enabled)] isChannelTagRegistrationEnabled];

    self.lookupManager = [UATagGroupsLookupManager lookupManagerWithAPIClient:self.mockAPIClient
                                                                     dataStore:self.dataStore
                                                                         cache:self.mockCache
                                                               mutationHistory:self.mockMutationHistory
                                                                   currentTime:self.testDate];
}

- (void)testGetTagsComponentDisabled {
    self.lookupManager.componentEnabled = NO;

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertNil(tagGroups);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, UATagGroupsLookupManagerErrorCodeComponentDisabled);
        [fetchCompleted fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
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

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
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

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    [self.mockAPIClient verify];
}

- (void)testGetTagsCachedResponse {

    UATagGroups *responseTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar"]}];

    UATagGroupsLookupResponse *response = [UATagGroupsLookupResponse responseWithTagGroups:responseTagGroups
                                                                                    status:200
                                                                     lastModifiedTimestamp:@"2018-03-02T22:56:09"];

    UATagGroups *tagGroupsWithLocalMutations = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar", @"baz"], @"bleep" : @[@"bloop"]}];

    NSDate *cacheCreationDate = [NSDate dateWithTimeIntervalSinceNow:-60];

    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturn:self.requestedTagGroups] requestedTagGroups];
    [[[self.mockCache expect] andReturn:cacheCreationDate] creationDate];
    [[[self.mockCache expect] andReturnValue:@(NO)] needsRefresh];

    self.testDate.absoluteTime = [NSDate date];
    NSTimeInterval expectedMaxAge = [[self.testDate now] timeIntervalSinceDate:cacheCreationDate] + self.lookupManager.preferLocalTagDataTime;

    [[[self.mockMutationHistory expect] andReturn:tagGroupsWithLocalMutations] applyHistory:response.tagGroups maxAge:expectedMaxAge];

    [[self.mockAPIClient reject] lookupTagGroupsWithChannelID:OCMOCK_ANY requestedTagGroups:OCMOCK_ANY cachedResponse:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertEqualObjects(tagGroups, expectedTagGroups);
        XCTAssertNil(error);
        [fetchCompleted fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    [self.mockCache verify];
    [self.mockMutationHistory verify];
    [self.mockAPIClient verify];
}

- (void)testGetTagsEmptyCache {

    [[[self.mockCache expect] andReturn:nil] response];
    [[[self.mockCache expect] andReturn:nil] creationDate];

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

    NSDate *cacheCreationDate = [NSDate date];

    [[[self.mockCache expect] andReturn:cacheCreationDate] creationDate];
    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturnValue:@(NO)] isStale];

    self.testDate.absoluteTime = [NSDate date];
    NSTimeInterval expectedMaxAge = [[self.testDate now] timeIntervalSinceDate:cacheCreationDate] + self.lookupManager.preferLocalTagDataTime;
    [[[self.mockMutationHistory expect] andReturn:tagGroupsWithLocalMutations] applyHistory:response.tagGroups maxAge:expectedMaxAge];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertEqualObjects(tagGroups, expectedTagGroups);
        XCTAssertNil(error);
        [fetchCompleted fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    [self.mockCache verify];
    [self.mockMutationHistory verify];
    [self.mockAPIClient verify];
}

- (void)testGetTagsCacheNeedsRefresh {

    UATagGroups *responseTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar"]}];

    UATagGroupsLookupResponse *response = [UATagGroupsLookupResponse responseWithTagGroups:responseTagGroups
                                                                                    status:200
                                                                     lastModifiedTimestamp:@"2018-03-02T22:56:09"];

    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturn:self.requestedTagGroups] requestedTagGroups];
    [[[self.mockCache expect] andReturn:[NSDate distantPast]] creationDate];
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

    NSDate *cacheCreationDate = [NSDate date];

    [[[self.mockCache expect] andReturn:cacheCreationDate] creationDate];
    [[[self.mockCache expect] andReturnValue:@(NO)] isStale];

    self.testDate.absoluteTime = [NSDate date];
    NSTimeInterval expectedMaxAge = [[self.testDate now] timeIntervalSinceDate:cacheCreationDate] + self.lookupManager.preferLocalTagDataTime;
    UATagGroups *tagGroupsWithLocalMutations = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar", @"baz"], @"bleep" : @[@"bloop"]}];
    [[[self.mockMutationHistory expect] andReturn:tagGroupsWithLocalMutations] applyHistory:response.tagGroups maxAge:expectedMaxAge];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertEqualObjects(tagGroups, expectedTagGroups);
        XCTAssertNil(error);
        [fetchCompleted fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    [self.mockCache verify];
    [self.mockMutationHistory verify];
    [self.mockAPIClient verify];
}

- (void)testGetTagsCacheErrorMissingResponse {
    UATagGroups *responseTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar"]}];

    UATagGroupsLookupResponse *response = [UATagGroupsLookupResponse responseWithTagGroups:responseTagGroups
                                                                                    status:200
                                                                     lastModifiedTimestamp:@"2018-03-02T22:56:09"];

    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturn:self.requestedTagGroups] requestedTagGroups];
    [[[self.mockCache expect] andReturn:[NSDate distantPast]] creationDate];
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

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
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
    [[[self.mockCache expect] andReturn:[NSDate distantPast]] creationDate];
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

    [[[self.mockCache expect] andReturn:[NSDate dateWithTimeIntervalSinceNow:(-90 * 60)]] creationDate];
    [[[self.mockCache expect] andReturnValue:@(YES)] isStale];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.lookupManager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertNil(tagGroups);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, UATagGroupsLookupManagerErrorCodeCacheRefresh);
        [fetchCompleted fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    [self.mockCache verify];
    [self.mockAPIClient verify];
}

@end
