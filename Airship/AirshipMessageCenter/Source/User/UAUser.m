/* Copyright Airship and Contributors */

#import "UAUser+Internal.h"
#import "UAUserData.h"
#import "UAUserAPIClient+Internal.h"
#import "UAAirshipMessageCenterCoreImport.h"
#import "UAUserData+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
static NSString * const UAUserRegisteredChannelIDKey= @"UAUserRegisteredChannelID";
static NSString * const UAUserRequireUpdate= @"UAUserRequireUpdate";

NSString * const UAUserCreatedNotification = @"com.urbanairship.notification.user_created";

static NSString * const UAUserUpdateTaskID = @"UAUser.update";

@interface UAUser()
@property (nonatomic, strong) id<UAChannelProtocol> channel;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UAUserDataDAO *userDataDAO;
@property (nonatomic, strong) UAUserAPIClient *apiClient;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (copy) NSString *registeredChannelID;
@property (assign) BOOL requireUserUpdate;

@property (nonatomic, strong) UATaskManager *taskManager;
@end

@implementation UAUser

- (instancetype)initWithChannel:(id<UAChannelProtocol>)channel
                  dataStore:(UAPreferenceDataStore *)dataStore
                     client:(UAUserAPIClient *)client
         notificationCenter:(NSNotificationCenter *)notificationCenter
                userDataDAO:(UAUserDataDAO *)userDataDAO
                taskManager:(UATaskManager *)taskManager {

    self = [super init];

    if (self) {
        _enabled = YES;
        self.channel = channel;
        self.dataStore = dataStore;
        self.apiClient = client;
        self.notificationCenter = notificationCenter;
        self.userDataDAO = userDataDAO;
        self.taskManager = taskManager;

        [self.notificationCenter addObserver:self
                                    selector:@selector(enqueueUpdateTask)
                                        name:UAChannel.channelCreatedEvent
                                      object:nil];


        [self.notificationCenter addObserver:self
                                    selector:@selector(remoteURLConfigUpdated)
                                        name:UARuntimeConfig.configUpdatedEvent
                                      object:nil];

        UA_WEAKIFY(self)
        [self.channel addRegistrationExtender:^(UAChannelRegistrationPayload * payload, void (^ completionHandler)(UAChannelRegistrationPayload *)) {
            UA_STRONGIFY(self)
            if (self.enabled) {
                [self.userDataDAO getUserData:^(UAUserData *userData) {
                    if (userData.username) {
                        payload.identityHints = payload.identityHints ?: [[UAIdentityHints alloc] init];
                        payload.identityHints.userID = userData.username;
                    }
                    completionHandler(payload);
                }];
            } else {
                completionHandler(payload);
            }
        }];
        
        [self.taskManager registerForTaskWithIDs:@[UAUserUpdateTaskID]
                                      dispatcher:UADispatcher.serialUtility
                                   launchHandler:^(id<UATask> task) {
            if (!self.enabled) {
                UA_LDEBUG(@"User disabled, unable to run task %@", task);
                [task taskCompleted];
                return;
            }

            UA_STRONGIFY(self)
            if ([task.taskID isEqualToString:UAUserUpdateTaskID]) {
                [self handleUpdateTask:task];
            } else {
                UA_LERR(@"Invalid task: %@", task.taskID);
                [task taskCompleted];
            }
        }];

        [self enqueueUpdateTask];
    }

    return self;
}

+ (instancetype)userWithChannel:(id<UAChannelProtocol>)channel config:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAUser alloc] initWithChannel:channel
                                 dataStore:dataStore
                                    client:[UAUserAPIClient clientWithConfig:config]
                        notificationCenter:[NSNotificationCenter defaultCenter]
                               userDataDAO:[UAUserDataDAO userDataDAOWithConfig:config]
                               taskManager:[UATaskManager shared]];
}

+ (instancetype)userWithChannel:(id<UAChannelProtocol>)channel
                      dataStore:(UAPreferenceDataStore *)dataStore
                         client:(UAUserAPIClient *)client
             notificationCenter:(NSNotificationCenter *)notificationCenter
                    userDataDAO:(UAUserDataDAO *)userDataDAO
                    taskManager:(UATaskManager *)taskManager {

    return [[UAUser alloc] initWithChannel:channel
                                 dataStore:dataStore
                                    client:client
                        notificationCenter:notificationCenter
                               userDataDAO:userDataDAO
                               taskManager:taskManager];
}

