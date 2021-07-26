///* Copyright Airship and Contributors */
//
//#import "UAAirshipBaseTest.h"
//#import "UAirship+Internal.h"
//#import "UANamedUser+Internal.h"
//#import "UAChannel+Internal.h"
//#import "UARuntimeConfig.h"
//#import "UATagGroupsRegistrar+Internal.h"
//#import "UAAttributePendingMutations.h"
//#import "AirshipTests-Swift.h"
//
//@import AirshipCore;
//
//static NSString * const UANamedUserUpdateTaskID = @"UANamedUser.update";
//static NSString * const UANamedUserTagUpdateTaskID = @"UANamedUser.tags.update";
//static NSString * const UANamedUserAttributeUpdateTaskID = @"UANamedUser.attributes.update";
//
//@interface UANamedUserTest : UAAirshipBaseTest
//
//@property (nonatomic, strong) id mockedAirship;
//@property (nonatomic, strong) id mockedNamedUserClient;
//@property (nonatomic, strong) id mockChannel;
//@property (nonatomic, strong) id mockTagGroupsRegistrar;
//@property (nonatomic, strong) id mockAttributeRegistrar;
//@property (nonatomic, strong) id mockTimeZone;
//@property (nonatomic, strong) id mockNotificationCenter;
//@property (nonatomic, strong) id mockTaskManager;
//@property (nonatomic, strong) UAPrivacyManager *privacyManager;
//@property (nonatomic, strong) UATestDate *testDate;
//@property (nonatomic, strong) UANamedUser *namedUser;
//@property (nonatomic, copy) NSString *channelID;
//@property (nonatomic, copy) UAChannelRegistrationExtenderBlock channelRegistrationExtenderBlock;
//@property (nonatomic, copy) void (^launchHandler)(id<UATask>);
//@end
//
//@implementation UANamedUserTest
//
//- (void)setUp {
//    [super setUp];
//
//
//    self.mockChannel = [self mockForClass:[UAChannel class]];
//    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
//        [invocation setReturnValue:&self->_channelID];
//    }] identifier];
//
//    self.mockedAirship = [self mockForClass:[UAirship class]];
//    [[[self.mockedAirship stub] andReturn:self.mockChannel] channel];
//    [UAirship setSharedAirship:self.mockedAirship];
//
//    self.channelID = @"someChannel";
//
//    self.mockTagGroupsRegistrar = [self mockForClass:[UATagGroupsRegistrar class]];
//    self.mockAttributeRegistrar = [self mockForClass:[UAAttributeRegistrar class]];
//
//    self.mockTimeZone = [self mockForClass:[NSTimeZone class]];
//    [[[self.mockTimeZone stub] andReturn:self.mockTimeZone] defaultTimeZone];
//
//    self.mockNotificationCenter = [self partialMockForObject:[NSNotificationCenter defaultCenter]];
//
//    self.testDate = [[UATestDate alloc] initWithOffset:0 dateOverride:[NSDate date]];
//
//    self.mockedNamedUserClient = [self mockForClass:[UANamedUserAPIClient class]];
//
//    // Capture the channel payload extender
//    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:2];
//        self.channelRegistrationExtenderBlock =  (__bridge UAChannelRegistrationExtenderBlock)arg;
//    }] addChannelExtenderBlock:OCMOCK_ANY];
//
//    self.mockTaskManager = [self mockForClass:[UATaskManager class]];
//
//    // Capture the task launcher
//    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:4];
//        self.launchHandler =  (__bridge void (^)(id<UATask>))arg;
//    }] registerForTaskWithIDs:@[UANamedUserUpdateTaskID, UANamedUserTagUpdateTaskID, UANamedUserAttributeUpdateTaskID] dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];
//
//
//    self.privacyManager = [[UAPrivacyManager alloc] initWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];
//    self.namedUser = [UANamedUser namedUserWithChannel:self.mockChannel
//                                                config:self.config
//                                    notificationCenter:self.mockNotificationCenter
//                                             dataStore:self.dataStore
//                                    tagGroupsRegistrar:self.mockTagGroupsRegistrar
//                                    attributeRegistrar:self.mockAttributeRegistrar
//                                                  date:self.testDate
//                                           taskManager:self.mockTaskManager
//                                       namedUserClient:self.mockedNamedUserClient
//                                        privacyManager:self.privacyManager];
//}
//
//- (void)tearDown {
//    [self.mockTimeZone stopMocking];
//    [self.mockNotificationCenter removeObserver:self.namedUser];
//    [self.mockNotificationCenter stopMocking];
//    [super tearDown];
//}
//
///**
// * Test set valid ID (associate).
// */
//- (void)testSetIDValid {
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];
//
//    self.namedUser.identifier = @"superFakeNamedUser";
//    [self.mockTaskManager verify];
//}
//
///**
// * Test set invalid ID.
// */
//- (void)testSetIDInvalid {
//    self.namedUser.identifier = @"fakeNamedUser";
//    [[self.mockTaskManager reject] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];
//
//    self.namedUser.identifier = @"         ";
//
//    XCTAssertEqualObjects(@"fakeNamedUser", self.namedUser.identifier);
//    [self.mockTaskManager verify];
//}
//
///**
// * Test set empty ID (disassociate).
// */
//- (void)testSetIDEmpty {
//    self.namedUser.identifier = @"fakeNamedUser";
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];
//
//    self.namedUser.identifier = @"";
//
//    XCTAssertNil(self.namedUser.identifier);
//    [self.mockTaskManager verify];
//}
//
///**
// * Test set nil ID (disassociate).
// */
//- (void)testSetIDNil {
//    self.namedUser.identifier = @"fakeNamedUser";
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];
//
//    self.namedUser.identifier = nil;
//
//    XCTAssertNil(self.namedUser.identifier);
//    [self.mockTaskManager verify];
//}
//
///**
// * Test when IDs match, don't update enqueu task.
// */
//- (void)testIDsMatchNoUpdate {
//    self.namedUser.identifier = @"fakeNamedUser";
//
//    [[self.mockTaskManager reject] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];
//
//    self.namedUser.identifier = @"fakeNamedUser";
//
//    XCTAssertEqualObjects(@"fakeNamedUser", self.namedUser.identifier);
//    [self.mockTaskManager verify];
//}
//
//- (void)testSetIdentifierDataCollectionDisabled {
//    self.namedUser.identifier = nil;
//    [self.privacyManager disableFeatures:UAFeaturesContacts];
//    self.namedUser.identifier = @"neat";
//    XCTAssertNil(self.namedUser.identifier);
//}
//
//- (void)testInitialIdentifierPassedToRegistrars {
//    self.namedUser.identifier = @"foo";
//
//    [[self.mockTagGroupsRegistrar expect] setIdentifier:@"foo" clearPendingOnChange:NO];
//    [[self.mockAttributeRegistrar expect] setIdentifier:@"foo" clearPendingOnChange:NO];
//
//    // Recreate the named user
//    self.namedUser = [UANamedUser namedUserWithChannel:self.mockChannel
//                                                config:self.config
//                                    notificationCenter:self.mockNotificationCenter
//                                             dataStore:self.dataStore
//                                    tagGroupsRegistrar:self.mockTagGroupsRegistrar
//                                    attributeRegistrar:self.mockAttributeRegistrar
//                                                  date:self.testDate
//                                           taskManager:self.mockTaskManager
//                                       namedUserClient:self.mockedNamedUserClient
//                                        privacyManager:self.privacyManager];
//
//
//    [self.mockTagGroupsRegistrar verify];
//    [self.mockAttributeRegistrar verify];
//}
//
//- (void)testSetIdentifierPassedToRegistrar {
//    [[self.mockTagGroupsRegistrar expect] setIdentifier:@"bar" clearPendingOnChange:YES];
//    [[self.mockAttributeRegistrar expect] setIdentifier:@"bar" clearPendingOnChange:YES];
//
//    self.namedUser.identifier = @"bar";
//
//    [self.mockTagGroupsRegistrar verify];
//    [self.mockAttributeRegistrar verify];
//}
//
///**
// * Test update will skip update on a new or re-install.
// */
//- (void)testUpdateSkipUpdateOnNewInstall {
//    // Named user client should not associate
//    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
//                                         channelID:OCMOCK_ANY
//                                 completionHandler:OCMOCK_ANY];
//
//    // Named user client should not disassociate
//    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
//                                    completionHandler:OCMOCK_ANY];
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
///**
// * Test update will skip update when named user already updated.
// */
//- (void)testUpdateSkipUpdateSameNamedUser {
//    [self updateNamedUser:@"some-ID"];
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    // Named user client should not disassociate
//    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
//                                         channelID:OCMOCK_ANY
//                                 completionHandler:OCMOCK_ANY];
//
//    // Named user client should not disassociate
//    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
//                                    completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//    [self.mockedNamedUserClient verify];
//}
//
///**
// * Test update will skip update when channel ID doesn't exist.
// */
//- (void)testUpdateSkipUpdateNoChannel {
//    self.channelID = nil;
//
//    // Named user client should not associate
//    [[self.mockedNamedUserClient reject] associate:OCMOCK_ANY
//                                         channelID:OCMOCK_ANY
//                                 completionHandler:OCMOCK_ANY];
//
//    // Named user client should not disassociate
//    [[self.mockedNamedUserClient reject] disassociate:OCMOCK_ANY
//                                    completionHandler:OCMOCK_ANY];
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    self.launchHandler(mockTask);
//    [self.mockedNamedUserClient verify];
//}
//
//- (void)testAssociate {
//    self.namedUser.identifier = @"named-user";
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:4];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:200], nil);
//    }] associate:@"named-user" channelID:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testAssociate429 {
//    self.namedUser.identifier = @"named-user";
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskFailed];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:4];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:429], nil);
//    }] associate:@"named-user" channelID:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testAssociateClientError {
//    self.namedUser.identifier = @"named-user";
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:4];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:400], nil);
//    }] associate:@"named-user" channelID:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testAssociateServerError {
//    self.namedUser.identifier = @"named-user";
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskFailed];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:4];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:500], nil);
//    }] associate:@"named-user" channelID:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testAssociateError {
//    self.namedUser.identifier = @"named-user";
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskFailed];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:4];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        NSError *error = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];
//        completionHandler(nil, error);
//    }] associate:@"named-user" channelID:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testDisassociate {
//    self.namedUser.identifier = nil;
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:3];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:200], nil);
//    }] disassociate:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testDisassociate429 {
//    self.namedUser.identifier = nil;
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskFailed];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:3];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:429], nil);
//    }] disassociate:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testDisassociateClientError {
//    self.namedUser.identifier = nil;
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:3];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:400], nil);
//    }] disassociate:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testDisassociateServerError {
//    self.namedUser.identifier = nil;
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskFailed];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:3];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:500], nil);
//    }] disassociate:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testDisassociateError {
//    self.namedUser.identifier = nil;
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskFailed];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:3];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        NSError *error = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];
//        completionHandler(nil, error);
//    }] disassociate:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
///**
// * Test force update changes the current token and updates named user.
// */
//- (void)testForceUpdate {
//    [self updateNamedUser:@"some-identifier"];
//
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];
//
//    // Force update should make the task call the client
//    [self.namedUser forceUpdate];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:4];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:200], nil);
//    }] associate:@"some-identifier" channelID:self.channelID completionHandler:OCMOCK_ANY];
//
//    // Actually run the task
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testChannelCreated {
//    self.namedUser.identifier = @"neat";
//    
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];
//
//    // Send a channel created event
//    [self.mockNotificationCenter postNotificationName:UAChannelCreatedEvent
//                                               object:nil
//                                             userInfo:@{UAChannelCreatedEventChannelKey:@"newChannel", UAChannelCreatedEventExistingKey: @(NO)}];
//
//    [self.mockTaskManager verify];
//}
//
//- (void)testConfigUpdataed {
//    [self updateNamedUser:@"some-identifier"];
//
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];
//
//    [self.mockNotificationCenter postNotificationName:UARemoteConfigURLManagerConfigUpdated
//                                               object:nil];
//
//    [self.mockTaskManager verify];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:4];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:200], nil);
//    }] associate:@"some-identifier" channelID:self.channelID completionHandler:OCMOCK_ANY];
//
//    // Actually run the task
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
///**
// * Test update will reassociate named user if the channel ID changes.
// */
//- (void)testUpdateChannelIDChanged {
//    [self updateNamedUser:@"some-identifier"];
//
//    self.channelID = @"neat";
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:4];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:200], nil);
//    }] associate:@"some-identifier" channelID:self.channelID completionHandler:OCMOCK_ANY];
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//- (void)testUpdateTagGroups {
//    self.namedUser.identifier = @"name-user";
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserTagUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    [[[self.mockTagGroupsRegistrar expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:2];
//        void (^completionHandler)(UATagGroupsUploadResult) = (__bridge void (^)(UATagGroupsUploadResult))arg;
//        completionHandler(UATagGroupsUploadResultFinished);
//    }] updateTagGroupsWithCompletionHandler:OCMOCK_ANY];
//
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserTagUpdateTaskID options:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockTagGroupsRegistrar verify];
//    [self.mockTaskManager verify];
//    [mockTask verify];
//}
//
//- (void)testUpdateTagsFailed {
//    self.namedUser.identifier = @"name-user";
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserTagUpdateTaskID] taskID];
//    [mockTask taskFailed];
//
//    [[[self.mockTagGroupsRegistrar expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:2];
//        void (^completionHandler)(UATagGroupsUploadResult) = (__bridge void (^)(UATagGroupsUploadResult))arg;
//        completionHandler(UATagGroupsUploadResultFailed);
//    }] updateTagGroupsWithCompletionHandler:OCMOCK_ANY];
//
//    [[self.mockTaskManager reject] enqueueRequestWithID:UANamedUserTagUpdateTaskID options:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockTagGroupsRegistrar verify];
//    [self.mockTaskManager verify];
//    [mockTask verify];
//}
//
//- (void)testUpdateTagsUpToDate {
//    self.namedUser.identifier = @"name-user";
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserTagUpdateTaskID] taskID];
//    [mockTask taskFailed];
//
//    [[[self.mockTagGroupsRegistrar expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:2];
//        void (^completionHandler)(UATagGroupsUploadResult) = (__bridge void (^)(UATagGroupsUploadResult))arg;
//        completionHandler(UATagGroupsUploadResultUpToDate);
//    }] updateTagGroupsWithCompletionHandler:OCMOCK_ANY];
//
//    [[self.mockTaskManager reject] enqueueRequestWithID:UANamedUserTagUpdateTaskID options:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockTagGroupsRegistrar verify];
//    [self.mockTaskManager verify];
//    [mockTask verify];
//}
//
///**
// * Test that the tag groups registrar is called when UANamedUser is asked to add tags
// */
//- (void)testAddTags {
//    self.namedUser.identifier = @"named user";
//
//    NSArray *tags = @[@"foo", @"bar"];
//    NSString *group = @"group";
//
//    // EXPECTATIONS
//    [[self.mockTagGroupsRegistrar expect] addTags:tags group:group];
//
//    // TEST
//    [self.namedUser addTags:tags group:group];;
//
//    // VERIFY
//    [self.mockTagGroupsRegistrar verify];
//}
//
///**
// * Test that the tag groups registrar is not called when UANamedUser is asked to add device tags and data collection is disabled.
// */
//- (void)testAddDeviceTagsDataCollectionDisabled {
//    self.namedUser.identifier = @"me";
//    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];
//
//    NSArray *tags = @[@"foo", @"bar"];
//    NSString *group = @"group";
//
//    // EXPECTATIONS
//    [[self.mockTagGroupsRegistrar reject] addTags:tags group:group];
//
//    // TEST
//    [self.namedUser addTags:tags group:group];;
//
//    // VERIFY
//    [self.mockTagGroupsRegistrar verify];
//}
//
///**
// * Test that the tag groups registrar is called when UANamedUser is asked to add device tags when data collection is enabled.
// */
//- (void)testAddDeviceTagsDataCollectionEnabled {
//    self.namedUser.identifier = @"me";
//
//    NSArray *tags = @[@"foo", @"bar"];
//    NSString *group = @"group";
//
//    // EXPECTATIONS
//    [[self.mockTagGroupsRegistrar expect] addTags:tags group:group];
//
//    // TEST
//    [self.namedUser addTags:tags group:group];;
//
//    // VERIFY
//    [self.mockTagGroupsRegistrar verify];
//}
//
///**
// * Test that the tag groups registrar is called when UANamedUser is asked to remove tags
// */
//- (void)testRemoveTags {
//    self.namedUser.identifier = @"me";
//    NSArray *tags = @[@"foo", @"bar"];
//    NSString *group = @"group";
//
//    // EXPECTATIONS
//    [[self.mockTagGroupsRegistrar expect] removeTags:tags group:group];
//
//    // TEST
//    [self.namedUser removeTags:tags group:group];;
//
//    // VERIFY
//    [self.mockTagGroupsRegistrar verify];
//}
//
///**
// * Test that the tag groups registrar is not called when UANamedUser is asked to remove device tags and data collection is disabled.
// */
//- (void)testRemoveDeviceTagsDataCollectionDisabled {
//    self.namedUser.identifier = @"me";
//    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];
//
//    NSArray *tags = @[@"foo", @"bar"];
//    NSString *group = @"group";
//
//    // EXPECTATIONS
//    [[self.mockTagGroupsRegistrar reject] removeTags:tags group:group];
//
//    // TEST
//    [self.namedUser removeTags:tags group:group];;
//
//    // VERIFY
//    [self.mockTagGroupsRegistrar verify];
//}
//
///**
// * Test that the tag groups registrar is called when UANamedUser is asked to remove device tags when data collection is enabled.
// */
//- (void)testRemoveDeviceTagsDataCollectionEnabled {
//    self.namedUser.identifier = @"me";
//
//    NSArray *tags = @[@"foo", @"bar"];
//    NSString *group = @"group";
//
//    // EXPECTATIONS
//    [[self.mockTagGroupsRegistrar expect] removeTags:tags group:group];
//
//    // TEST
//    [self.namedUser removeTags:tags group:group];;
//
//    // VERIFY
//    [self.mockTagGroupsRegistrar verify];
//}
//
///**
// * Test that the tag groups registrar is called when UANamedUser is asked to set tags
// */
//- (void)testSetTags {
//    self.namedUser.identifier = @"me";
//
//    NSArray *tags = @[@"foo", @"bar"];
//    NSString *group = @"group";
//
//    // EXPECTATIONS
//    [[self.mockTagGroupsRegistrar expect] setTags:tags group:group];
//
//    // TEST
//    [self.namedUser setTags:tags group:group];;
//
//    // VERIFY
//    [self.mockTagGroupsRegistrar verify];
//}
//
///**
// * Test that the tag groups registrar is not called when UANamedUser is asked to set device tags and data collection is disabled.
// */
//- (void)testSetDeviceTagsDataCollectionDisabled {
//    self.namedUser.identifier = @"me";
//    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];
//
//    NSArray *tags = @[@"foo", @"bar"];
//    NSString *group = @"group";
//
//    // EXPECTATIONS
//    [[self.mockTagGroupsRegistrar reject] setTags:tags group:group];
//
//    // TEST
//    [self.namedUser setTags:tags group:group];;
//
//    // VERIFY
//    [self.mockTagGroupsRegistrar verify];
//}
//
///**
// * Test that the tag groups registrar is called when UANamedUser is asked to set device tags when data collection is enabled.
// */
//- (void)testSetDeviceTagsDataCollectionEnabled {
//    self.namedUser.identifier = @"me";
//
//    NSArray *tags = @[@"foo", @"bar"];
//    NSString *group = @"group";
//
//    // EXPECTATIONS
//    [[self.mockTagGroupsRegistrar expect] setTags:tags group:group];
//
//    // TEST
//    [self.namedUser setTags:tags group:group];
//
//    // VERIFY
//    [self.mockTagGroupsRegistrar verify];
//}
//
//- (void)testClearNamedUserOnDataCollectionDisabled {
//    self.namedUser.identifier = @"neat";
//    XCTAssertNotNil(self.namedUser.identifier);
//
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];
//
//    [self.privacyManager disableFeatures:UAFeaturesContacts];
//
//    XCTAssertNil(self.namedUser.identifier);
//
//    [self.mockTaskManager verify];
//}
//
///**
// * Test registration payload extender.
// */
//- (void)testRegistrationPayloadExtender {
//    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
//    XCTestExpectation *extendedPayload = [self expectationWithDescription:@"extended payload"];
//    self.channelRegistrationExtenderBlock(payload, ^(UAChannelRegistrationPayload * _Nonnull payload) {
//        XCTAssertEqualObjects(self.namedUser.identifier, payload.namedUserId);
//        [extendedPayload fulfill];
//    });
//
//    [self waitForTestExpectations];
//}
//
///**
// * Test changing named user id updates channel registration .
// */
//- (void)testChangingIdUpdatesChannelRegistration {
//
//    [[self.mockChannel expect] updateRegistration];
//
//    self.namedUser.identifier = @"a_different_named_user";
//
//    [self.mockChannel verify];
//}
//
//- (void)testClearNamedUserAttributesOnDataCollectionDisabled {
//    // expect pending mutations to be deleted
//    [[self.mockAttributeRegistrar expect] clearPendingMutations];
//
//    [self.privacyManager disableFeatures:UAFeaturesTagsAndAttributes];
//
//    [self.mockAttributeRegistrar verify];
//}
//
///**
// * Tests adding a named user attribute results in save and update called when a named user is present.
// */
//- (void)testAddNamedUserAttribute {
//    self.namedUser.identifier = @"some-named-user";
//
//    [self.mockTimeZone stopMocking];
//
//    UAAttributeMutations *addMutation = [UAAttributeMutations mutations];
//    [addMutation setString:@"string" forAttribute:@"attribute"];
//
//    UAAttributePendingMutations *expectedPendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:addMutation date:self.testDate];
//
//    [[self.mockAttributeRegistrar expect] savePendingMutations:[OCMArg checkWithBlock:^BOOL(id obj) {
//        UAAttributePendingMutations *pendingMutations = (UAAttributePendingMutations *)obj;
//        return [pendingMutations.payload isEqualToDictionary:expectedPendingMutations.payload];
//    }]];
//
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserAttributeUpdateTaskID options:OCMOCK_ANY];
//    [self.namedUser applyAttributeMutations:addMutation];
//
//    [self.mockAttributeRegistrar verify];
//    [self.mockTaskManager verify];
//}
//
///**
// * Tests adding a named user attribute results in a no-op.
// */
//- (void)testAddNamedUserAttributeNoNamedUser {
//    [[self.mockAttributeRegistrar reject] savePendingMutations:OCMOCK_ANY];
//
//    self.namedUser.identifier = nil;
//
//    UAAttributeMutations *addMutation = [UAAttributeMutations mutations];
//    [addMutation setString:@"string" forAttribute:@"attribute"];
//    [self.namedUser applyAttributeMutations:addMutation];
//
//    [self.mockAttributeRegistrar verify];
//}
//
///**
// * Test updateNamedUserAttributes method if data collection is disabled.
// */
//- (void)testUpdateNamedUserAttributesIfDataDisabled {
//    [self.privacyManager disableFeatures:UAFeaturesContacts];
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserAttributeUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    [[self.mockAttributeRegistrar reject] updateAttributesWithCompletionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockAttributeRegistrar verify];
//    [mockTask verify];
//}
//
//- (void)testUpdateAttributes {
//    self.namedUser.identifier = @"named user";
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserAttributeUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    [[[self.mockAttributeRegistrar expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:2];
//        void (^completionHandler)(UAAttributeUploadResult) = (__bridge void (^)(UAAttributeUploadResult))arg;
//        completionHandler(UAAttributeUploadResultFinished);
//    }] updateAttributesWithCompletionHandler:OCMOCK_ANY];
//
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserAttributeUpdateTaskID options:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockAttributeRegistrar verify];
//    [self.mockTaskManager verify];
//    [mockTask verify];
//}
//
//- (void)testUpdateAttributesFailed {
//    self.namedUser.identifier = @"named user";
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserAttributeUpdateTaskID] taskID];
//    [[mockTask expect] taskFailed];
//
//    [[[self.mockAttributeRegistrar expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:2];
//        void (^completionHandler)(UAAttributeUploadResult) = (__bridge void (^)(UAAttributeUploadResult))arg;
//        completionHandler(UAAttributeUploadResultFailed);
//    }] updateAttributesWithCompletionHandler:OCMOCK_ANY];
//
//    [[self.mockTaskManager reject] enqueueRequestWithID:UANamedUserAttributeUpdateTaskID options:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockAttributeRegistrar verify];
//    [self.mockTaskManager verify];
//    [mockTask verify];
//}
//
//- (void)testUpdateAttributesUpToDate {
//    self.namedUser.identifier = @"named user";
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserAttributeUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    [[[self.mockAttributeRegistrar expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:2];
//        void (^completionHandler)(UAAttributeUploadResult) = (__bridge void (^)(UAAttributeUploadResult))arg;
//        completionHandler(UAAttributeUploadResultUpToDate);
//    }] updateAttributesWithCompletionHandler:OCMOCK_ANY];
//
//    [[self.mockTaskManager reject] enqueueRequestWithID:UANamedUserAttributeUpdateTaskID options:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockAttributeRegistrar verify];
//    [self.mockTaskManager verify];
//    [mockTask verify];
//}
//
//
//- (void)testSetDataCollectionEnabledNO {
//    self.namedUser.identifier = @"neat";
//
//    [self.privacyManager disableFeatures:UAFeaturesContacts];
//    
//    [[self.mockTaskManager expect] enqueueRequestWithID:UANamedUserUpdateTaskID options:OCMOCK_ANY];
//    XCTAssertNil(self.namedUser.identifier);
//}
//
//- (void)updateNamedUser:(NSString *)namedUserID {
//    self.namedUser.identifier = namedUserID;
//
//    id mockTask = [self mockForProtocol:@protocol(UATask)];
//    [[[mockTask stub] andReturn:UANamedUserUpdateTaskID] taskID];
//    [[mockTask expect] taskCompleted];
//
//    [[[self.mockedNamedUserClient expect] andDo:^(NSInvocation *invocation) {
//        void *arg;
//        [invocation getArgument:&arg atIndex:4];
//        void (^completionHandler)(UAHTTPResponse * _Nullable, NSError * _Nullable);
//        completionHandler = (__bridge void (^)(UAHTTPResponse * _Nullable , NSError * _Nullable))arg;
//        completionHandler([[UAHTTPResponse alloc] initWithStatus:200], nil);
//    }] associate:namedUserID channelID:self.channelID completionHandler:OCMOCK_ANY];
//
//    self.launchHandler(mockTask);
//
//    [self.mockedNamedUserClient verify];
//    [mockTask verify];
//}
//
//@end
