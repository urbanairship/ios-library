/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UANamedUser+Internal.h"
#import "UANamedUserAPIClient+Internal.h"
#import "UAChannel+Internal.h"
#import "UARuntimeConfig.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATestDate.h"
#import "UAAttributePendingMutations+Internal.h"

@interface UANamedUserTest : UAAirshipBaseTest

@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) id mockedNamedUserClient;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockTagGroupsRegistrar;
@property (nonatomic, strong) id mockAttributeRegistrar;
@property (nonatomic, strong) id mockTimeZone;
@property (nonatomic, strong) UATestDate *testDate;

@property (nonatomic, strong) UANamedUser *namedUser;
@property (nonatomic, copy) NSString *pushChannelID;
@property (nonatomic, strong) NSMutableDictionary *addTagGroups;
@property (nonatomic, strong) NSMutableDictionary *removeTagGroups;
@property (nonatomic, copy) UAChannelRegistrationExtenderBlock channelRegistrationExtenderBlock;

@end

@implementation UANamedUserTest

void (^namedUserSuccessDoBlock)(NSInvocation *);
void (^namedUserFailureDoBlock)(NSInvocation *);

- (void)setUp {
    [super setUp];

    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];
    
    self.mockChannel = [self mockForClass:[UAChannel class]];
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&self->_pushChannelID];
    }] identifier];

    self.mockedAirship = [self mockForClass:[UAirship class]];
    [[[self.mockedAirship stub] andReturn:self.mockChannel] channel];
    [UAirship setSharedAirship:self.mockedAirship];

    self.pushChannelID = @"someChannel";

    self.mockTagGroupsRegistrar = [self mockForClass:[UATagGroupsRegistrar class]];
    self.mockAttributeRegistrar = [self mockForClass:[UAAttributeRegistrar class]];

    self.mockTimeZone = [self mockForClass:[NSTimeZone class]];
    [[[self.mockTimeZone stub] andReturn:self.mockTimeZone] defaultTimeZone];
    
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];

    // Capture the channel payload extender
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
           void *arg;
           [invocation getArgument:&arg atIndex:2];
           self.channelRegistrationExtenderBlock =  (__bridge UAChannelRegistrationExtenderBlock)arg;
    }] addChannelExtenderBlock:OCMOCK_ANY];

    self.namedUser = [UANamedUser namedUserWithChannel:self.mockChannel
                                                config:self.config
                                             dataStore:self.dataStore
                                    tagGroupsRegistrar:self.mockTagGroupsRegistrar
                                    attributeRegistrar:self.mockAttributeRegistrar
                                                  date:self.testDate];

    self.mockedNamedUserClient = [self mockForClass:[UANamedUserAPIClient class]];
    self.namedUser.namedUserAPIClient = self.mockedNamedUserClient;

    // set up the named user
    self.namedUser.identifier = @"fakeNamedUser";
    self.namedUser.changeToken = @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE";
    self.namedUser.lastUpdatedToken = @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE";

    namedUserSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UANamedUserAPIClientSuccessBlock successBlock = (__bridge UANamedUserAPIClientSuccessBlock)arg;
        successBlock();
    };

    namedUserFailureDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        UANamedUserAPIClientFailureBlock failureBlock = (__bridge UANamedUserAPIClientFailureBlock)arg;
        failureBlock(400);
    };
}

- (void)tearDown {
    [self.mockedNamedUserClient stopMocking];
    [self.mockedAirship stopMocking];
    [self.mockChannel stopMocking];
    [super tearDown];
}

/**
 * Test set valid ID (associate).
 */
- (void)testSetIDValid {
    NSString *changeToken = self.namedUser.changeToken;
    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] associate:@"superFakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                         onSuccess:OCMOCK_ANY
                                                                         onFailure:OCMOCK_ANY];

    self.namedUser.identifier = @"superFakeNamedUser";

    XCTAssertEqualObjects(@"superFakeNamedUser", self.namedUser.identifier,
                          @"Named user ID should be set.");
    XCTAssertEqualObjects(@"superFakeNamedUser", [self.dataStore stringForKey:UANamedUserIDKey],
                          @"Named user ID should be stored in standardUserDefaults.");
    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change tokens should have changed.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be associated");
}

