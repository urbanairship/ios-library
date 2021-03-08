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
#import "UAAttributePendingMutations.h"
#import "UATaskManager.h"

static NSString * const UANamedUserUpdateTaskID = @"UANamedUser.update";
static NSString * const UANamedUserTagUpdateTaskID = @"UANamedUser.tags.update";
static NSString * const UANamedUserAttributeUpdateTaskID = @"UANamedUser.attributes.update";

@interface UANamedUserTest : UAAirshipBaseTest

@property (nonatomic, strong) id mockedAirship;
@property (nonatomic, strong) id mockedNamedUserClient;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockTagGroupsRegistrar;
@property (nonatomic, strong) id mockAttributeRegistrar;
@property (nonatomic, strong) id mockTimeZone;
@property (nonatomic, strong) id mockNotificationCenter;

@property (nonatomic, strong) UATestDate *testDate;

@property (nonatomic, strong) UANamedUser *namedUser;
@property (nonatomic, copy) NSString *pushChannelID;
@property (nonatomic, strong) NSMutableDictionary *addTagGroups;
@property (nonatomic, strong) NSMutableDictionary *removeTagGroups;
@property (nonatomic, copy) UAChannelRegistrationExtenderBlock channelRegistrationExtenderBlock;
@property (nonatomic, strong) id mockTaskManager;
@property(nonatomic, copy) void (^launchHandler)(id<UATask>);

@end

@implementation UANamedUserTest

void (^associateSuccessDoBlock)(NSInvocation *);
void (^disassociateSuccessDoBlock)(NSInvocation *);

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

    self.mockNotificationCenter = [self partialMockForObject:[NSNotificationCenter defaultCenter]];

    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];

    // Capture the channel payload extender
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        self.channelRegistrationExtenderBlock =  (__bridge UAChannelRegistrationExtenderBlock)arg;
    }] addChannelExtenderBlock:OCMOCK_ANY];

    self.mockTaskManager = [self mockForClass:[UATaskManager class]];

    // Capture the task launcher
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        self.launchHandler =  (__bridge void (^)(id<UATask>))arg;
    }] registerForTaskWithIDs:@[UANamedUserUpdateTaskID, UANamedUserTagUpdateTaskID, UANamedUserAttributeUpdateTaskID] dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];

    self.namedUser = [UANamedUser namedUserWithChannel:self.mockChannel
                                                config:self.config
                                    notificationCenter:self.mockNotificationCenter
                                             dataStore:self.dataStore
                                    tagGroupsRegistrar:self.mockTagGroupsRegistrar
                                    attributeRegistrar:self.mockAttributeRegistrar
                                                  date:self.testDate
                                           taskManager:self.mockTaskManager];

    self.mockedNamedUserClient = [self mockForClass:[UANamedUserAPIClient class]];
    self.namedUser.namedUserAPIClient = self.mockedNamedUserClient;

    // set up the named user
    self.namedUser.identifier = @"fakeNamedUser";
    self.namedUser.changeToken = @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE";
    self.namedUser.lastUpdatedToken = @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE";

    associateSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(NSError * _Nullable);
        completionHandler = (__bridge void (^)(NSError * _Nullable))arg;
        completionHandler(nil);
    };

    disassociateSuccessDoBlock = ^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(NSError * _Nullable);
        completionHandler = (__bridge void (^)(NSError * _Nullable))arg;
        completionHandler([NSError errorWithDomain:@"error" code:0 userInfo:@{}]);
    };
}


- (void)tearDown {
    [self.mockTimeZone stopMocking];
    [self.mockNotificationCenter stopMocking];
    [super tearDown];
}

/**
 * Test set valid ID (associate).
 */
- (void)testSetIDValid {
    NSString *changeToken = self.namedUser.changeToken;
    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:associateSuccessDoBlock] associate:@"superFakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                 completionHandler:OCMOCK_ANY];

    [[self.mockNotificationCenter expect] postNotificationName:UANamedUserIdentifierChangedNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserIdentifierChangedNotificationIdentifierKey : @"superFakeNamedUser"}];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyReplace requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    self.namedUser.identifier = @"superFakeNamedUser";

    [self.mockTaskManager verify];

    XCTAssertEqualObjects(@"superFakeNamedUser", self.namedUser.identifier,
                          @"Named user ID should be set.");
    XCTAssertEqualObjects(@"superFakeNamedUser", [self.dataStore stringForKey:UANamedUserIDKey],
                          @"Named user ID should be stored in standardUserDefaults.");
    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change tokens should have changed.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be associated");
    XCTAssertNoThrow([self.mockNotificationCenter verify], @"Change notification should be posted");
}

