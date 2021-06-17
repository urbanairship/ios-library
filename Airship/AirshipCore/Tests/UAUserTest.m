/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAUser+Internal.h"
#import "UAUserAPIClient+Internal.h"
#import "UAUserData+Internal.h"
#import "UAKeychainUtils.h"
#import "UAirship+Internal.h"
#import "UARuntimeConfig.h"
#import "UATestDispatcher.h"
#import "UARuntimeConfig+Internal.h"
#import "UAChannel+Internal.h"
#import "UAAppStateTracker.h"
#import "NSError+UAAdditions.h"
@import AirshipCore;

@interface UATestUserDataDAO : UAUserDataDAO
@property (nonatomic, strong) UAUserData *userData;
@end

static NSString * const UAUserUpdateTaskID = @"UAUser.update";

@interface UAUserTest : UAAirshipBaseTest
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockUserClient;
@property (nonatomic, strong) id mockTaskManager;
@property (nonatomic, strong) UAUserData *userData;
@property (nonatomic, strong) UAUserDataDAO *userDataDAO;
@property (nonatomic, copy) NSString *channelID;
@property (nonatomic, copy) UAChannelRegistrationExtenderBlock extenderBlock;
@property(nonatomic, copy) void (^launchHandler)(id<UATask>);
@end

@implementation UAUserTest

- (void)setUp {
    [super setUp];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        NSString *channelID = self.channelID;
        [invocation setReturnValue:(void *)&channelID];
    }] identifier];

    // Capture the channel payload extender
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
          void *arg;
          [invocation getArgument:&arg atIndex:2];
          self.extenderBlock =  (__bridge UAChannelRegistrationExtenderBlock)arg;
    }] addChannelExtenderBlock:OCMOCK_ANY];

    self.mockUserClient = [self mockForClass:[UAUserAPIClient class]];
    self.mockTaskManager = [self mockForClass:[UATaskManager class]];

    // Capture the task launcher
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        self.launchHandler =  (__bridge void (^)(id<UATask>))arg;
    }] registerForTaskWithIDs:@[UAUserUpdateTaskID] dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];


    self.notificationCenter = [[NSNotificationCenter alloc] init];
    self.userDataDAO = [[UATestUserDataDAO alloc] init];

    self.user = [UAUser userWithChannel:self.mockChannel
                              dataStore:self.dataStore
                                 client:self.mockUserClient
                     notificationCenter:self.notificationCenter
                            userDataDAO:self.userDataDAO
                            taskManager:self.mockTaskManager];

    self.userData = [UAUserData dataWithUsername:@"userName" password:@"password"];
 }