/**
 * Test set invalid ID.
 */
- (void)testSetIDInvalid {
    NSString *changeToken = self.namedUser.changeToken;
    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    NSString *currentID = self.namedUser.identifier;
    self.namedUser.identifier = @"         ";

    XCTAssertEqualObjects(currentID, self.namedUser.identifier,
                          @"Named user ID should not have changed.");
    XCTAssertEqualObjects(changeToken, self.namedUser.changeToken,
                          @"Change tokens should remain the same.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should not be associated");
}

/**
 * Test set empty ID (disassociate).
 */
- (void)testSetIDEmpty {
    NSString *changeToken = self.namedUser.changeToken;
    // Expect the named user client to disassociate and call the success block
    [[self.mockedNamedUserClient expect] disassociate:@"someChannel"
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];
    self.namedUser.identifier = @"";

    XCTAssertNil(self.namedUser.identifier, @"Named user ID should be nil.");
    XCTAssertNil([self.dataStore stringForKey:UANamedUserIDKey],
                 @"Named user ID should be able to be cleared in standardUserDefaults.");
    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change tokens should have changed.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be disassociated");
}

/**
 * Test set nil ID (disassociate).
 */
- (void)testSetIDNil {
    NSString *changeToken = self.namedUser.changeToken;
    // Expect the named user client to disassociate and call the success block
    [[self.mockedNamedUserClient expect] disassociate:@"someChannel"
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];
    self.namedUser.identifier = nil;

    XCTAssertNil(self.namedUser.identifier, @"Named user ID should be nil.");
    XCTAssertNil([self.dataStore stringForKey:UANamedUserIDKey],
                 @"Named user ID should be able to be cleared in standardUserDefaults.");
    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change tokens should have changed.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be disassociated");
}

/**
 * Test set ID when channel doesn't exist sets ID, but fails to associate
 */
- (void)testSetIDNoChannel {
    self.pushChannelID = nil;

    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    NSString *changeToken = self.namedUser.changeToken;
    NSString *lastUpdatedToken = self.namedUser.lastUpdatedToken;

    self.namedUser.identifier = @"kindaFakeNamedUser";

    XCTAssertEqualObjects(@"kindaFakeNamedUser", self.namedUser.identifier,
                          @"Named user ID should match.");
    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Named user change token should not remain the same.");
    XCTAssertEqualObjects(lastUpdatedToken, self.namedUser.lastUpdatedToken,
                          @"Named user last updated token should remain the same.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should not be associated");
}

/**
 * Test when IDs match, don't update named user
 */
- (void)testIDsMatchNoUpdate {
    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    NSString *currentID = self.namedUser.identifier;
    NSString *changeToken = self.namedUser.changeToken;
    NSString *lastUpdatedToken = self.namedUser.lastUpdatedToken;

    self.namedUser.identifier = currentID;

    XCTAssertEqualObjects(currentID, self.namedUser.identifier,
                          @"Named user ID should match.");
    XCTAssertEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Named user change token should remain the same.");
    XCTAssertEqualObjects(lastUpdatedToken, self.namedUser.lastUpdatedToken,
                          @"Named user last updated token should remain the same.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should not be associated");
}

/**
 * Test set change token.
 */
- (void)testSetChangeToken {
    self.namedUser.changeToken = @"fakeChangeToken";
    XCTAssertEqualObjects(@"fakeChangeToken", self.namedUser.changeToken,
                          @"Named user change token should be set.");
    XCTAssertEqualObjects(@"fakeChangeToken", [self.dataStore stringForKey:UANamedUserChangeTokenKey],
                          @"Named user change token should be stored in standardUserDefaults.");
}

/**
 * Test set last updated token.
 */
- (void)testSetLastUpdatedToken {
    self.namedUser.lastUpdatedToken = @"fakeLastUpdatedToken";
    XCTAssertEqualObjects(@"fakeLastUpdatedToken", self.namedUser.lastUpdatedToken,
                          @"Named user lsat updated token should be set.");
    XCTAssertEqualObjects(@"fakeLastUpdatedToken", [self.dataStore stringForKey:UANamedUserLastUpdatedTokenKey],
                          @"Named user last updated token should be stored in standardUserDefaults.");
}

