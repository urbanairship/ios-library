/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UAUserAPIClient.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAGlobal.h"
#import "UAUtils.h"
#import "UAConfig.h"
#import "UAKeychainUtils.h"


static UAUser *_defaultUser;

NSString * const UAUserCreatedNotification = @"com.urbanairship.notification.user_created";



@implementation UAUser

+ (UAUser *)defaultUser {
    @synchronized(self) {
        if(_defaultUser == nil) {
            _defaultUser = [[UAUser alloc] init];
            UA_LTRACE(@"Initialized default user.");
        }
    }
    return _defaultUser;
}

+ (void)setDefaultUsername:(NSString *)defaultUsername withPassword:(NSString *)defaultPassword {

    NSString *storedUsername = [UAKeychainUtils getUsername:[UAirship shared].config.appKey];
    
    // If the keychain username is present a user already exists, if not, save
    if (storedUsername == nil) {
        //Store un/pw
        [UAKeychainUtils createKeychainValueForUsername:defaultUsername withPassword:defaultPassword forIdentifier:[UAirship shared].config.appKey];
    }
    
}


+ (void)land {
    if (_defaultUser) {
        [_defaultUser unregisterForDeviceRegistrationChanges];
    }
    
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // init
        self.apiClient = [UAUserAPIClient client];
    }
    
    return self;
}

- (void)initializeUser {
    
    @synchronized(self) {
        
        if (self.initialized) {
            return;
        }
        
        if (![UAirship shared].ready) {
            return;
        }

        if (!self.appKey) {
            UA_LERR(@"No App Key was set on UAUser. Unable to initialize.");
            UA_LERR("[UAirship takeOff] has probably not been called yet or is being called after application:didFinishLaunchingWithOptions: has returned");
            return;
        }
                
        NSString *storedUsername = [UAKeychainUtils getUsername:self.appKey];
        NSString *storedPassword = [UAKeychainUtils getPassword:self.appKey];
        
        if (storedUsername && storedPassword) {
            self.username = storedUsername;
            self.password = storedPassword;
        }
        
        // Boot strap
        [self loadUser];
        
        [self performSelector:@selector(registerForDeviceRegistrationChanges) withObject:nil afterDelay:0];


        self.initialized = YES;
        self.userUpdateBackgroundTask = UIBackgroundTaskInvalid;
    }
}

#pragma mark -
#pragma mark Load

- (void)loadUser {

    if (self.creatingUser) {
        // if we're creating a user, do not load anything now
        // everything relevant has already been loaded
        // and we don't want to step on the in-progress creation
        return;
    }

    // First thing we need to do is make sure we have a valid User.

    if (self.username && self.password ) {
        // If the user and password are set, then we are not in a "no user"/"initial run" case - just set it in defaults
        // for the app to access with a Settings bundle
        [[NSUserDefaults standardUserDefaults] setObject:self.username forKey:@"ua_user_id"];
    } else {
        // Either the user or password is not set, so the "no user"/"initial run" case is still true, try to recreate the user
        [self createUser];
    }
}

#pragma mark -
#pragma mark Update/Save User Data

/*
 saveUserData - Saves all the existing password and username data to disk.
 */
- (void)saveUserData {

    NSString *storedUsername = [UAKeychainUtils getUsername:self.appKey];

    if (!storedUsername) {

        // No username object stored in the keychain for this app, so let's create it
        // but only if we indeed have a username and password to store
        if (self.username != nil && self.password != nil) {
            if (![UAKeychainUtils createKeychainValueForUsername:self.username withPassword:self.password forIdentifier:self.appKey]) {
                UA_LERR(@"Save failed: unable to create keychain for username.");
                return;
            }
        } else {
            UA_LDEBUG(@"Save failed: must have a username and password.");
            return;
        }
    }
    
    //Update keychain with latest username and password
    [UAKeychainUtils updateKeychainValueForUsername:self.username
                                       withPassword:self.password
                                      forIdentifier:self.appKey];
    
    NSDictionary *dictionary = [[NSUserDefaults standardUserDefaults] objectForKey:self.appKey];
    NSMutableDictionary *userDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionary];

    [userDictionary setValue:self.url forKey:kUserUrlKey];
    
    // Save in defaults for access with a Settings bundle
    [[NSUserDefaults standardUserDefaults] setObject:self.username forKey:@"ua_user_id"];
    
    [[NSUserDefaults standardUserDefaults] setObject:userDictionary forKey:self.appKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark -
#pragma mark Create

- (BOOL)defaultUserCreated {
    
    if (![UAirship shared].ready) {
        return NO;
    }
    
    NSString *storedUsername = [UAKeychainUtils getUsername:self.appKey];
    NSString *storedPassword = [UAKeychainUtils getPassword:self.appKey];

    if (storedUsername == nil || storedPassword == nil) {
        return NO;
    }

    //check for empty values
    if ([storedUsername isEqualToString:@""] || [storedPassword isEqualToString:@""]) {
        return NO;
    }

    return YES;
}

- (void)createDefaultUser {
    if ([self defaultUserCreated]) {
        return;
    }
    [self createUser];
}

- (void)sendUserCreatedNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:UAUserCreatedNotification object:nil];
}