/**
 * Test set invalid ID.
 */
- (void)testSetIDInvalid {
    NSString *changeToken = self.namedUser.changeToken;
    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [[self.mockNotificationCenter reject] postNotificationName:UANamedUserIdentifierChangedNotification
                                                        object:OCMOCK_ANY
                                                      userInfo:OCMOCK_ANY];

    NSString *currentID = self.namedUser.identifier;
    self.namedUser.identifier = @"         ";

    XCTAssertEqualObjects(currentID, self.namedUser.identifier,
                          @"Named user ID should not have changed.");
    XCTAssertEqualObjects(changeToken, self.namedUser.changeToken,
                          @"Change tokens should remain the same.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should not be associated");
    XCTAssertNoThrow([self.mockNotificationCenter verify], @"Change notification should not be posted");
}

/**
 * Test set empty ID (disassociate).
 */
- (void)testSetIDEmpty {
    NSString *changeToken = self.namedUser.changeToken;
    // Expect the named user client to disassociate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:disassociateSuccessDoBlock] disassociate:@"someChannel"
                                    completionHandler:OCMOCK_ANY];

    [[self.mockNotificationCenter expect] postNotificationName:UANamedUserIdentifierChangedNotification
                                                        object:nil
                                                      userInfo:@{}];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyReplace requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    self.namedUser.identifier = @"";

    [self.mockTaskManager verify];

    XCTAssertNil(self.namedUser.identifier, @"Named user ID should be nil.");
    XCTAssertNil([self.dataStore stringForKey:UANamedUserIDKey],
                 @"Named user ID should be able to be cleared in standardUserDefaults.");
    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change tokens should have changed.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be disassociated");
    XCTAssertNoThrow([self.mockNotificationCenter verify], @"Change notification should be posted");
}

/**
 * Test set nil ID (disassociate).
 */
- (void)testSetIDNil {
    NSString *changeToken = self.namedUser.changeToken;
    // Expect the named user client to disassociate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:disassociateSuccessDoBlock] disassociate:@"someChannel"
                                    completionHandler:OCMOCK_ANY];

    [[self.mockNotificationCenter expect] postNotificationName:UANamedUserIdentifierChangedNotification
                                                        object:nil
                                                      userInfo:@{}];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyReplace requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    self.namedUser.identifier = nil;

    [self.mockTaskManager verify];
    XCTAssertNil(self.namedUser.identifier, @"Named user ID should be nil.");
    XCTAssertNil([self.dataStore stringForKey:UANamedUserIDKey],
                 @"Named user ID should be able to be cleared in standardUserDefaults.");
    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change tokens should have changed.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be disassociated");
    XCTAssertNoThrow([self.mockNotificationCenter verify], @"Change notification should be posted");
}

/**
 * Test set ID when channel doesn't exist sets ID, but fails to associate
 */
- (void)testSetIDNoChannel {
    self.pushChannelID = nil;

    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [[self.mockNotificationCenter expect] postNotificationName:UANamedUserIdentifierChangedNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserIdentifierChangedNotificationIdentifierKey : @"kindaFakeNamedUser"}];

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
    XCTAssertNoThrow([self.mockNotificationCenter verify], @"Change notification should be posted");
}

/**
 * Test when IDs match, don't update named user
 */
- (void)testIDsMatchNoUpdate {
    // Named user client should not associate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    [[self.mockNotificationCenter reject] postNotificationName:UANamedUserIdentifierChangedNotification
                                                        object:OCMOCK_ANY
                                                      userInfo:OCMOCK_ANY];

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
    XCTAssertNoThrow([self.mockNotificationCenter verify], @"Change notification should not be posted");
}

- (void)testSetIdentifierDataCollectionDisabled {
    self.namedUser.identifier = nil;
    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];
    self.namedUser.identifier = @"neat";
    XCTAssertNil(self.namedUser.identifier);
}

- (void)testInitialIdentifierPassedToRegistrars {
    [self.dataStore setValue:@"foo" forKey:UANamedUserIDKey];
    [[self.mockTagGroupsRegistrar expect] setIdentifier:@"foo" clearPendingOnChange:NO];
    [[self.mockAttributeRegistrar expect] setIdentifier:@"foo" clearPendingOnChange:NO];

    self.namedUser = [UANamedUser namedUserWithChannel:self.mockChannel
                                                config:self.config
                                    notificationCenter:self.mockNotificationCenter
                                             dataStore:self.dataStore
                                    tagGroupsRegistrar:self.mockTagGroupsRegistrar
                                    attributeRegistrar:self.mockAttributeRegistrar
                                                  date:self.testDate
                                           taskManager:self.mockTaskManager];


    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
}