/**
 * Test update will skip update on a new or re-install.
 */
- (void)testUpdateSkipUpdateOnNewInstall {
    self.namedUser.changeToken = nil;
    self.namedUser.lastUpdatedToken = nil;

    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];

    [self.namedUser update];

    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user client should not associate or disassociate.");
}

/**
 * Test update will skip update when named user already updated.
 */
- (void)testUpdateSkipUpdateSameNamedUser {
    // Named user client should not associate
    [[self.mockedNamedUserClient expect] associate:OCMOCK_ANY channelID:OCMOCK_ANY onSuccess:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(void) = obj;
        completionBlock();
        return YES;
    }] onFailure:OCMOCK_ANY];

    [self.namedUser update];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];

    [self.namedUser update];

    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user client should not associate or disassociate.");
}

/**
 * Test update will skip update when channel ID doesn't exist.
 */
- (void)testUpdateSkipUpdateNoChannel {
    self.pushChannelID = nil;

    self.namedUser.changeToken = @"AbcToken";
    self.namedUser.lastUpdatedToken = @"XyzToken";

    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                         onSuccess:OCMOCK_ANY
                                         onFailure:OCMOCK_ANY];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];

    [self.namedUser update];

    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user client should not associate or disassociate.");
}

/**
 * Test disassociateNamedUserIfNil when named user is nil.
 */
- (void)testDisassociateNamedUserNil {
    self.namedUser.identifier = nil;

    // Expect the named user client to disassociate
    [[self.mockedNamedUserClient expect] disassociate:@"someChannel"
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];

    self.namedUser.changeToken = nil;
    [self.namedUser disassociateNamedUserIfNil];

    XCTAssertNil(self.namedUser.identifier, @"Named user ID should remain nil.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user should be disassociated");
}

/**
 * Test disassociateNamedUserIfNil when named user is not nil.
 */
- (void)testDisassociateNamedUserNonNil {

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                            onSuccess:OCMOCK_ANY
                                            onFailure:OCMOCK_ANY];

    [self.namedUser disassociateNamedUserIfNil];

    XCTAssertEqualObjects(@"fakeNamedUser", self.namedUser.identifier,
                          @"Named user ID should remain the same.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user should not be disassociated");
}

/**
 * Test force update changes the current token and updates named user.
 */
- (void)testForceUpdate {
    NSString *changeToken = self.namedUser.changeToken;

    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                         onSuccess:OCMOCK_ANY
                                                                         onFailure:OCMOCK_ANY];

    [self.namedUser forceUpdate];

    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change token should have changed.");
    XCTAssertEqualObjects(self.namedUser.changeToken, self.namedUser.lastUpdatedToken,
                          @"Tokens should match.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be associated");
}

/**
 * Test update will reassociate named user if the channel ID changes.
 */
- (void)testUpdateChannelIDChanged {
    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                         onSuccess:OCMOCK_ANY
                                                                         onFailure:OCMOCK_ANY];

    [self.namedUser forceUpdate];

    // Change the channelID
    self.pushChannelID = @"neat";

    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"neat"
                                                                         onSuccess:OCMOCK_ANY
                                                                         onFailure:OCMOCK_ANY];

    [self.namedUser update];

    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be associated");
}

/**
 * Test that the tag groups registrar is called when UANamedUser is asked to update tags
 */
- (void)testUpdateTags {
    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar expect] updateTagGroupsForID:[OCMArg checkWithBlock:^BOOL(id obj) {
        return (obj != nil);
    }]];
    
    // TEST
    [self.namedUser updateTags];
    
    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Test that the tag groups registrar is called when UANamedUser is asked to add tags
 */
- (void)testAddTags {
    NSArray *tags = @[@"foo", @"bar"];
    NSString *group = @"group";

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar expect] addTags:tags group:group];

    // TEST
    [self.namedUser addTags:tags group:group];;

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Test that the tag groups registrar is not called when UANamedUser is asked to add device tags and data collection is disabled.
 */
