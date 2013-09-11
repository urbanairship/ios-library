/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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
#import "UA_SBJSON.h"


static UAUser *_defaultUser;

NSString * const UAUserCreatedNotification = @"com.urbanairship.notification.user_created";



@implementation UAUser

+ (UAUser *)defaultUser {
    @synchronized(self) {
        if(_defaultUser == nil) {
            _defaultUser = [[UAUser alloc] init];
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

- (void)dealloc {
    self.username = nil;
    self.password = nil;
    self.url = nil;
    self.apiClient = nil;
    [super dealloc];
}

+ (void)land {

    if (_defaultUser) {
        [_defaultUser cancelListeningForDeviceToken];
    }
    
}

- (id)init {
    self = [super init];
    if (self) {
        // init
        self.apiClient = [[[UAUserAPIClient alloc] init] autorelease];
        self.appKey = [UAirship shared].config.appKey;
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
                
        NSString *storedUsername = [UAKeychainUtils getUsername:self.appKey];
        NSString *storedPassword = [UAKeychainUtils getPassword:self.appKey];
        
        if (storedUsername && storedPassword) {
            self.username = storedUsername;
            self.password = storedPassword;
        }
        
        // Boot strap
        [self loadUser];
        
        [self performSelector:@selector(listenForDeviceTokenReg) withObject:nil afterDelay:0];
        
        self.initialized = YES;
                
    }
}

#pragma mark -
#pragma mark Load

- (void)loadUser {

    if (self.creatingUser) {
        // if we're creating a user, do not load anything now
        // everything relevant has already beenloaded
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
        
    NSString *storedUsername = [UAKeychainUtils getUsername:[UAirship shared].config.appKey];

    if (!storedUsername) {
        // No username object stored in the keychain for this app, so let's create it
        // but only if we indeed have a username and password to store
        if (self.username != nil && self.password != nil) {
            [UAKeychainUtils createKeychainValueForUsername:self.username withPassword:self.password forIdentifier:self.appKey];
        } else {
            UA_LINFO(@"Save failed: must have a username and password.");
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
    
    [[NSUserDefaults standardUserDefaults] setObject:userDictionary forKey:[UAirship shared].config.appKey];
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

    [self.apiClient createUserOnSuccess:^(UAUserData *data, NSString *sentDeviceToken) {
        self.creatingUser = NO;
        self.username = data.username;
        self.password = data.password;
        self.url = data.url;

        [self saveUserData];

        //if we didnt send a token up on creation, try updating now
        if (!sentDeviceToken) {
            [self updateDefaultDeviceToken];
        }

        [self sendUserCreatedNotification];

    } onFailure:^(UAHTTPRequest *request){
        [UAUtils logFailedRequest:request withMessage:@"UAUser Request"];
        self.creatingUser = NO;
    }];
}

#pragma mark -
#pragma mark Update

-(void)updateDefaultDeviceToken {
    if (![UAPush shared].deviceToken || ![self defaultUserCreated]){
        UA_LDEBUG(@"Skipping device token update: no token, already up to date, or user is being updated.");
        return;
    }

    NSString *deviceToken = [UAPush shared].deviceToken;

    [self.apiClient updateDeviceToken:deviceToken forUsername:self.username onSuccess:^(NSString *updatedToken) {
        UA_LINFO(@"Device token updated to: %@", updatedToken);
    } onFailure:^(UAHTTPRequest *request) {
        UA_LDEBUG(@"Device token update failed with status: %ld", (long)request.response.statusCode);
    }];
}

#pragma mark -
#pragma mark Device Token Listener

// Ensure the methods that need token are invoked even after inbox was created
- (void)listenForDeviceTokenReg {
    if (self.isObservingDeviceToken) {
        return;
    }
    
    // If the device token is already available just update it
    if([UAPush shared].deviceToken) {
        [self cancelListeningForDeviceToken];
        [self updateDefaultDeviceToken];
        return;
    }
    
    // Listen for changes to the device token
    self.isObservingDeviceToken = YES;
    [[UAPush shared] addObserver:self forKeyPath:@"deviceToken" options:0 context:NULL];
    
    // Double check here incase we managed to recieve the token the same
    // moment we registered the KVO
    if([UAPush shared].deviceToken != nil) {
        [self cancelListeningForDeviceToken];
        [self updateDefaultDeviceToken];
        return;
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context {
    
    if ([keyPath isEqualToString:@"deviceToken"]) {
        UA_LTRACE(@"KVO device token modified.");
        [self cancelListeningForDeviceToken];
        [self updateDefaultDeviceToken];
    }
}

-(void)cancelListeningForDeviceToken {
    if (self.isObservingDeviceToken) {
        [[UAPush shared] removeObserver:self forKeyPath:@"deviceToken"];
        self.isObservingDeviceToken = NO;
    }
}

@end