- (void)testSetIdentifierPassedToRegistrar {
    [[self.mockTagGroupsRegistrar expect] setIdentifier:@"bar" clearPendingOnChange:YES];
    [[self.mockAttributeRegistrar expect] setIdentifier:@"bar" clearPendingOnChange:YES];

    self.namedUser.identifier = @"bar";

    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
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
                                 completionHandler:OCMOCK_ANY];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                    completionHandler:OCMOCK_ANY];

    [self.namedUser update];

    XCTAssertNoThrow([self.mockedNamedUserClient verify],
                     @"Named user client should not associate or disassociate.");
}

/**
 * Test update will skip update when named user already updated.
 */
- (void)testUpdateSkipUpdateSameNamedUser {
    // Named user client should not associate
    [[self.mockedNamedUserClient expect] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                 completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(NSError * _Nullable) = obj;
        completionBlock(nil);
        return YES;
    }]];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyReplace requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    [self.namedUser update];

    [self.mockTaskManager verify];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
                                         channelID:OCMOCK_ANY
                                 completionHandler:OCMOCK_ANY];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                    completionHandler:OCMOCK_ANY];

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
                                 completionHandler:OCMOCK_ANY];

    // Named user client should not disassociate
    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
                                    completionHandler:OCMOCK_ANY];

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
    [[[self.mockedNamedUserClient expect] andDo:disassociateSuccessDoBlock] disassociate:@"someChannel"
                                    completionHandler:OCMOCK_ANY];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyReplace requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

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
                                    completionHandler:OCMOCK_ANY];

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
    [[[self.mockedNamedUserClient expect] andDo:associateSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                 completionHandler:OCMOCK_ANY];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyReplace requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    [self.namedUser forceUpdate];

    [self.mockTaskManager verify];

    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change token should have changed.");
    XCTAssertEqualObjects(self.namedUser.changeToken, self.namedUser.lastUpdatedToken,
                          @"Tokens should match.");
    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be associated");
}

- (void)testChannelCreated {
    NSString *changeToken = self.namedUser.changeToken;

    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:associateSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                 completionHandler:OCMOCK_ANY];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyReplace requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    // Send a channel created event
    [self.mockNotificationCenter postNotificationName:UAChannelCreatedEvent
                                               object:nil
                                             userInfo:@{UAChannelCreatedEventChannelKey:@"newChannel", UAChannelCreatedEventExistingKey: @(NO)}];

    [self.mockTaskManager verify];

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
    [[[self.mockedNamedUserClient expect] andDo:associateSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                 completionHandler:OCMOCK_ANY];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyReplace requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    [self.namedUser forceUpdate];

    [self.mockTaskManager verify];

    // Change the channelID
    self.pushChannelID = @"neat";

    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:associateSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"neat"
                                                                 completionHandler:OCMOCK_ANY];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    [self.namedUser update];

    XCTAssertNoThrow([self.mockedNamedUserClient verify], @"Named user should be associated");
}

/**
 * Test that the tag groups registrar is called when UANamedUser is asked to update tags
 */
- (void)testUpdateTags {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UANamedUserTagUpdateTaskID] taskID];
    [[mockTask expect] taskFailed];

    [[[self.mockTagGroupsRegistrar expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(NO);
    }] updateTagGroupsWithCompletionHandler:OCMOCK_ANY];

    [[self.mockTaskManager reject] enqueueRequestWithID:UANamedUserTagUpdateTaskID options:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockTagGroupsRegistrar verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}

/**
 * Test that the tag groups registrar is called again if the value passed with the completion handler is YES
 */
- (void)testUpdateTagsContinuesIfNeeded {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UANamedUserTagUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    [[[self.mockTagGroupsRegistrar expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] updateTagGroupsWithCompletionHandler:OCMOCK_ANY];

    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserTagUpdateTaskID options:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockTagGroupsRegistrar verify];
    [self.mockTaskManager verify];
    [mockTask verify];
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

- (void)testClearNamedUserOnDataCollectionDisabled {
    self.namedUser.identifier = @"neat";
    XCTAssertNotNil(self.namedUser.identifier);

    // Expect the named user client to disassociate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:disassociateSuccessDoBlock] disassociate:@"someChannel"
                                                                       completionHandler:OCMOCK_ANY];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];
    [self.namedUser onDataCollectionEnabledChanged];

    XCTAssertNil(self.namedUser.identifier);

    [self.mockedNamedUserClient verify];
    [self.mockTaskManager verify];
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
    [[[self.mockedNamedUserClient expect] andDo:disassociateSuccessDoBlock] disassociate:@"someChannel"
                                                                       completionHandler:OCMOCK_ANY];

    // expect pending mutations to be deleted
    [[self.mockAttributeRegistrar expect] clearPendingMutations];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];
    [self.namedUser onDataCollectionEnabledChanged];

    [self.mockedNamedUserClient verify];
    [self.mockAttributeRegistrar verify];
    [self.mockTaskManager verify];
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

    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserAttributeUpdateTaskID options:OCMOCK_ANY];
    [self.namedUser applyAttributeMutations:addMutation];

    [self.mockAttributeRegistrar verify];
    [self.mockTaskManager verify];
}