- (void)testDefaultUser {
    XCTestExpectation *expectation = [self expectationWithDescription:@"got user data"];

    [self.user getUserData:^(UAUserData *data) {
        XCTAssertNotNil(self.user, @"we should at least have a user");
        XCTAssertNil(data.username, @"user name should be nil");
        XCTAssertNil(data.password, @"password should be nil");
        [expectation fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testUpdateOnChannelCreation {
    [[self.mockTaskManager expect] enqueueRequestWithID:UAUserUpdateTaskID options:OCMOCK_ANY];
    [self.notificationCenter postNotificationName:UAChannelCreatedEvent object:nil];
    [self.mockTaskManager verify];
}

- (void)testUpdateOnInit {
    [[self.mockTaskManager expect] enqueueRequestWithID:UAUserUpdateTaskID options:OCMOCK_ANY];
    self.user = [UAUser userWithChannel:self.mockChannel
                              dataStore:self.dataStore
                                 client:self.mockUserClient
                     notificationCenter:self.notificationCenter
                            userDataDAO:self.userDataDAO
                            taskManager:self.mockTaskManager];
    [self.mockTaskManager verify];
}

- (void)testUpdateOnEnablement {
    self.user.enabled = NO;

    [[self.mockTaskManager expect] enqueueRequestWithID:UAUserUpdateTaskID options:OCMOCK_ANY];
    self.user.enabled = YES;
    [self.mockTaskManager verify];
}	

/**
 * Test user ID is added to the CRA payload.
 */
- (void)testRegistrationPayload {
    [self.userDataDAO saveUserData:self.userData completionHandler:^(BOOL success) {}];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    XCTestExpectation *extendedPayload = [self expectationWithDescription:@"extended payload"];
    self.extenderBlock(payload, ^(UAChannelRegistrationPayload * _Nonnull payload) {
        XCTAssertEqualObjects(self.userData.username, payload.userID);
        [extendedPayload fulfill];
    });

    [self waitForTestExpectations];
}

- (void)testRegistrationPayloadDisabled {
    self.user.enabled = NO;
    [self.userDataDAO saveUserData:self.userData completionHandler:^(BOOL success) {}];

    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];
    XCTestExpectation *extendedPayload = [self expectationWithDescription:@"extended payload"];
    self.extenderBlock(payload, ^(UAChannelRegistrationPayload * _Nonnull payload) {
        XCTAssertNil(payload.userID);
        [extendedPayload fulfill];
    });

    [self waitForTestExpectations];
}

- (void)testUpdateTaskCreatesChannel {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.channelID = @"some-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) = completionHandler = (__bridge  void (^)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error))arg;

        UAUserCreateResponse *response = [[UAUserCreateResponse alloc] initWithStatus:200 userData:self.userData];
        completionHandler(response, nil);

        [apiCalled fulfill];
    }] createUserWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self waitForTestExpectations];

    XCTAssertEqualObjects(self.userDataDAO.getUserDataSync, self.userData, @"Saved and response user data should match");

    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUserCreateFailedWithError {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskFailed];

    self.channelID = @"some-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) = completionHandler = (__bridge  void (^)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error))arg;

        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];
        completionHandler(nil, error);

        [apiCalled fulfill];
    }] createUserWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    XCTAssertNil([self.userDataDAO getUserDataSync]);
    [self waitForTestExpectations];
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUserCreateFailedWithRecoverableStatus {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskFailed];

    self.channelID = @"some-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) =  (__bridge  void (^)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error))arg;

        UAUserCreateResponse *response = [[UAUserCreateResponse alloc] initWithStatus:500 userData:self.userData];
        completionHandler(response, nil);

        [apiCalled fulfill];
    }] createUserWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    XCTAssertNil([self.userDataDAO getUserDataSync]);
    [self waitForTestExpectations];

    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUserCreateFailedWithUnrecoverableStatus {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.channelID = @"some-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) = completionHandler = (__bridge  void (^)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error))arg;

        UAUserCreateResponse *response = [[UAUserCreateResponse alloc] initWithStatus:400 userData:self.userData];
        completionHandler(response, nil);

        [apiCalled fulfill];
    }] createUserWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    XCTAssertNil([self.userDataDAO getUserDataSync]);
    [self waitForTestExpectations];

    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateDifferentChannelRecreatesUser {
    // Create the channel
    [self testUpdateTaskCreatesChannel];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.channelID = @"some-other-channel";

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) = completionHandler = (__bridge  void (^)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error))arg;

        UAUserCreateResponse *response = [[UAUserCreateResponse alloc] initWithStatus:200 userData:self.userData];
        completionHandler(response, nil);

        [apiCalled fulfill];
    }] createUserWithChannelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self waitForTestExpectations];
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateUserWithError {
    // Create the channel
    [self testUpdateTaskCreatesChannel];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskFailed];

    // force an update
    [self.notificationCenter postNotificationName:UARemoteConfigURLManagerConfigUpdated object:nil];

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse * _Nullable response, NSError * _Nullable error) = completionHandler = (__bridge  void (^)(UAHTTPResponse * _Nullable response, NSError * _Nullable error))arg;

        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];
        completionHandler(nil, error);

        [apiCalled fulfill];
    }] updateUserWithData:self.userData channelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self waitForTestExpectations];
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateUserWithUnrecoverableStatus {
    // Create the channel
    [self testUpdateTaskCreatesChannel];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    // force an update
    [self.notificationCenter postNotificationName:UARemoteConfigURLManagerConfigUpdated object:nil];

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse * _Nullable response, NSError * _Nullable error) = completionHandler = (__bridge  void (^)(UAHTTPResponse * _Nullable response, NSError * _Nullable error))arg;

        UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:400];
        completionHandler(response, nil);

        [apiCalled fulfill];
    }] updateUserWithData:self.userData channelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self waitForTestExpectations];
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateUserWithRecoverableStatus {
    // Create the channel
    [self testUpdateTaskCreatesChannel];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskFailed];

    // force an update
    [self.notificationCenter postNotificationName:UARemoteConfigURLManagerConfigUpdated object:nil];

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];
    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse * _Nullable response, NSError * _Nullable error) = completionHandler = (__bridge  void (^)(UAHTTPResponse * _Nullable response, NSError * _Nullable error))arg;

        UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:500];
        completionHandler(response, nil);

        [apiCalled fulfill];
    }] updateUserWithData:self.userData channelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self waitForTestExpectations];
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateUserWithUnauthorizedStatus {
    [self.userDataDAO saveUserData:self.userData completionHandler:^(BOOL success) {}];

    // Create the channel
    [self testUpdateTaskCreatesChannel];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    // force an update
    [self.notificationCenter postNotificationName:UARemoteConfigURLManagerConfigUpdated object:nil];

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse * _Nullable response, NSError * _Nullable error) = completionHandler = (__bridge  void (^)(UAHTTPResponse * _Nullable response, NSError * _Nullable error))arg;
        UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:401];
        completionHandler(response, nil);

        [apiCalled fulfill];
    }] updateUserWithData:self.userData channelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self waitForTestExpectations];

    XCTAssertNil([self.userDataDAO getUserDataSync]);

    [self.mockUserClient verify];
    [self.mockTaskManager verify];
    [mockTask verify];
}