- (void)createUser {
    self.creatingUser = YES;


    UAUserAPIClientCreateSuccessBlock success = ^(UAUserData *data, NSDictionary *payload) {
        UA_LINFO(@"Created user %@.", data.username);

        self.creatingUser = NO;
        self.username = data.username;
        self.password = data.password;
        self.url = data.url;

        [self saveUserData];

        //if we didnt send a device token or a channel on creation, try again
        if (![payload valueForKey:@"device_tokens"] || ![payload valueForKey:@"ios_channels"]) {
            [self updateUser];
        }

        [self sendUserCreatedNotification];
    };

    UAUserAPIClientFailureBlock failure = ^(UAHTTPRequest *request) {
        UA_LINFO(@"Failed to create user");
        self.creatingUser = NO;
    };


    [self.apiClient createUserWithChannelID:[UAPush shared].channelID
                                deviceToken:[UAPush shared].deviceToken
                                  onSuccess:success
                                  onFailure:failure];
}

#pragma mark -
#pragma mark Update

-(void)updateUser {

    NSString *deviceToken = [UAPush shared].deviceToken;
    NSString *channelID = [UAPush shared].channelID;

    if (![self defaultUserCreated]) {
        UA_LDEBUG(@"Skipping user update, user not created yet.");
        return;
    }

    if (!channelID && !deviceToken) {
        UA_LDEBUG(@"Skipping user update, no device token or channel.");
        return;
    }


    if (self.userUpdateBackgroundTask == UIBackgroundTaskInvalid) {
        self.userUpdateBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [self invalidateUserUpdateBackgroundTask];
        }];
    }

    [self.apiClient updateUser:self.username
                   deviceToken:deviceToken
                     channelID:channelID
                     onSuccess:^{
                         UA_LINFO(@"Updated user %@ successfully.", self.username);
                         [self invalidateUserUpdateBackgroundTask];
                     }
                     onFailure:^(UAHTTPRequest *request) {
                         UA_LDEBUG(@"Failed to update user.");
                         [self invalidateUserUpdateBackgroundTask];
                     }];
}

- (void)invalidateUserUpdateBackgroundTask {
    if (self.userUpdateBackgroundTask != UIBackgroundTaskInvalid) {
        UA_LTRACE(@"Ending user update background task %lu.", (unsigned long)self.userUpdateBackgroundTask);

        [[UIApplication sharedApplication] endBackgroundTask:self.userUpdateBackgroundTask];
        self.userUpdateBackgroundTask = UIBackgroundTaskInvalid;
    }
}

- (NSString *)appKey {
    return [UAirship shared].config.appKey;
}

#pragma mark -
#pragma mark Device Token Listener

- (void)registerForDeviceRegistrationChanges {
    if (self.isObservingDeviceRegistrationChanges) {
        return;
    }
    
    self.isObservingDeviceRegistrationChanges = YES;

    // Listen for changes to the device token and channel ID
    [[UAPush shared] addObserver:self forKeyPath:@"deviceToken" options:0 context:NULL];
    [[UAPush shared] addObserver:self forKeyPath:@"channelID" options:0 context:NULL];

    // Update the user if we already have a channelID or device token
    if ([UAPush shared].deviceToken || [UAPush shared].channelID) {
        [self updateUser];
        return;
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context {
    
    if ([keyPath isEqualToString:@"deviceToken"]) {
        // Only update user if we do not have a channel ID
        if (![UAPush shared].channelID) {
            UA_LTRACE(@"KVO device token modified. Updating user.");
            [self updateUser];
        }
    } else if ([keyPath isEqualToString:@"channelID"]) {
        UA_LTRACE(@"KVO channel ID modified. Updating user.");
        [self updateUser];
    }
}

-(void)unregisterForDeviceRegistrationChanges {
    if (self.isObservingDeviceRegistrationChanges) {
        [[UAPush shared] removeObserver:self forKeyPath:@"deviceToken"];
        [[UAPush shared] removeObserver:self forKeyPath:@"channelID"];
        self.isObservingDeviceRegistrationChanges = NO;
    }
}

@end