/**
 * Tests adding a named user attribute results in a no-op.
 */
- (void)testAddNamedUserAttributeNoNamedUser {
    [[self.mockAttributeRegistrar reject] savePendingMutations:OCMOCK_ANY];

    self.namedUser.identifier = nil;

    UAAttributeMutations *addMutation = [UAAttributeMutations mutations];
    [addMutation setString:@"string" forAttribute:@"attribute"];
    [self.namedUser applyAttributeMutations:addMutation];

    [self.mockAttributeRegistrar verify];
}

/**
 * Test updateNamedUserAttributes method if data collection is disabled.
 */
- (void)testUpdateNamedUserAttributesIfDataDisabled {
    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UANamedUserAttributeUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    [[self.mockAttributeRegistrar reject] updateAttributesWithCompletionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockAttributeRegistrar verify];
    [mockTask verify];
}

/**
 * Test updateNamedUserAttributes method if the identifier is set.
 */
- (void)testUpdateNamedUserAttributes {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UANamedUserAttributeUpdateTaskID] taskID];
    [[mockTask expect] taskFailed];

    [[[self.mockAttributeRegistrar expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(NO);
    }] updateAttributesWithCompletionHandler:OCMOCK_ANY];

    [[self.mockTaskManager reject] enqueueRequestWithID:UANamedUserAttributeUpdateTaskID options:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockAttributeRegistrar verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}

/**
 * Test that the attribute registrar is called again if the value passed with the completion handler is YES
 */
- (void)testUpdateAttributesContinuesIfNeeded {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UANamedUserAttributeUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    [[[self.mockAttributeRegistrar expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] updateAttributesWithCompletionHandler:OCMOCK_ANY];

    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserAttributeUpdateTaskID options:OCMOCK_ANY];

    self.launchHandler(mockTask);

    [self.mockTagGroupsRegistrar verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}

- (void)testSetDataCollectionEnabledYES {
    NSString *changeToken = self.namedUser.changeToken;
    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];
    [self.namedUser onDataCollectionEnabledChanged];

    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change token should have changed.");

    [self.mockTaskManager verify];
}

- (void)testSetDataCollectionEnabledYESComponentDisabled {
    NSString *changeToken = self.namedUser.changeToken;

    self.namedUser.componentEnabled = NO;
    [self.dataStore setBool:NO forKey:UAirshipDataCollectionEnabledKey];

    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:associateSuccessDoBlock] associate:@"fakeNamedUser"
                                                                         channelID:@"someChannel"
                                                                 completionHandler:OCMOCK_ANY];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];
    [self.namedUser onDataCollectionEnabledChanged];

    XCTAssertNotEqualObjects(changeToken, self.namedUser.changeToken,
                             @"Change token should have changed.");
    XCTAssertEqualObjects(self.namedUser.changeToken, self.namedUser.lastUpdatedToken,
                          @"Tokens should match.");

    [self.mockTagGroupsRegistrar verify];
    [self.mockAttributeRegistrar verify];
    [self.mockedNamedUserClient verify];
    [self.mockTaskManager verify];
}

- (void)testSetDataCollectionEnabledNO {
    NSString *changeToken = self.namedUser.changeToken;

    [self.dataStore setBool:YES forKey:UAirshipDataCollectionEnabledKey];

    [[self.mockAttributeRegistrar expect] clearPendingMutations];
    [[self.mockTagGroupsRegistrar expect] clearPendingMutations];

    // Expect the named user client to associate and call the success block
    [[[self.mockedNamedUserClient expect] andDo:disassociateSuccessDoBlock] disassociate:@"someChannel"
                                                                       completionHandler:OCMOCK_ANY];

    UATaskRequestOptions *options = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend requiresNetwork:YES extras:nil];
    id mockTask = [self mockForProtocol:@protocol(UATask)];

    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];

    [[[self.mockTaskManager expect] andDo:^(NSInvocation *invocation) {
        self.launchHandler(mockTask);
    }] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];

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
    [self.mockTaskManager verify];
}

@end