- (void)testAddDeviceTagsDataCollectionDisabled {
    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];

    NSArray *tags = @[@"foo", @"bar"];
    NSString *group = @"group";

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] addTags:tags group:group];

    // TEST
    [self.namedUser addTags:tags group:group];;

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Test that the tag groups registrar is called when UANamedUser is asked to add device tags when data collection is enabled.
 */
- (void)testAddDeviceTagsDataCollectionEnabled {
    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];

    NSArray *tags = @[@"foo", @"bar"];
    NSString *group = @"group";

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar expect] addTags:tags group:group];

    // TEST
    [self.namedUser addTags:tags group:group];;

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Test that the tag groups registrar is called when UANamedUser is asked to remove tags
 */
- (void)testRemoveTags {
    NSArray *tags = @[@"foo", @"bar"];
    NSString *group = @"group";

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar expect] removeTags:tags group:group];

    // TEST
    [self.namedUser removeTags:tags group:group];;

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Test that the tag groups registrar is not called when UANamedUser is asked to remove device tags and data collection is disabled.
 */
- (void)testRemoveDeviceTagsDataCollectionDisabled {
    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];

    NSArray *tags = @[@"foo", @"bar"];
    NSString *group = @"group";

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] removeTags:tags group:group];

    // TEST
    [self.namedUser removeTags:tags group:group];;

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Test that the tag groups registrar is called when UANamedUser is asked to remove device tags when data collection is enabled.
 */
- (void)testRemoveDeviceTagsDataCollectionEnabled {
    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];

    NSArray *tags = @[@"foo", @"bar"];
    NSString *group = @"group";

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar expect] removeTags:tags group:group];

    // TEST
    [self.namedUser removeTags:tags group:group];;

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Test that the tag groups registrar is called when UANamedUser is asked to set tags
 */
- (void)testSetTags {
    NSArray *tags = @[@"foo", @"bar"];
    NSString *group = @"group";

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar expect] setTags:tags group:group];

    // TEST
    [self.namedUser setTags:tags group:group];;

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Test that the tag groups registrar is not called when UANamedUser is asked to set device tags and data collection is disabled.
 */
- (void)testSetDeviceTagsDataCollectionDisabled {
    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];

    NSArray *tags = @[@"foo", @"bar"];
    NSString *group = @"group";

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar reject] setTags:tags group:group];

    // TEST
    [self.namedUser setTags:tags group:group];;

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

/**
 * Test that the tag groups registrar is called when UANamedUser is asked to set device tags when data collection is enabled.
 */
- (void)testSetDeviceTagsDataCollectionEnabled {
    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];

    NSArray *tags = @[@"foo", @"bar"];
    NSString *group = @"group";

    // EXPECTATIONS
    [[self.mockTagGroupsRegistrar expect] setTags:tags group:group];

    // TEST
    [self.namedUser setTags:tags group:group];

    // VERIFY
    [self.mockTagGroupsRegistrar verify];
}

- (void)testSetIdentifierDataCollectionDisabled {
    self.namedUser.identifier = nil;
    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];
    self.namedUser.identifier = @"neat";
    XCTAssertNil(self.namedUser.identifier);
}

- (void)testClearNamedUserOnDataCollectionDisabled {
    self.namedUser.identifier = @"neat";
    XCTAssertNotNil(self.namedUser.identifier);

    // Expect the named user client to disassociate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] disassociate:@"someChannel"
                                                                         onSuccess:OCMOCK_ANY
                                                                         onFailure:OCMOCK_ANY];

    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];
    [self.namedUser onDataCollectionEnabledChanged];

    XCTAssertNil(self.namedUser.identifier);

    [self.mockedNamedUserClient verify];
}

/**
 * Test registration payload extender.
 */
- (void)testRegistrationPayloadExtender {
    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    XCTestExpectation *extendedPayload = [self expectationWithDescription:@"extended payload"];
    self.channelRegistrationExtenderBlock(payload, ^(UAChannelRegistrationPayload * _Nonnull payload) {
        XCTAssertEqualObjects(self.namedUser.identifier, payload.namedUserId);
        [extendedPayload fulfill];
    });

    [self waitForTestExpectations];
}

/**
 * Test changing named user id updates channel registration .
 */
