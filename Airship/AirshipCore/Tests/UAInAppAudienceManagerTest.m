/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAInAppAudienceManager+Internal.h"
#import "UAirship.h"
#import "UAChannel.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UAPendingTagGroupStore+Internal.h"
#import "UATestDate.h"

@interface UAInAppAudienceManagerTest : UAAirshipBaseTest
@property (nonatomic, strong) UAInAppAudienceManager *manager;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockNamedUser;
@property (nonatomic, strong) id mockAPIClient;
@property (nonatomic, strong) id mockCache;
@property (nonatomic, strong) id mockHistorian;
@property (nonatomic, strong) UATagGroups *requestedTagGroups;
@property (nonatomic, strong) UATestDate *testDate;
@property (nonatomic, strong) id mockDelegate;
@end

@implementation UAInAppAudienceManagerTest

- (void)setUp {
    [super setUp];
    self.requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar", @"baz"]}];
    self.testDate = [[UATestDate alloc] init];

    self.mockDelegate = [self mockForProtocol:@protocol(UAInAppAudienceManagerDelegate)];
    [[[self.mockDelegate stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UATagGroups *) = (__bridge void(^)(UATagGroups *))arg;
        completionHandler(self.requestedTagGroups);
    }] gatherTagGroupsWithCompletionHandler:OCMOCK_ANY];

    [self setupMocks:@"channel" channelTagsEnabled:NO];

    self.manager.enabled = YES;
    self.manager.delegate = self.mockDelegate;
}

- (void)setupMocks:(NSString *)channelID channelTagsEnabled:(BOOL)enabled {
    self.mockAirship = [self mockForClass:[UAirship class]];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockNamedUser = [self mockForClass:[UANamedUser class]];
    self.mockAPIClient = [self mockForClass:[UATagGroupsLookupAPIClient class]];
    self.mockHistorian = [self mockForClass:[UAInAppAudienceHistorian class]];
    self.mockCache = [self mockForClass:[UATagGroupsLookupResponseCache class]];

    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];

    [[[self.mockChannel stub] andReturn:@[@"test"]] tags];
    [[[self.mockChannel stub] andReturn:channelID] identifier];
    [[[self.mockChannel stub] andReturnValue:@(enabled)] isChannelTagRegistrationEnabled];

    self.manager = [UAInAppAudienceManager managerWithAPIClient:self.mockAPIClient
                                                      dataStore:self.dataStore
                                                        channel:self.mockChannel
                                                      namedUser:self.mockNamedUser
                                                          cache:self.mockCache
                                                      historian:self.mockHistorian
                                                    currentTime:self.testDate];
}

- (void)testGetTagsComponentDisabled {
    self.manager.enabled = NO;

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.manager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertNil(tagGroups);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, UAInAppAudienceManagerErrorCodeComponentDisabled);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetTagsNoChannel {
    [self setupMocks:nil channelTagsEnabled:NO];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.manager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertNil(tagGroups);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, UAInAppAudienceManagerErrorCodeChannelRequired);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testGetOnlyDeviceTags {
    [self setupMocks:@"channel" channelTagsEnabled:YES];

    self.requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"device" : @[@"override"]}];

    [[self.mockAPIClient reject] lookupTagGroupsWithChannelID:OCMOCK_ANY requestedTagGroups:OCMOCK_ANY cachedResponse:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.manager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
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

    NSArray *localHistory = @[
        [UATagGroupsMutation mutationToAddTags:@[@"bar", @"baz"] group:@"foo"],
        [UATagGroupsMutation mutationToAddTags:@[@"bloop"] group:@"bleep"]
    ];

    NSDate *cacheRefreshDate = [NSDate dateWithTimeIntervalSinceNow:-60];

    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturn:self.requestedTagGroups] requestedTagGroups];
    [[[self.mockCache expect] andReturn:cacheRefreshDate] refreshDate];
    [[[self.mockCache expect] andReturnValue:@(NO)] needsRefresh];


    self.testDate.absoluteTime = [NSDate date];

    [[[self.mockHistorian expect] andReturn:localHistory] tagHistoryNewerThan:[cacheRefreshDate dateByAddingTimeInterval:-self.manager.preferLocalTagDataTime]];

    [[self.mockAPIClient reject] lookupTagGroupsWithChannelID:OCMOCK_ANY requestedTagGroups:OCMOCK_ANY cachedResponse:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.manager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertEqualObjects(tagGroups, expectedTagGroups);
        XCTAssertNil(error);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCache verify];
    [self.mockHistorian verify];
    [self.mockAPIClient verify];
}