- (nullable UAUserData *)getUserDataSync {
    return [self.userDataDAO getUserDataSync];
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler
         dispatcher:(nullable UADispatcher *)dispatcher {
    return [self.userDataDAO getUserData:completionHandler dispatcher:dispatcher];
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler {
    return [self.userDataDAO getUserData:completionHandler];
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler queue:(nullable dispatch_queue_t)queue {
    return [self.userDataDAO getUserData:completionHandler queue:queue];
}

- (NSString *)registeredChannelID {
    return [self.dataStore stringForKey:UAUserRegisteredChannelIDKey];
}

- (void)setRegisteredChannelID:(NSString *)registeredChannelID {
    [self.dataStore setValue:registeredChannelID forKey:UAUserRegisteredChannelIDKey];
}

- (BOOL)requireUserUpdate {
    return [self.dataStore boolForKey:UAUserRequireUpdate];
}

- (void)setRequireUserUpdate:(BOOL)requireUpdate {
    return [self.dataStore setBool:requireUpdate forKey:UAUserRequireUpdate];
}

- (void)enqueueUpdateTask {
    if (!self.enabled) {
        UA_LDEBUG(@"Skipping user registration, user disabled.");
        return;
    }

    UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyKeep
                                                                                requiresNetwork:YES
                                                                                         extras:nil];

    [self.taskManager enqueueRequestWithID:UAUserUpdateTaskID
                                   options:requestOptions];
}

- (void)handleUpdateTask:(id<UATask>)task {
    NSString *channelID = self.channel.identifier;
    if (!channelID) {
        [task taskCompleted];
        return;
    }

    UAUserData *data = nil;
    if ([self.registeredChannelID isEqualToString:channelID]) {
        data = [self getUserDataSync];
    } else {
        [self reset];
    }

    if (data && !self.requireUserUpdate) {
        [task taskCompleted];
        return;
    }

    void (^completionHandler)(BOOL) = ^(BOOL completed) {
        if (completed) {
            [task taskCompleted];
            self.requireUserUpdate = false;
        } else {
            [task taskFailed];
        }
    };

    UADisposable *request;
    if (data) {
        request = [self performUserUpdateWithData:data channelID:channelID completionHandler:completionHandler];
    } else {
        request = [self performUserCreateWithChannelID:channelID completionHandler:completionHandler];
    }

    task.expirationHandler = ^{
        [request dispose];
    };
}

- (UADisposable *)performUserUpdateWithData:(UAUserData *)userData
                                  channelID:(NSString *)channelID
                          completionHandler:(void (^)(BOOL completed))completionHandler {
    UA_WEAKIFY(self)
    return [self.apiClient updateUserWithData:userData channelID:channelID completionHandler:^(UAHTTPResponse * _Nullable response, NSError * _Nullable error) {
        UA_STRONGIFY(self)
        if (error) {
            UA_LDEBUG(@"User update failed with error %@", error);
            completionHandler(false);
        } else if (!response.isSuccess) {
            UA_LDEBUG(@"User update failed with status %lul", (unsigned long)response.status);

            if (response.status == 401) {
                [self reset];
                [self enqueueUpdateTask];
                completionHandler(true);
            } else {
                completionHandler(!response.isServerError);
            }
        } else {
            UA_LINFO(@"Updated user %@ successfully.", userData.username);
            self.registeredChannelID = channelID;
            completionHandler(true);
        }
    }];
}

- (UADisposable *)performUserCreateWithChannelID:(NSString *)channelID
                               completionHandler:(void (^)(BOOL completed))completionHandler {

    UA_WEAKIFY(self)
    return [self.apiClient createUserWithChannelID:channelID completionHandler:^(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            UA_LDEBUG(@"User creation failed with error %@", error);
            completionHandler(false);
        } else if (!response.isSuccess) {
            UA_LDEBUG(@"User creation failed with status %lul", (unsigned long)response.status);
            completionHandler(!response.isServerError);
        } else {
            UA_STRONGIFY(self)
            [self.userDataDAO saveUserData:response.userData completionHandler:^(BOOL success) {
                UA_STRONGIFY(self)
                if (success) {
                    UA_LINFO(@"Created user %@ successfully.", response.userData.username);
                    self.registeredChannelID = channelID;
                    [UADispatcher.main dispatchAsync:^{
                        [self.notificationCenter postNotificationName:UAUserCreatedNotification object:nil];
                    }];
                    completionHandler(true);
                } else {
                    UA_LINFO(@"Failed to save user");
                    completionHandler(false);
                }
            }];
        }
    }];
}


- (void)setEnabled:(BOOL)enabled {
    if (_enabled != enabled) {
        _enabled = enabled;
        if (enabled) {
            [self enqueueUpdateTask];
        }
    }
}

- (void)remoteURLConfigUpdated {
    // clear registered channel ID to force an update
    self.requireUserUpdate = true;
    [self enqueueUpdateTask];
}

- (void)reset {
    self.registeredChannelID = nil;
    [self.userDataDAO clearUser];
}

@end

