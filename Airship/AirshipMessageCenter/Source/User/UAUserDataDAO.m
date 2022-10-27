/* Copyright Airship and Contributors */

#import "UAUserDataDAO+Internal.h"
#import "UAUserData+Internal.h"
#import "UAAirshipMessageCenterCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif


@interface UAUserDataDAO()
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UADispatcher *backgroundDispatcher;
@property (strong) UAUserData *userData;
@property (strong) UAirshipKeychainAccess *keychainAccess;
@end

@implementation UAUserDataDAO

- (instancetype)initWithConfig:(UARuntimeConfig *)config {
    self = [super init];

    if (self) {
        self.config = config;
        self.backgroundDispatcher = UADispatcher.global;
        self.keychainAccess = [[UAirshipKeychainAccess alloc] initWithAppKey:config.appKey];
    }

    return self;
}

+ (instancetype)userDataDAOWithConfig:(UARuntimeConfig *)config {
    return [[UAUserDataDAO alloc] initWithConfig:config];
}

- (nullable UAUserData *)getUserDataSync {
    __block UAUserData *userData;

    UA_WEAKIFY(self)
    [self.backgroundDispatcher doSync:^{
        UA_STRONGIFY(self)

        @synchronized (self) {
            if (!self.userData) {
                UAirshipKeychainCredentials *credentials = [self.keychainAccess readCredentialsSyncWithIdentifier:self.config.appKey];

                if (credentials) {
                    self.userData = [UAUserData dataWithUsername:credentials.username
                                                        password:credentials.password];
                }
            }

            userData = self.userData;
        }
    }];

    return userData;
}

- (void)getUserData:(void (^)(UAUserData *))completionHandler dispatcher:(nullable UADispatcher *)dispatcher {
    UA_WEAKIFY(self)
    [self.backgroundDispatcher dispatchAsync:^{
        UA_STRONGIFY(self)
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

- (void)getUserData:(void (^)(UAUserData *))completionHandler {
    UA_WEAKIFY(self)
    [self.backgroundDispatcher dispatchAsync:^{
        UA_STRONGIFY(self)
        completionHandler([self getUserDataSync]);
    }];
}

- (void)getUserData:(void (^)(UAUserData *))completionHandler queue:(nullable dispatch_queue_t)queue {
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

/**
 * Save username and password data to disk.
 */
- (void)saveUserData:(UAUserData *)data completionHandler:(void (^)(BOOL))completionHandler {
    UAirshipKeychainCredentials *credentials = [[UAirshipKeychainCredentials alloc] initWithUsername:data.username
                                                                                            password:data.password];

    [self.keychainAccess writeCredentials:credentials
                               identifier:self.config.appKey
                        completionHandler:^(BOOL success) {
        if (success) {
            self.userData = data;
            completionHandler(YES);
        } else {
            UA_LERR(@"Save failed: unable to create keychain for username.");
            completionHandler(NO);
        }
    }];
}

- (void)clearUser {
    UA_WEAKIFY(self)
    [self.backgroundDispatcher doSync:^{
        UA_STRONGIFY(self)
        UA_LDEBUG(@"Deleting the keychain credentials");
        @synchronized (self) {
            [self.keychainAccess deleteCredentialsWithIdentifier:self.config.appKey];
            self.userData = nil;
        }
    }];
}

@end
