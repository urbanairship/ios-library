/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAUser+Internal.h"
#import "UAUserData+Internal.h"
#import "UAUserAPIClient+Internal.h"
#import "UAPush.h"
#import "UAUtils.h"
#import "UAConfig.h"
#import "UAKeychainUtils+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAirship.h"

NSString * const UAUserCreatedNotification = @"com.urbanairship.notification.user_created";

@interface UAUser()
@property (nonatomic, strong) UAPush *push;
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithPush:(UAPush *)push config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.config = config;
        self.apiClient = [UAUserAPIClient clientWithConfig:config];
        self.dataStore = dataStore;
        self.push = push;


        NSString *storedUsername = [UAKeychainUtils getUsername:self.config.appKey];
        NSString *storedPassword = [UAKeychainUtils getPassword:self.config.appKey];

        if (storedUsername && storedPassword) {
            self.username = storedUsername;
            self.password = storedPassword;
            [[NSUserDefaults standardUserDefaults] setObject:self.username forKey:@"ua_user_id"];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(channelCreated)
                                                     name:UAChannelCreatedEvent
                                                   object:nil];
    }
    
    return self;
}

+ (instancetype)userWithPush:(UAPush *)push config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAUser alloc] initWithPush:push config:config dataStore:dataStore];
}

#pragma mark -
#pragma mark Update/Save User Data

/*
 saveUserData - Saves all the existing password and username data to disk.
 */
- (void)saveUserData {

    NSString *storedUsername = [UAKeychainUtils getUsername:self.config.appKey];

    if (!storedUsername) {

        // No username object stored in the keychain for this app, so let's create it
        // but only if we indeed have a username and password to store
        if (self.username != nil && self.password != nil) {
            if (![UAKeychainUtils createKeychainValueForUsername:self.username withPassword:self.password forIdentifier:self.config.appKey]) {
                UA_LERR(@"Save failed: unable to create keychain for username.");
                return;
            }
        } else {
            UA_LDEBUG(@"Save failed: must have a username and password.");
            return;
        }
    }
    
    // Update keychain with latest username and password
    [UAKeychainUtils updateKeychainValueForUsername:self.username
                                       withPassword:self.password
                                      forIdentifier:self.config.appKey];
    
    NSDictionary *dictionary = [self.dataStore objectForKey:self.config.appKey];
    NSMutableDictionary *userDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionary];

    [userDictionary setValue:self.url forKey:kUserUrlKey];


    // Save in defaults for access with a Settings bundle
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.username forKey:@"ua_user_id"];
    [defaults setObject:userDictionary forKey:self.config.appKey];
    [defaults synchronize];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:UAUserCreatedNotification object:nil];
}

- (void)createUser {

    if (!self.push.channelID) {
        UA_LDEBUG(@"Skipping user creation, no channel");
        return;
    }

    if (self.isCreated) {
        UA_LDEBUG(@"User already created");
        return;
    }

    __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
        [self.apiClient cancelAllRequests];
    }];

    if (backgroundTask == UIBackgroundTaskInvalid) {
        UA_LDEBUG(@"Unable to create background task to create user.");
        return;
    }

    self.creatingUser = YES;

    UAUserAPIClientCreateSuccessBlock success = ^(UAUserData *data, NSDictionary *payload) {
        UA_LINFO(@"Created user %@.", data.username);

        self.creatingUser = NO;
        self.username = data.username;
        self.password = data.password;
        self.url = data.url;

        [self saveUserData];

        // if we didn't send a channel on creation, try again
        if (![payload valueForKey:@"ios_channels"]) {
            [self updateUser];
        }

        [self sendUserCreatedNotification];
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
    };

    UAUserAPIClientFailureBlock failure = ^(NSUInteger statusCode) {
        UA_LINFO(@"Failed to create user");
        self.creatingUser = NO;
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
    };

    [self.apiClient createUserWithChannelID:self.push.channelID
                                  onSuccess:success
                                  onFailure:failure];
}

#pragma mark -
#pragma mark Update

-(void)updateUser {
    if (!self.isCreated) {
        UA_LDEBUG(@"Skipping user update, user not created yet.");
        return;
    }

    if (!self.push.channelID.length) {
        UA_LDEBUG(@"Skipping user update, no channel.");
        return;
    }

    __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
        [self.apiClient cancelAllRequests];
    }];

    if (backgroundTask == UIBackgroundTaskInvalid) {
        UA_LDEBUG(@"Unable to create background task to update user.");
        return;
    }

    UA_LTRACE(@"Updating user");
    [self.apiClient updateUser:self
                     channelID:self.push.channelID
                     onSuccess:^{
                         UA_LINFO(@"Updated user %@ successfully.", self.username);
                         [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
                         backgroundTask = UIBackgroundTaskInvalid;
                     }
                     onFailure:^(NSUInteger statusCode) {
                         UA_LDEBUG(@"Failed to update user.");
                         [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
                         backgroundTask = UIBackgroundTaskInvalid;
                     }];

}

- (void)channelCreated {
    // Update the user if we already have a channelID
    if (self.push.channelID) {
        if (self.isCreated) {
            [self updateUser];
        } else {
            [self createUser];
        }
    }
}

@end
