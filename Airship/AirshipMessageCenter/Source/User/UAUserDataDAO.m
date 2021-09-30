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
@end

@implementation UAUserDataDAO

- (instancetype)initWithConfig:(UARuntimeConfig *)config {
    self = [super init];

    if (self) {
        self.config = config;
        self.backgroundDispatcher = UADispatcher.global;
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
            if (self.userData) {
                userData = self.userData;
                return;
            }

            NSString *username = [UAKeychainUtils getUsername:self.config.appKey];
            NSString *password = [UAKeychainUtils getPassword:self.config.appKey];

            if (username && password) {
                self.userData = userData = [UAUserData dataWithUsername:username password:password];
            }
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
    UA_WEAKIFY(self)
    [self getUserData:^(UAUserData *savedData) {
        UA_STRONGIFY(self)
        if (!savedData) {
            // No username object stored in the keychain for this app, so let's create it
            if (![UAKeychainUtils createKeychainValueForUsername:data.username withPassword:data.password forIdentifier:self.config.appKey]) {
                UA_LERR(@"Save failed: unable to create keychain for username.");
                return completionHandler(NO);
            }
        }

        @synchronized (self) {
            self.userData = data;

            // Update keychain with latest username and password
            [UAKeychainUtils updateKeychainValueForUsername:data.username
                                               withPassword:data.password
                                              forIdentifier:self.config.appKey];
        }

        completionHandler(YES);
    }];
}

- (void)clearUser {
    UA_WEAKIFY(self)
    [self.backgroundDispatcher doSync:^{
        UA_STRONGIFY(self)
        UA_LDEBUG(@"Deleting the keychain credentials");
        @synchronized (self) {
            [UAKeychainUtils deleteKeychainValue:self.config.appKey];
            self.userData = nil;
        }
    }];
}

@end
