/* Copyright Airship and Contributors */

#import "UAUser+Internal.h"
#import "UAUserData.h"
#import "UAUserAPIClient+Internal.h"
#import "UAPush.h"
#import "UAUtils+Internal.h"
#import "UARuntimeConfig.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAirship.h"
#import "UAComponent+Internal.h"

NSString * const UAUserRegisteredChannelIDKey= @"UAUserRegisteredChannelID";
NSString * const UAUserCreatedNotification = @"com.urbanairship.notification.user_created";

@interface UAUser()
@property (nonatomic, strong) UAPush *push;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UIApplication *application;
@property (nonatomic, strong) UAUserDataDAO *userDataDAO;
@property (nonatomic, strong) UAUserAPIClient *apiClient;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UADispatcher *backgroundDispatcher;
@property (copy) NSString *registeredChannelID;
@property (assign) BOOL registrationInProgress;
@end

@implementation UAUser

- (instancetype)initWithPush:(UAPush *)push
                   dataStore:(UAPreferenceDataStore *)dataStore
                      client:(UAUserAPIClient *)client
          notificationCenter:(NSNotificationCenter *)notificationCenter
                 application:(UIApplication *)application
        backgroundDispatcher:(UADispatcher *)backgroundDispatcher
                 userDataDAO:(UAUserDataDAO *)userDataDAO {

    self = [super initWithDataStore:dataStore];

    if (self) {
        self.push = push;
        self.dataStore = dataStore;
        self.apiClient = client;
        self.notificationCenter = notificationCenter;
        self.application = application;
        self.backgroundDispatcher = backgroundDispatcher;
        self.userDataDAO = userDataDAO;

        [self.notificationCenter addObserver:self
                                    selector:@selector(performUserRegistration)
                                        name:UAChannelCreatedEvent
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(didBecomeActive)
                                        name:UIApplicationDidBecomeActiveNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(enterForeground)
                                        name:UIApplicationWillEnterForegroundNotification
                                      object:nil];
    }

    return self;
}

+ (instancetype)userWithPush:(UAPush *)push config:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAUser alloc] initWithPush:push
                              dataStore:dataStore
                                 client:[UAUserAPIClient clientWithConfig:config]
                     notificationCenter:[NSNotificationCenter defaultCenter]
                            application:[UIApplication sharedApplication]
                   backgroundDispatcher:[UADispatcher backgroundDispatcher]
                            userDataDAO:[UAUserDataDAO userDataDAOWithConfig:config]];
}

