/* Copyright Urban Airship and Contributors */

#import "UAUser+Internal.h"
#import "UAUserData.h"
#import "UAUserAPIClient+Internal.h"
#import "UAPush.h"
#import "UAUtils+Internal.h"
#import "UAConfig.h"
#import "UAKeychainUtils+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAirship.h"
#import "UAComponent+Internal.h"

#define kUAUserIDKey @"ua_user_id"
#define kUAUserURLKey @"UserURLKey"

NSString * const UAUserCreatedNotification = @"com.urbanairship.notification.user_created";

@interface UAUser()
@property (nonatomic, strong) UAPush *push;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UIApplication *application;
@property (nonatomic, strong) UADispatcher *backgroundDispatcher;
@end

@implementation UAUser

+ (void)setDefaultUsername:(NSString *)defaultUsername withPassword:(NSString *)defaultPassword {

    NSString *storedUsername = [UAKeychainUtils getUsername:[UAirship shared].config.appKey];

    // If the keychain username is present a user already exists, if not, save
    if (storedUsername == nil) {
        //Store un/pw
        [UAKeychainUtils createKeychainValueForUsername:defaultUsername withPassword:defaultPassword forIdentifier:[UAirship shared].config.appKey];
    }

}

- (instancetype)initWithPush:(UAPush *)push
                      config:(UAConfig *)config
                   dataStore:(UAPreferenceDataStore *)dataStore
                      client:(UAUserAPIClient *)client
          notificationCenter:(NSNotificationCenter *)notificationCenter
                 application:(UIApplication *)application
                  dispatcher:(UADispatcher *)dispatcher {

    self = [super initWithDataStore:dataStore];

    if (self) {
        self.config = config;
        self.apiClient = client;
        self.dataStore = dataStore;
        self.push = push;
        self.notificationCenter = notificationCenter;
        self.application = application;

        [self.notificationCenter addObserver:self
                                    selector:@selector(channelCreated)
                                        name:UAChannelCreatedEvent
                                      object:nil];

        self.backgroundDispatcher = dispatcher;
    }

    return self;
}

+ (instancetype)userWithPush:(UAPush *)push config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAUser alloc] initWithPush:push
                                 config:config
                              dataStore:dataStore
                                 client:[UAUserAPIClient clientWithConfig:config]
                     notificationCenter:[NSNotificationCenter defaultCenter]
                            application:[UIApplication sharedApplication]
                             dispatcher:[UADispatcher backgroundDispatcher]];
}

+ (instancetype)userWithPush:(UAPush *)push
                      config:(UAConfig *)config
                   dataStore:(UAPreferenceDataStore *)dataStore
                      client:(UAUserAPIClient *)client
          notificationCenter:(NSNotificationCenter *)notificationCenter
                 application:(UIApplication *)application
                  dispatcher:(UADispatcher *)dispatcher {

    return [[UAUser alloc] initWithPush:push
                                 config:config
                              dataStore:dataStore
                                 client:client
                     notificationCenter:notificationCenter
                            application:application
                             dispatcher:dispatcher];
}

#pragma mark -
#pragma mark Get/Update/Save User Data

- (nullable UAUserData *)getUserDataSync {
    NSString *appKey = self.config.appKey;
    __block UAUserData *userData;

    UA_WEAKIFY(self)
    [self.backgroundDispatcher doSync:^{
        if (self.userData) {
            userData = self.userData;
            return;
        }

        UA_STRONGIFY(self)
        NSString *username = [UAKeychainUtils getUsername:appKey];
        NSString *password = [UAKeychainUtils getPassword:appKey];

        if (username && password) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            self.userData = userData = [UAUserData dataWithUsername:username password:password url:self.url];
#pragma GCC diagnostic pop
        }
    }];

    return userData;
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler dispatcher:(nullable UADispatcher *)dispatcher {
    [self.backgroundDispatcher dispatchAsync:^{
        UAUserData *userData = [self getUserDataSync];

        if (dispatcher) {
            [dispatcher dispatchAsync:^{
                completionHandler(userData);
            }];
        } else {
            completionHandler(userData);
        }
    }];
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler {
    [self.backgroundDispatcher dispatchAsync:^{
        completionHandler([self getUserDataSync]);
    }];
}

- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler queue:(nullable dispatch_queue_t)queue {
    [self getUserData:^(UAUserData *data) {
        if (queue) {
            dispatch_async(queue, ^{
                completionHandler(data);
            });
        } else {
            completionHandler(data);
        }
    }];
}

- (NSString *)username {
    UAUserData *userData = [self getUserDataSync];
    return userData.username;
}

- (NSString *)password {
    UAUserData *userData = [self getUserDataSync];
    return userData.password;
}

- (NSString *)url {
    return [self.dataStore objectForKey:kUAUserURLKey];
}

/**
 * Save username and password data to disk.
 */
- (void)saveUserData:(UAUserData *)data completionHandler:(void (^)(BOOL))completionHandler; {
    // No username object stored in the keychain for this app, so let's create it
    // but only if we indeed have a username and password to store
    UA_WEAKIFY(self)
    [self getUserData:^(UAUserData *savedData) {
        UA_STRONGIFY(self)
        if (!savedData) {
            if (![UAKeychainUtils createKeychainValueForUsername:data.username withPassword:data.password forIdentifier:self.config.appKey]) {
                UA_LERR(@"Save failed: unable to create keychain for username.");
                return completionHandler(NO);
            }
        }

        self.userData = data;

        // Update keychain with latest username and password
        [UAKeychainUtils updateKeychainValueForUsername:data.username
                                           withPassword:data.password
                                          forIdentifier:self.config.appKey];

        // Persist URL in datastore
        [self.dataStore setObject:data.url forKey:kUAUserURLKey];

        // Save in NSUserDefaults for access with a Settings bundle
        NSMutableDictionary *userDictionary = [NSMutableDictionary dictionary];
        [userDictionary setValue:data.url forKey:kUserUrlKey];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:data.username forKey:kUAUserIDKey];
        [defaults setObject:userDictionary forKey:self.config.appKey];
        [defaults synchronize];

        completionHandler(YES);
    }];
}