- (void)testUpdateTaskNoChannelID {
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.channelID = nil;
    [[self.mockUserClient reject] createUserWithChannelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockUserClient reject] updateUserWithData:OCMOCK_ANY channelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateTaskDisabled {
    self.user.enabled = NO;
    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    self.channelID = @"some-channel";
    [[self.mockUserClient reject] createUserWithChannelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockUserClient reject] updateUserWithData:OCMOCK_ANY channelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testUpdateTaskAlreadyUpToDate {
    // Create the channel
    [self testUpdateTaskCreatesChannel];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    [[self.mockUserClient reject] createUserWithChannelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockUserClient reject] updateUserWithData:OCMOCK_ANY channelID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self.mockUserClient verify];
    [mockTask verify];
}

- (void)testRemoteURLConfigUpdated {
    // Create the channel
    [self testUpdateTaskCreatesChannel];

    [[self.mockTaskManager expect] enqueueRequestWithID:UAUserUpdateTaskID options:OCMOCK_ANY];

    [self.notificationCenter postNotificationName:UARemoteConfigURLManagerConfigUpdated object:nil];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAUserUpdateTaskID] taskID];
    [[mockTask expect] taskCompleted];

    XCTestExpectation *apiCalled = [self expectationWithDescription:@"API client called"];

    [[[self.mockUserClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(UAHTTPResponse * _Nullable response, NSError * _Nullable error) = completionHandler = (__bridge  void (^)(UAHTTPResponse * _Nullable response, NSError * _Nullable error))arg;

        UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:200];
        completionHandler(response, nil);

        [apiCalled fulfill];
    }] updateUserWithData:self.userData channelID:self.channelID completionHandler:OCMOCK_ANY];

    self.launchHandler(mockTask);
    [self waitForTestExpectations];
    [self.mockUserClient verify];
    [mockTask verify];
}


@end

@implementation UATestUserDataDAO
- (nullable UAUserData *)getUserDataSync {
    return self.userData;
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler dispatcher:(nullable UADispatcher *)dispatcher {
    [dispatcher dispatchAsync:^{
        completionHandler(self.userData);
    }];
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler {
    completionHandler(self.userData);
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler queue:(nullable dispatch_queue_t)queue {
    if (queue) {
        dispatch_async(queue, ^{
            completionHandler(self.userData);
        });
    } else {
        completionHandler(self.userData);
    }
}

- (void)saveUserData:(UAUserData *)data completionHandler:(void (^)(BOOL))completionHandler {
    self.userData = data;
    completionHandler(YES);
}

- (void)clearUser {
    self.userData = nil;
}

@end

