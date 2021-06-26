/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAChannelRegistrar+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAPush.h"
#import "UARuntimeConfig.h"
#import "UANamedUser+Internal.h"
#import "UAirship.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;


typedef void (^UAChannelAPIClientCreateCompletionHandler)(UAChannelCreateResponse * _Nullable response, NSError * _Nullable error);
typedef void (^UAChannelAPIClientUpdateCompletionHandler)(UAHTTPResponse * _Nullable response, NSError * _Nullable error);


static NSString * const UAChannelRegistrationTaskID = @"UAChannelRegistrar.registration";

@interface UAChannelRegistrarTest : UAAirshipBaseTest

@property(nonatomic, strong) id mockedChannelClient;
@property(nonatomic, strong) id mockedRegistrarDelegate;
@property(nonatomic, strong) id mockTaskManager;
@property(nonatomic, strong) UAChannelRegistrationPayload *payload;
@property(nonatomic, strong) UAChannelRegistrar *registrar;
@property(nonatomic, strong) UATestDate *testDate;
@property(nonatomic, copy) void (^launchHandler)(id<UATask>);
@end

@implementation UAChannelRegistrarTest

- (void)setUp {
    [super setUp];

    self.mockedChannelClient = [self mockForClass:[UAChannelAPIClient class]];
    self.mockedRegistrarDelegate = [self mockForProtocol:@protocol(UAChannelRegistrarDelegate)];
    self.mockTaskManager = [self mockForClass:[UATaskManager class]];
    self.testDate = [[UATestDate alloc] init];

    self.payload = [[UAChannelRegistrationPayload alloc] init];
    self.payload.pushAddress = @"someDeviceToken";
    __block UAChannelRegistrationPayload *copyOfPayload;

    [[[self.mockedRegistrarDelegate stub] andDo:^(NSInvocation *invocation) {
        // verify that createChannelPayload is called on the main thread.
        XCTAssertEqualObjects([NSThread currentThread],[NSThread mainThread]);

        void *arg;
        [invocation getArgument:&arg atIndex:2];
        void (^completionHandler)(UAChannelRegistrationPayload *)  = (__bridge void (^)(UAChannelRegistrationPayload *)) arg;

        copyOfPayload = [self.payload copy];
        completionHandler(copyOfPayload);
    }] createChannelPayload:OCMOCK_ANY];

    // Capture the task launcher
    [[[self.mockTaskManager stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        self.launchHandler =  (__bridge void (^)(id<UATask>))arg;
    }] registerForTaskWithIDs:@[UAChannelRegistrationTaskID] dispatcher:OCMOCK_ANY launchHandler:OCMOCK_ANY];

    self.registrar =  [UAChannelRegistrar channelRegistrarWithConfig:self.config
                                                           dataStore:self.dataStore
                                                    channelAPIClient:self.mockedChannelClient
                                                                date:self.testDate
                                                          dispatcher:[[UATestDispatcher alloc] init]
                                                         taskManager:self.mockTaskManager];
    self.registrar.delegate = self.mockedRegistrarDelegate;
}

- (void)testChannelCreate200 {
    UAChannelCreateResponse *response = [[UAChannelCreateResponse alloc] initWithStatus:200
                                                                              channelID:@"some-channel"];

    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callCreateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] createChannelWithPayload:self.payload completionHandler:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] channelCreated:response.channelID existing:YES];
    [[self.mockedRegistrarDelegate expect] registrationSucceeded];

    id task = [self registrationTask:NO];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];

    XCTAssertEqual(response.channelID, self.registrar.channelID);
}

- (void)testChannelCreate201 {
    UAChannelCreateResponse *response = [[UAChannelCreateResponse alloc] initWithStatus:201
                                                                              channelID:@"some-channel"];

    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callCreateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] createChannelWithPayload:self.payload completionHandler:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] channelCreated:response.channelID existing:NO];
    [[self.mockedRegistrarDelegate expect] registrationSucceeded];

    id task = [self registrationTask:NO];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];

    XCTAssertEqual(response.channelID, self.registrar.channelID);
}