#pragma mark -
#pragma mark Create

- (BOOL)isCreated {
    if (self.password.length && self.username.length) {
        return YES;
    }
    return NO;
}

- (void)sendUserCreatedNotification {
    [self.notificationCenter postNotificationName:UAUserCreatedNotification object:nil];
}

- (void)createUser:(void (^_Nullable)(UAUserData *))completionHandler {
    completionHandler = completionHandler ? : ^(UAUserData *data){};

    if (!self.componentEnabled) {
        UA_LDEBUG(@"Skipping user creation, component disabled");
        return completionHandler(nil);
    }

    if (!self.push.channelID) {
        UA_LDEBUG(@"Skipping user creation, no channel");
        return completionHandler(nil);
    }

    [self getUserData:^(UAUserData *data) {
        if (data) {
            UA_LDEBUG(@"User already created");
            return completionHandler(data);
        }

        UA_WEAKIFY(self)
        __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            UA_STRONGIFY(self)
            [self.application endBackgroundTask:backgroundTask];
            backgroundTask = UIBackgroundTaskInvalid;
            [self.apiClient cancelAllRequests];
        }];

        if (backgroundTask == UIBackgroundTaskInvalid) {
            UA_LDEBUG(@"Unable to create background task to create user.");
            return completionHandler(nil);
        }

        UAUserAPIClientCreateSuccessBlock success = ^(UAUserData *data, NSDictionary *payload) {
            UA_STRONGIFY(self)
            UA_LINFO(@"Created user %@.", data.username);

            [self saveUserData:data completionHandler:^(BOOL success) {
                if (success) {
                    // if we didn't send a channel on creation, try again
                    if (![payload valueForKey:@"ios_channels"]) {
                        [self updateUser:nil];
                    }

                    [self sendUserCreatedNotification];
                    [self.application endBackgroundTask:backgroundTask];
                    backgroundTask = UIBackgroundTaskInvalid;

                    completionHandler(data);
                } else {
                    completionHandler(nil);
                }
            }];
        };

        UAUserAPIClientFailureBlock failure = ^(NSUInteger statusCode) {
            UA_STRONGIFY(self)
            if (statusCode != UAAPIClientStatusUnavailable) {
                UA_LINFO(@"Failed to create user");
            }

            [self.application endBackgroundTask:backgroundTask];
            backgroundTask = UIBackgroundTaskInvalid;

            completionHandler(nil);
        };

        [self.apiClient createUserWithChannelID:self.push.channelID
                                      onSuccess:success
                                      onFailure:failure];

    }];
}

- (void)createUser {
    [self createUser:nil];
}

#pragma mark -
#pragma mark Update

- (void)updateUser:(void (^_Nullable)(void))completionHandler {
    completionHandler = completionHandler ? : ^{};

    if (!self.componentEnabled) {
        UA_LDEBUG(@"Skipping user update, component disabled");
        return completionHandler();
    }

    if (!self.push.channelID.length) {
        UA_LDEBUG(@"Skipping user update, no channel.");
        return completionHandler();
    }

    UA_WEAKIFY(self)
    __block UIBackgroundTaskIdentifier backgroundTask = [self.application beginBackgroundTaskWithExpirationHandler:^{
        UA_STRONGIFY(self)
        [self.application endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
        [self.apiClient cancelAllRequests];
    }];

    if (backgroundTask == UIBackgroundTaskInvalid) {
        UA_LDEBUG(@"Unable to create background task to update user.");
        return completionHandler();
    }

    [self getUserData:^(UAUserData *data) {

        if (!data) {
            UA_LDEBUG(@"Skipping user update, user not created yet.");
            return completionHandler();
        }

        UA_LTRACE(@"Updating user");

        [self.apiClient updateUser:self
                         channelID:self.push.channelID
                         onSuccess:^{
                             UA_STRONGIFY(self)
                             UA_LINFO(@"Updated user %@ successfully.", data.username);
                             [self.application endBackgroundTask:backgroundTask];
                             backgroundTask = UIBackgroundTaskInvalid;
                             completionHandler();
                         }
                         onFailure:^(NSUInteger statusCode) {
                             UA_STRONGIFY(self)
                             UA_LDEBUG(@"Failed to update user.");
                             [self.application endBackgroundTask:backgroundTask];
                             backgroundTask = UIBackgroundTaskInvalid;
                             completionHandler();
                         }];
    }];
}

- (void)resetUser {
    UA_WEAKIFY(self)
    [self.backgroundDispatcher doSync:^{
        UA_STRONGIFY(self)
        UA_LDEBUG(@"Deleting the keychain credentials");
        [self.apiClient cancelAllRequests];
        [UAKeychainUtils deleteKeychainValue:self.config.appKey];
        self.userData = nil;
    }];
}

- (void)channelCreated {
    // Update the user if we already have a channelID
    if (self.push.channelID) {
        UA_WEAKIFY(self)
        [self getUserData:^(UAUserData *data) {
            UA_STRONGIFY(self)
            if (data) {
                [self updateUser:nil];
            } else {
                [self createUser:nil];
            }
        }];
    }
}

- (void)onComponentEnableChange {
    if (self.componentEnabled) {
        // if component was disabled and is now enabled, update the user in case we missed channel creation
        [self channelCreated];
    }
}

@end

