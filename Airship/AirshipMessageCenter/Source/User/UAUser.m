/* Copyright Airship and Contributors */

#import "UAUser+Internal.h"
#import "UAUserData.h"
#import "UAUserAPIClient+Internal.h"
#import "UAAirshipMessageCenterCoreImport.h"
#import "UATaskManager.h"
#import "UAUserData+Internal.h"

NSString * const UAUserRegisteredChannelIDKey= @"UAUserRegisteredChannelID";
NSString * const UAUserCreatedNotification = @"com.urbanairship.notification.user_created";

static NSString * const UAUserUpdateTaskID = @"UAUser.update";
static NSString * const UAUserResetTaskID = @"UAUser.reset";

@interface UAUser()
@property (nonatomic, strong) UAChannel<UAExtendableChannelRegistration> *channel;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UAUserDataDAO *userDataDAO;
@property (nonatomic, strong) UAUserAPIClient *apiClient;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (copy) NSString *registeredChannelID;
@property (nonatomic, strong) UATaskManager *taskManager;
@end

@implementation UAUser

- (instancetype)initWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel
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
                                        name:UAChannelCreatedEvent
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(enqueueResetTask)
                                        name:UADeviceIDChangedNotification
                                      object:nil];

        UA_WEAKIFY(self)
        [self.channel addChannelExtenderBlock:^(UAChannelRegistrationPayload *payload, UAChannelRegistrationExtenderCompletionHandler completionHandler) {
            UA_STRONGIFY(self)
            [self extendChannelRegistrationPayload:payload completionHandler:completionHandler];
        }];

        [self.taskManager registerForTaskWithIDs:@[UAUserUpdateTaskID, UAUserResetTaskID]
                                      dispatcher:[UADispatcher serialDispatcher]
                                   launchHandler:^(id<UATask> task) {
            UA_STRONGIFY(self)
            if ([task.taskID isEqualToString:UAUserResetTaskID]) {
                [self handleResetTask:task];
            } else if ([task.taskID isEqualToString:UAUserUpdateTaskID]) {
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

+ (instancetype)userWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel config:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAUser alloc] initWithChannel:channel
                                 dataStore:dataStore
                                    client:[UAUserAPIClient clientWithConfig:config]
                        notificationCenter:[NSNotificationCenter defaultCenter]
                               userDataDAO:[UAUserDataDAO userDataDAOWithConfig:config]
                               taskManager:[UATaskManager shared]];
}

+ (instancetype)userWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel
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

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler dispatcher:(nullable UADispatcher *)dispatcher {
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

- (void)enqueueUpdateTask {
    UATaskRequestOptions *requestOptions = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyKeep
                                                                           requiresNetwork:YES
                                                                                    extras:nil];
    [self.taskManager enqueueRequestWithID:UAUserUpdateTaskID
                                   options:requestOptions];
}

- (void)enqueueResetTask {
    UATaskRequestOptions *requestOptions = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyKeep
                                                                           requiresNetwork:NO
                                                                                    extras:nil];
    [self.taskManager enqueueRequestWithID:UAUserResetTaskID
                                   options:requestOptions];
}

- (void)handleResetTask:(id<UATask>)task {
    self.registeredChannelID = nil;
    [self.userDataDAO clearUser];
    [self enqueueUpdateTask];
    [task taskCompleted];
}

- (void)handleUpdateTask:(id<UATask>)task {
    if (!self.enabled) {
        UA_LDEBUG(@"Skipping user registration, user disabled.");
        [task taskCompleted];
        return;
    }

    NSString *channelID = self.channel.identifier;
    if (!channelID) {
        [task taskCompleted];
        return;
    }

    UAUserData *data = [self getUserDataSync];

    if (data && [self.registeredChannelID isEqualToString:channelID]) {
        [task taskCompleted];
        return;
    }

    UADisposable *request;

    if (data) {
        request = [self performUserUpdateWithData:data channelID:channelID task:task];
    } else {
        request = [self performUserCreateWithChannelID:channelID task:task];
    }

    task.expirationHandler = ^{
        [request dispose];
    };
}

- (void)setEnabled:(BOOL)enabled {
    if (_enabled != enabled) {
        _enabled = enabled;
        if (enabled) {
            [self enqueueUpdateTask];
        }
    }
}

- (UADisposable *)performUserUpdateWithData:(UAUserData *)userData channelID:(NSString *)channelID task:(id<UATask>)task {
    UA_WEAKIFY(self)
    return [self.apiClient updateUserWithData:userData channelID:channelID completionHandler:^(UAHTTPResponse * _Nullable response, NSError * _Nullable error) {
        UA_STRONGIFY(self)
        if (error) {
            UA_LDEBUG(@"User update failed with error %@", error);
            [task taskFailed];
        } else if (!response.isSuccess) {
            UA_LDEBUG(@"User update failed with status %lul", (unsigned long)response.status);

            if (response.isServerError) {
                [task taskFailed];
            } else {
                if (response.status == 401) {
                    UA_LDEBUG(@"Recreating user");
                    [self enqueueResetTask];
                }

                [task taskCompleted];
            }
        } else {
            UA_LINFO(@"Updated user %@ successfully.", userData.username);
            self.registeredChannelID = channelID;
            [task taskCompleted];
        }
    }];
}


- (UADisposable *)performUserCreateWithChannelID:(NSString *)channelID task:(id<UATask>)task {
    UA_WEAKIFY(self)
    return [self.apiClient createUserWithChannelID:channelID completionHandler:^(UAUserCreateResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            UA_LDEBUG(@"User creation failed with error %@", error);
            [task taskFailed];
        } else if (!response.isSuccess) {
            UA_LDEBUG(@"User creation failed with status %lul", (unsigned long)response.status);

            if (response.isServerError) {
                [task taskFailed];
            } else {
                [task taskCompleted];
            }
        } else {
            UA_STRONGIFY(self)
            [self.userDataDAO saveUserData:response.userData completionHandler:^(BOOL success) {
                UA_STRONGIFY(self)
                if (success) {
                    UA_LINFO(@"Created user %@ successfully.", response.userData.username);
                    self.registeredChannelID = channelID;
                    [self.notificationCenter postNotificationName:UAUserCreatedNotification object:nil];
                    [task taskCompleted];
                } else {
                    UA_LINFO(@"Failed to save user");
                    [task taskFailed];
                }
            }];
        }
    }];
}

- (void)extendChannelRegistrationPayload:(UAChannelRegistrationPayload *)payload
                       completionHandler:(UAChannelRegistrationExtenderCompletionHandler)completionHandler {
    [self.userDataDAO getUserData:^(UAUserData *userData) {
        payload.userID = userData.username;
        completionHandler(payload);
    }];
}


@end