- (void)testChannelCreateTooManyRequests {
    UAChannelCreateResponse *response = [[UAChannelCreateResponse alloc] initWithStatus:429 channelID:nil];

    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callCreateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] createChannelWithPayload:self.payload completionHandler:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationFailed];

    id task = [self registrationTask:NO];
    [[task expect] taskFailed];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];
}

- (void)testChannelCreateClientError {
    UAChannelCreateResponse *response = [[UAChannelCreateResponse alloc] initWithStatus:400 channelID:nil];

    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callCreateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] createChannelWithPayload:self.payload completionHandler:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationFailed];

    id task = [self registrationTask:NO];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];
}

- (void)testChannelCreateServerError {
    UAChannelCreateResponse *response = [[UAChannelCreateResponse alloc] initWithStatus:500 channelID:nil];

    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callCreateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] createChannelWithPayload:self.payload completionHandler:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationFailed];

    id task = [self registrationTask:NO];
    [[task expect] taskFailed];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];
}

- (void)testChannelCreateError {
    NSError *error = [[NSError alloc] initWithDomain:@"domain" code:1 userInfo:nil];

    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callCreateCompletionHandler:invocation
                                                   response:nil
                                                      error:error];
    }] createChannelWithPayload:self.payload completionHandler:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationFailed];

    id task = [self registrationTask:NO];
    [[task expect] taskFailed];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];
}

- (void)testChannelCreatePayloadOutdated {
    UAChannelCreateResponse *response = [[UAChannelCreateResponse alloc] initWithStatus:201 channelID:@"some-channel"];

    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        // Update the push address
        self.payload.pushAddress = [NSUUID UUID].UUIDString;

        [UAChannelRegistrarTest callCreateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] createChannelWithPayload:self.payload completionHandler:OCMOCK_ANY];

    [[self.mockTaskManager expect] enqueueRequestWithID:UAChannelRegistrationTaskID options:OCMOCK_ANY];
    [[self.mockedRegistrarDelegate expect] channelCreated:response.channelID existing:NO];
    [[self.mockedRegistrarDelegate expect] registrationSucceeded];

    id task = [self registrationTask:YES];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [self.mockTaskManager verify];

    [task verify];
}

- (void)testChannelUpdate {
    [self createChannel:@"some-channel"];

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:200];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callUpdateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] updateChannelWithID:@"some-channel" withPayload:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationSucceeded];

    id task = [self registrationTask:YES];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];
}

- (void)testChannelUpdateTooManyRequests {
    [self createChannel:@"some-channel"];

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:429];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callUpdateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] updateChannelWithID:@"some-channel" withPayload:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationFailed];

    id task = [self registrationTask:YES];
    [[task expect] taskFailed];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];
}

- (void)testChannelUpdateConflict {
    [self createChannel:@"some-channel"];
    XCTAssertNotNil(self.registrar.channelID);

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:409];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callUpdateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] updateChannelWithID:@"some-channel" withPayload:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockTaskManager expect]  enqueueRequestWithID:UAChannelRegistrationTaskID options:OCMOCK_ANY];
    id task = [self registrationTask:YES];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [self.mockTaskManager verify];
    [task verify];

    XCTAssertNil(self.registrar.channelID);
}

- (void)testChannelUpdateClientError {
    [self createChannel:@"some-channel"];

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:400];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callUpdateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] updateChannelWithID:@"some-channel" withPayload:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationFailed];

    id task = [self registrationTask:YES];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];
}

- (void)testChannelUpdateServerError {
    [self createChannel:@"some-channel"];

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:500];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callUpdateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] updateChannelWithID:@"some-channel" withPayload:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockedRegistrarDelegate expect] registrationFailed];

    id task = [self registrationTask:YES];
    [[task expect] taskFailed];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];
}

- (void)testChannelUpdateError {
    [self createChannel:@"some-channel"];

    NSError *error = [[NSError alloc] initWithDomain:@"domain" code:1 userInfo:nil];

    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callUpdateCompletionHandler:invocation
                                                   response:nil
                                                      error:error];
    }] updateChannelWithID:@"some-channel" withPayload:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[self.mockedRegistrarDelegate expect] registrationFailed];

    id task = [self registrationTask:YES];
    [[task expect] taskFailed];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [task verify];
}