- (void)testChangingIdUpdatesChannelRegistration {
    
    [[self.mockChannel expect] updateRegistration];
    
    self.namedUser.identifier = @"a_different_named_user";
    
    [self.mockChannel verify];
}

- (void)testClearNamedUserAttributesOnDataCollectionDisabled {
    // Expect the named user client to disassociate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] disassociate:@"someChannel"
                                                                         onSuccess:OCMOCK_ANY
                                                                         onFailure:OCMOCK_ANY];

    // expect pending mutations to be deleted
    [[self.mockAttributeRegistrar expect] deletePendingMutations];
    
    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];
    [self.namedUser onDataCollectionEnabledChanged];

    [self.mockedNamedUserClient verify];
    [self.mockAttributeRegistrar verify];
}

/**
 * Tests adding a named user attribute results in save and update called when a named user is present.
 */
- (void)testAddNamedUserAttribute {
    [self.mockTimeZone stopMocking];

    UAAttributeMutations *addMutation = [UAAttributeMutations mutations];
    [addMutation setString:@"string" forAttribute:@"attribute"];

    UAAttributePendingMutations *expectedPendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:addMutation date:self.testDate];

    [[self.mockAttributeRegistrar expect] savePendingMutations:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAAttributePendingMutations *pendingMutations = (UAAttributePendingMutations *)obj;
        return [pendingMutations.payload isEqualToDictionary:expectedPendingMutations.payload];
    }]];

    [[self.mockAttributeRegistrar expect] updateAttributesForNamedUser:self.namedUser.identifier];

    [self.namedUser applyAttributeMutations:addMutation];

    [self.mockAttributeRegistrar verify];
}

/**
 * Tests adding a named user attribute results in a save but does not result in a registration call to update with mutations when no named user is present.
 */
- (void)testAddNamedUserAttributeNoNamedUser {
    [self.mockTimeZone stopMocking];

    UAAttributeMutations *addMutation = [UAAttributeMutations mutations];

    [addMutation setString:@"string" forAttribute:@"attribute"];
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];

    UAAttributePendingMutations *expectedPendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:addMutation date:self.testDate];

    [[self.mockAttributeRegistrar expect] savePendingMutations:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAAttributePendingMutations *pendingMutations = (UAAttributePendingMutations *)obj;
        return [pendingMutations.payload isEqualToDictionary:expectedPendingMutations.payload];
    }]];

    [[self.mockAttributeRegistrar reject] updateAttributesForNamedUser:OCMOCK_ANY];

    self.namedUser.identifier = nil;
    
    [self.namedUser applyAttributeMutations:addMutation];

    [self.mockAttributeRegistrar verify];
}

/**
 * Test updateNamedUserAttributes method if the named user component is disabled
 */
- (void)testUpdateNamedUserAttributesIfComponentDisabled {
    self.namedUser.componentEnabled = NO;

    [[self.mockAttributeRegistrar reject] updateAttributesForNamedUser:OCMOCK_ANY];

    UAAttributeMutations *addMutation = [UAAttributeMutations mutations];
    [addMutation setString:@"string" forAttribute:@"attribute"];
    
    [self.namedUser applyAttributeMutations:addMutation];
    [self.mockAttributeRegistrar verify];
}

/**
 * Test updateNamedUserAttributes method if the identifier is not set and the named user component enabled
 */
- (void)testUpdateNamedUserAttributesIfIdentifierNil {
    self.namedUser.componentEnabled = YES;
    self.namedUser.identifier = nil;
    
    [[self.mockAttributeRegistrar reject] updateAttributesForNamedUser:OCMOCK_ANY];
    
    UAAttributeMutations *addMutation = [UAAttributeMutations mutations];
    [addMutation setString:@"string" forAttribute:@"attribute"];
    
    [self.namedUser applyAttributeMutations:addMutation];
    [self.mockAttributeRegistrar verify];
}

/**
 * Test updateNamedUserAttributes method if the identifier is set and the named user component enabled
 */
