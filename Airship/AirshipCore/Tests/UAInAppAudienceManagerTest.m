/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAInAppAudienceManager+Internal.h"
#import "UAirship.h"
#import "UAChannel.h"
#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UAPendingTagGroupStore+Internal.h"
#import "AirshipTests-Swift.h"

@interface UAInAppAudienceManagerTest : UAAirshipBaseTest
@property (nonatomic, strong) UAInAppAudienceManager *manager;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockContact;
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
    self.mockContact = [self mockForClass:[UAContact class]];
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
                                                        contact:self.mockContact
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
        [[UATagGroupUpdate alloc] initWithGroup:@"foo" tags:@[@"bar", @"baz"] type:UATagGroupUpdateTypeAdd],
        [[UATagGroupUpdate alloc] initWithGroup:@"bleep" tags:@[@"bloop"] type:UATagGroupUpdateTypeAdd],
   ];

    NSDate *cacheRefreshDate = [NSDate dateWithTimeIntervalSinceNow:-60];

    [[[self.mockCache expect] andReturn:response] response];
    [[[self.mockCache expect] andReturn:self.requestedTagGroups] requestedTagGroups];
    [[[self.mockCache expect] andReturn:cacheRefreshDate] refreshDate];
    [[[self.mockCache expect] andReturnValue:@(NO)] needsRefresh];

    self.testDate.dateOverride = [NSDate date];

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
        [[UATagGroupUpdate alloc] initWithGroup:@"foo" tags:@[@"bar", @"baz"] type:UATagGroupUpdateTypeAdd],
        [[UATagGroupUpdate alloc] initWithGroup:@"bleep" tags:@[@"bloop"] type:UATagGroupUpdateTypeAdd],
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

    self.testDate.dateOverride = [NSDate date];

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

    self.testDate.dateOverride = [NSDate date];

    NSArray *localHistory = @[
        [[UATagGroupUpdate alloc] initWithGroup:@"foo" tags:@[@"bar", @"baz"] type:UATagGroupUpdateTypeAdd],
        [[UATagGroupUpdate alloc] initWithGroup:@"bleep" tags:@[@"bloop"] type:UATagGroupUpdateTypeAdd],
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
    self.testDate.dateOverride = [NSDate date];

    NSArray *localHistory = @[
        [[UATagGroupUpdate alloc] initWithGroup:@"foo" tags:@[@"one", @"two"] type:UATagGroupUpdateTypeRemove],
        [[UATagGroupUpdate alloc] initWithGroup:@"bar" tags:@[@"a"] type:UATagGroupUpdateTypeSet],
        [[UATagGroupUpdate alloc] initWithGroup:@"baz" tags:@[@"1"] type:UATagGroupUpdateTypeSet],
   ];

    [[[self.mockHistorian expect] andReturn:localHistory] tagHistoryNewerThan:[self.testDate.dateOverride dateByAddingTimeInterval:-self.manager.preferLocalTagDataTime]];

    NSArray *pendingTagUpates = @[
        [[UATagGroupUpdate alloc] initWithGroup:@"baz" tags:@[@"3"] type:UATagGroupUpdateTypeAdd],
        [[UATagGroupUpdate alloc] initWithGroup:@"foo" tags:@[@"one"] type:UATagGroupUpdateTypeAdd],
    ];

    [[[self.mockContact expect] andReturn:pendingTagUpates] pendingTagGroupUpdates];

    NSArray *pendingChannel = @[
        [UATagGroupsMutation mutationToAddTags:@[@"2"] group:@"baz"],
        [UATagGroupsMutation mutationToSetTags:@[@"b"] group:@"bar"]
    ];

    [[[self.mockChannel expect] andReturn:pendingChannel] pendingTagGroups];

    NSMutableArray *expected = [NSMutableArray array];
    [expected addObjectsFromArray:localHistory];
    [expected addObjectsFromArray:pendingTagUpates];
    [expected addObjectsFromArray:[pendingChannel[0] tagGroupUpdates]];
    [expected addObjectsFromArray:[pendingChannel[1] tagGroupUpdates]];
    
    NSSet *expectedSet = [NSSet setWithArray:[UAAudienceUtils collapseTagGroupUpdates:expected]];
    XCTAssertEqualObjects(expectedSet, [NSSet setWithArray:self.manager.tagOverrides]);
    XCTAssertTrue(YES);
}

- (void)testAttributeOverrides {
    self.testDate.dateOverride = [NSDate date];

    NSArray *localHistory = @[
        [[UAAttributeUpdate alloc] initWithAttribute:@"foo"
                                                type:UAAttributeUpdateTypeRemove
                                               value:nil
                                                date:[NSDate date]],
        
        [[UAAttributeUpdate alloc] initWithAttribute:@"bar"
                                                type:UAAttributeUpdateTypeSet
                                               value:@"1"
                                                date:[NSDate date]],
        
        [[UAAttributeUpdate alloc] initWithAttribute:@"baz"
                                                type:UAAttributeUpdateTypeSet
                                               value:@"a"
                                                date:[NSDate date]]
    ];
    
    [[[self.mockHistorian expect] andReturn:localHistory] attributeHistoryNewerThan:[self.testDate.dateOverride dateByAddingTimeInterval:-self.manager.preferLocalTagDataTime]];

    NSArray *pendingContact = @[
        [[UAAttributeUpdate alloc] initWithAttribute:@"foo"
                                                type:UAAttributeUpdateTypeSet
                                               value:@"some-value"
                                                date:[NSDate date]],
    ];
    
    [[[self.mockContact expect] andReturn:pendingContact] pendingAttributeUpdates];

    UAAttributePendingMutations *pendingChannel = [self setAttributeMutationWithKey:@"bar" value:@"2"];
    [[[self.mockChannel expect] andReturn:pendingChannel] pendingAttributes];

    NSMutableArray *expected = [NSMutableArray array];
    [expected addObjectsFromArray:localHistory];
    [expected addObjectsFromArray:pendingContact];
    [expected addObjectsFromArray:pendingChannel.attributeUpdates];

    XCTAssertEqualObjects([UAAudienceUtils collapseAttributeUpdates:expected], self.manager.attributeOverrides);
}

- (void)testContactChanged {
    [[self.mockCache expect] setResponse:nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:UAContact.contactChangedEvent
                                                        object:nil
                                                      userInfo:nil];

    [self.mockCache verify];
}

- (UAAttributePendingMutations *)setAttributeMutationWithKey:(NSString *)key value:(NSString *)value {
    UAAttributeMutations *attribute = [UAAttributeMutations mutations];
    [attribute setString:value forAttribute:key];
    return [UAAttributePendingMutations pendingMutationsWithMutations:attribute date:[[UADate alloc] init]];
}

- (UAAttributePendingMutations *)removeAttributeMutationWithKey:(NSString *)key {
    UAAttributeMutations *attribute = [UAAttributeMutations mutations];
    [attribute removeAttribute:key];
    return [UAAttributePendingMutations pendingMutationsWithMutations:attribute date:[[UADate alloc] init]];
}


@end