- (void)testUpdatePayloadOutdated {
    [self createChannel:@"some-channel"];

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:200];

    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        // Update the push address
        self.payload.pushAddress = [NSUUID UUID].UUIDString;

        [UAChannelRegistrarTest callUpdateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] updateChannelWithID:@"some-channel" withPayload:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockTaskManager expect]  enqueueRequestWithID:UAChannelRegistrationTaskID options:OCMOCK_ANY];
    [[self.mockedRegistrarDelegate expect] registrationSucceeded];

    id task = [self registrationTask:YES];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [self.mockedRegistrarDelegate verify];
    [self.mockTaskManager verify];
    [task verify];
}

- (void)testUpdateAfter24Hours {
    [self createChannel:@"some-channel"];

    // Fast forward
    self.testDate.offset = (24 * 60 * 60);

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:200];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callUpdateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] updateChannelWithID:@"some-channel" withPayload:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    id task = [self registrationTask:NO];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [task verify];
}

- (void)testUpdateMinPayload {
    self.payload.tags = @[@"neat"];
    self.payload.setTags = YES;

    [self createChannel:@"some-channel"];

    UAChannelRegistrationPayload *minPayload = [self.payload minimalUpdatePayloadWithLastPayload:self.payload];
    XCTAssertNotEqualObjects(minPayload, self.payload);

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:200];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callUpdateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] updateChannelWithID:@"some-channel" withPayload:minPayload completionHandler:OCMOCK_ANY];


    id task = [self registrationTask:YES];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [task verify];
}

- (void)testFullUpdate {
    self.payload.tags = @[@"neat"];
    self.payload.setTags = YES;

    [self createChannel:@"some-channel"];

    [self.registrar performFullRegistration];

    UAHTTPResponse *response = [[UAHTTPResponse alloc] initWithStatus:200];
    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callUpdateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] updateChannelWithID:@"some-channel" withPayload:self.payload completionHandler:OCMOCK_ANY];

    id task = [self registrationTask:YES];
    [[task expect] taskCompleted];

    self.launchHandler(task);

    [self.mockedChannelClient verify];
    [task verify];
}

#pragma mark -
#pragma mark Utility methods

- (id<UATask>)registrationTask:(BOOL)forcefully {
    UATaskRequestOptions *options = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyKeep
                                                                         requiresNetwork:YES
                                                                                  extras:@{@"forcefully" : @(forcefully)}];

    id mockTask = [self mockForProtocol:@protocol(UATask)];
    [[[mockTask stub] andReturn:UAChannelRegistrationTaskID] taskID];
    [[[mockTask stub] andReturn:options] requestOptions];
    return mockTask;
}

- (void)createChannel:(NSString *)channelID {
    UAChannelCreateResponse *response = [[UAChannelCreateResponse alloc] initWithStatus:200 channelID:channelID];

    [[[self.mockedChannelClient expect] andDo:^(NSInvocation *invocation) {
        [UAChannelRegistrarTest callCreateCompletionHandler:invocation
                                                   response:response
                                                      error:nil];
    }] createChannelWithPayload:self.payload completionHandler:OCMOCK_ANY];

    id task = [self registrationTask:NO];
    [[task expect] taskCompleted];

    self.launchHandler(task);
}

+ (void)callCreateCompletionHandler:(NSInvocation *)invocation
                           response:(UAChannelCreateResponse *)response
                              error:(NSError *)error {
    void *arg;
    [invocation getArgument:&arg atIndex:3];
    UAChannelAPIClientCreateCompletionHandler completionHandler = (__bridge UAChannelAPIClientCreateCompletionHandler) arg;
    completionHandler(response, error);
}

+ (void)callUpdateCompletionHandler:(NSInvocation *)invocation
                           response:(UAHTTPResponse *)response
                              error:(NSError *)error {
    void *arg;
    [invocation getArgument:&arg atIndex:4];
    UAChannelAPIClientUpdateCompletionHandler completionHandler = (__bridge UAChannelAPIClientUpdateCompletionHandler) arg;
    completionHandler(response, error);
}

@end