- (void)testUpdateNamedUserAttributes {
    self.namedUser.componentEnabled = YES;
    
    [[self.mockAttributeRegistrar expect] updateAttributesForNamedUser:OCMOCK_ANY];
    
    UAAttributeMutations *addMutation = [UAAttributeMutations mutations];
    [addMutation setString:@"string" forAttribute:@"attribute"];
    
    [self.namedUser applyAttributeMutations:addMutation];
    [self.mockAttributeRegistrar verify];
}

- (void)testSetComponentEnabledYES {
    self.namedUser.componentEnabled = NO;

    [[self.mockAttributeRegistrar expect] setComponentEnabled:YES];
    [[self.mockTagGroupsRegistrar expect] setEnabled:YES];
    [[self.mockedNamedUserClient expect] setEnabled:YES];

    self.namedUser.componentEnabled = YES;

    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
    [self.mockedNamedUserClient verify];
}

- (void)testSetComponentEnabledYESDataCollectionDisabled {
    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];

    self.namedUser.componentEnabled = NO;

    [[self.mockAttributeRegistrar reject] setComponentEnabled:YES];
    [[self.mockTagGroupsRegistrar reject] setEnabled:YES];
    [[self.mockedNamedUserClient reject] setEnabled:YES];

    self.namedUser.componentEnabled = YES;

    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
    [self.mockedNamedUserClient verify];
}

- (void)testSetComponentEnabledNO {
    [[self.mockAttributeRegistrar expect] setComponentEnabled:NO];
    [[self.mockTagGroupsRegistrar expect] setEnabled:NO];
    [[self.mockedNamedUserClient expect] setEnabled:NO];

    self.namedUser.componentEnabled = NO;

    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
    [self.mockedNamedUserClient verify];
}

- (void)testSetDataCollectionEnabledYES {
    NSString *changeToken = self.namedUser.changeToken;

    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];

    [[self.mockAttributeRegistrar expect] setComponentEnabled:YES];
    [[self.mockTagGroupsRegistrar expect] setEnabled:YES];
    [[self.mockedNamedUserClient expect] setEnabled:YES];

    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                         onSuccess:OCMOCK_ANY
                                                                         onFailure:OCMOCK_ANY];

    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];
    [self.namedUser onDataCollectionEnabledChanged];

    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change token should have changed.");
    XCTAssertEqualObjects(self.namedUser.changeToken, self.namedUser.lastUpdatedToken,
                          @"Tokens should match.");

    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
    [self.mockedNamedUserClient verify];
}

- (void)testSetDataCollectionEnabledYESComponentDisabled {
    NSString *changeToken = self.namedUser.changeToken;

    self.namedUser.componentEnabled = NO;
    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];

    [[self.mockAttributeRegistrar reject] setComponentEnabled:YES];
    [[self.mockTagGroupsRegistrar reject] setEnabled:YES];
    [[self.mockedNamedUserClient reject] setEnabled:YES];

    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                         onSuccess:OCMOCK_ANY
                                                                         onFailure:OCMOCK_ANY];

    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];
    [self.namedUser onDataCollectionEnabledChanged];

    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change token should have changed.");
    XCTAssertEqualObjects(self.namedUser.changeToken, self.namedUser.lastUpdatedToken,
                          @"Tokens should match.");

    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
    [self.mockedNamedUserClient verify];
}

- (void)testSetDataCollectionEnabledNO {
    NSString *changeToken = self.namedUser.changeToken;

    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];

    [[self.mockAttributeRegistrar expect] setComponentEnabled:NO];
    [[self.mockAttributeRegistrar expect] deletePendingMutations];

    [[self.mockTagGroupsRegistrar expect] setEnabled:NO];
    [[self.mockTagGroupsRegistrar expect] clearAllPendingTagUpdates];

    [[self.mockedNamedUserClient expect] setEnabled:NO];
    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:namedUserSuccessDoBlock] disassociate:@"someChannel"
                                                                            onSuccess:OCMOCK_ANY
                                                                            onFailure:OCMOCK_ANY];

    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];
    [self.namedUser onDataCollectionEnabledChanged];

    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change token should have changed.");
    XCTAssertNotEqualObjects(self.namedUser.changeToken, self.namedUser.lastUpdatedToken,
                          @"Tokens should not match.");
    XCTAssertNil(self.namedUser.identifier);

    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
    [self.mockedNamedUserClient verify];
}

@end