- (void)testGetTagsEmptyCache {

    [[[self.mockCache expect] andReturn:nil] response];
    [[[self.mockCache expect] andReturn:nil] refreshDate];

    UATagGroups *responseTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo": @[@"bar"]}];

    UATagGroupsLookupResponse *response = [UATagGroupsLookupResponse responseWithTagGroups:responseTagGroups
                                                                                    status:200
                                                                     lastModifiedTimestamp:@"2018-03-02T22:56:09"];


    NSArray *localHistory = @[
        [UATagGroupsMutation mutationToAddTags:@[@"bar", @"baz"] group:@"foo"],
        [UATagGroupsMutation mutationToAddTags:@[@"bloop"] group:@"bleep"]
    ];

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

    [[[self.mockHistorian expect] andReturn:localHistory] tagHistoryNewerThan:[cacheRefreshDate dateByAddingTimeInterval:-self.manager.preferLocalTagDataTime]];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.manager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertEqualObjects(tagGroups, expectedTagGroups);
        XCTAssertNil(error);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCache verify];
    [self.mockHistorian verify];
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

    NSArray *localHistory = @[
        [UATagGroupsMutation mutationToAddTags:@[@"bar", @"baz"] group:@"foo"],
        [UATagGroupsMutation mutationToAddTags:@[@"bloop"] group:@"bleep"]
    ];

    [[[self.mockHistorian expect] andReturn:localHistory] tagHistoryNewerThan:[cacheRefreshDate dateByAddingTimeInterval:-self.manager.preferLocalTagDataTime]];

    UATagGroups *expectedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    XCTestExpectation *fetchCompleted = [self expectationWithDescription:@"fetch completed"];

    [self.manager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertEqualObjects(tagGroups, expectedTagGroups);
        XCTAssertNil(error);
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCache verify];
    [self.mockHistorian verify];
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

    [self.manager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertNil(tagGroups);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, UAInAppAudienceManagerErrorCodeCacheRefresh);
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

    [self.manager getTagGroups:self.requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        XCTAssertNil(tagGroups);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, UAInAppAudienceManagerErrorCodeCacheRefresh);
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

    [self.manager getTagGroups:requestedTagGroups completionHandler:^(UATagGroups * _Nonnull tagGroups, NSError * _Nonnull error) {
        [fetchCompleted fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCache verify];
    [self.mockAPIClient verify];
}

- (void)testTagOverrides {
    self.testDate.absoluteTime = [NSDate date];

    NSArray *localHistory = @[
        [UATagGroupsMutation mutationToRemoveTags:@[@"one", @"two"] group:@"foo"],
        [UATagGroupsMutation mutationToSetTags:@[@"a"] group:@"bar"],
        [UATagGroupsMutation mutationToSetTags:@[@"1"] group:@"baz"]
    ];

    [[[self.mockHistorian expect] andReturn:localHistory] tagHistoryNewerThan:[self.testDate.absoluteTime dateByAddingTimeInterval:-self.manager.preferLocalTagDataTime]];

    NSArray *pendingNamedUser = @[
        [UATagGroupsMutation mutationToSetTags:@[@"3"] group:@"baz"],
        [UATagGroupsMutation mutationToAddTags:@[@"one"] group:@"foo"]
    ];

    [[[self.mockNamedUser expect] andReturn:pendingNamedUser] pendingTagGroups];

    NSArray *pendingChannel = @[
        [UATagGroupsMutation mutationToAddTags:@[@"2"] group:@"baz"],
        [UATagGroupsMutation mutationToSetTags:@[@"b"] group:@"bar"]
    ];

    [[[self.mockChannel expect] andReturn:pendingChannel] pendingTagGroups];

    NSMutableArray *expected = [NSMutableArray array];
    [expected addObjectsFromArray:localHistory];
    [expected addObjectsFromArray:pendingNamedUser];
    [expected addObjectsFromArray:pendingChannel];

    XCTAssertEqualObjects([UATagGroupsMutation collapseMutations:expected], self.manager.tagOverrides);
}

@end