+ (instancetype)userWithPush:(UAPush *)push
                   dataStore:(UAPreferenceDataStore *)dataStore
                      client:(UAUserAPIClient *)client
          notificationCenter:(NSNotificationCenter *)notificationCenter
                 application:(UIApplication *)application
        backgroundDispatcher:(UADispatcher *)backgroundDispatcher
                 userDataDAO:(UAUserDataDAO *)userDataDAO {

    return [[UAUser alloc] initWithPush:push
                              dataStore:dataStore
                                 client:client
                     notificationCenter:notificationCenter
                            application:application
                   backgroundDispatcher:backgroundDispatcher
                            userDataDAO:userDataDAO];
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

- (void)enterForeground {
    [self ensureUserUpToDate];
}

- (void)didBecomeActive {
    [self ensureUserUpToDate];
    [self.notificationCenter removeObserver:self
                                       name:UIApplicationDidBecomeActiveNotification
                                     object:nil];
}

- (void)ensureUserUpToDate {
    if (!self.push.channelID) {
        return;
    }

    UA_WEAKIFY(self)
    [self getUserData:^(UAUserData *data) {
        UA_STRONGIFY(self)
        if (self.registrationInProgress) {
            return;
        }

        if (!data || ![self.registeredChannelID isEqualToString:self.push.channelID]) {
            [self performUserRegistration];
        }
    } dispatcher:self.backgroundDispatcher];
}

- (void)resetUser {
    UA_WEAKIFY(self)
    [self getUserData:^(UAUserData *data) {
        if (!data) {
            return;
        }

        UA_STRONGIFY(self)
        self.registeredChannelID = nil;
        self.registrationInProgress = NO;
        [self.userDataDAO clearUser];
        [self performUserRegistration];
    } dispatcher:self.backgroundDispatcher];
}

- (void)onComponentEnableChange {
    if (self.componentEnabled) {
        [self ensureUserUpToDate];
    }
}

/**
 * Performs either a create or update on the user depending on if the user data is available in the DAO. Perform registration
 * will no-op if the component is disabled, channelID is unavailable, or if a background task fails to create.
 */
- (void)performUserRegistration {
    if (!self.componentEnabled) {
        UA_LDEBUG(@"Skipping user registration, component disabled.");
        return;
    }

    NSString *channelID = self.push.channelID;
    if (!channelID) {
        UA_LDEBUG(@"Skipping user registration, no channel.");
        return;
    }

    UA_WEAKIFY(self)

    __block UIBackgroundTaskIdentifier backgroundTask = [self.application beginBackgroundTaskWithExpirationHandler:^{
        UA_STRONGIFY(self)
        [self.apiClient cancelAllRequests];
        if (backgroundTask != UIBackgroundTaskInvalid) {
            [self.application endBackgroundTask:backgroundTask];
            backgroundTask = UIBackgroundTaskInvalid;
        }
        self.registrationInProgress = NO;
    }];

    if (backgroundTask == UIBackgroundTaskInvalid) {
        UA_LDEBUG(@"Skipping user registration, unable to create background task.");
        return;
    }

    void (^completionHandler)(BOOL) = ^(BOOL success) {
        UA_STRONGIFY(self)
        [self.backgroundDispatcher dispatchAsync:^{
            UA_STRONGIFY(self)
            self.registrationInProgress = NO;
            if (success) {
                self.registeredChannelID = channelID;
            }
            if (backgroundTask != UIBackgroundTaskInvalid) {
                [self.application endBackgroundTask:backgroundTask];
                backgroundTask = UIBackgroundTaskInvalid;
            }
        }];
    };

    [self getUserData:^(UAUserData *data) {
        UA_STRONGIFY(self)

        // Checking for registrationInProgress here instead of above so its only
        // accessed on the background queue.
        if (self.registrationInProgress) {
            UA_LDEBUG(@"Skipping user registration, already in progress");
            completionHandler(NO);
            return;
        }

        self.registrationInProgress = YES;
        if (data) {
            [self updateUserWithUserData:data channelID:channelID completionHandler:completionHandler];
        } else {
            [self createUserWithChannelID:channelID completionHandler:completionHandler];
        }
    } dispatcher:self.backgroundDispatcher];
}

/**
 *  Updates the user with the latest channel. Called from `performUserRegistration`.
 *  @param userData The current user's data.
 *  @param channelID The Airship channel ID.
 *  @param completionHandler Completion handler.
 */
- (void)updateUserWithUserData:(UAUserData *)userData channelID:(NSString *)channelID completionHandler:(void(^)(BOOL))completionHandler {
    UA_LTRACE(@"Updating user");
    [self.apiClient updateUserWithData:userData
                             channelID:channelID
                             onSuccess:^{
                                 UA_LINFO(@"Updated user %@ successfully.", userData.username);
                                 completionHandler(YES);
                             }
                             onFailure:^(NSUInteger statusCode) {
                                 UA_LDEBUG(@"Failed to update user.");
                                 completionHandler(NO);
                             }];
}

/**
 *  Creates the user with the latest channel and saves the user data to the DAO. Called from `performUserRegistration`.
 *  @param channelID The Airship channel ID.
 *  @param completionHandler Completion handler.
 */
- (void)createUserWithChannelID:(NSString *)channelID completionHandler:(void(^)(BOOL))completionHandler {
    UA_LTRACE(@"Creating user");
    UA_WEAKIFY(self)
    [self.apiClient createUserWithChannelID:channelID
                                  onSuccess:^(UAUserData *data) {
                                      UA_STRONGIFY(self)
                                      UA_LINFO(@"Created user %@.", data.username);
                                      [self.userDataDAO saveUserData:data completionHandler:^(BOOL success) {
                                          UA_STRONGIFY(self)
                                          if (success) {
                                              [self.notificationCenter postNotificationName:UAUserCreatedNotification object:nil];
                                          } else {
                                              UA_LINFO(@"Failed to save user");
                                          }
                                          completionHandler(success);
                                      }];
                                  }
                                  onFailure:^(NSUInteger statusCode) {
                                      UA_LINFO(@"Failed to create user");
                                      completionHandler(NO);
                                  }];
}

@end
