/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

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

#import "UAUser.h"
#import "UAUser+Internal.h"
#import "UAUserAPIClient.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAGlobal.h"
#import "UAUtils.h"
#import "UAKeychainUtils.h"
#import "UA_SBJSON.h"

static UAUser *_defaultUser;

@interface UAUser()

@property(nonatomic, retain) UAUserAPIClient *apiClient;
@property(nonatomic, assign) BOOL initialized;
@property(nonatomic, copy) NSString *username;
@property(nonatomic, copy) NSString *password;
@property(nonatomic, copy) NSString *url;
@property(nonatomic, assign) UAUserState userState;
@property(nonatomic, assign) BOOL isObservingDeviceToken;
//creation flag
@property(nonatomic, assign) BOOL creatingUser;

@end

@implementation UAUser

// UAUser
@synthesize username;
@synthesize password;
@synthesize url;
@synthesize userState;

+ (UAUser *)defaultUser {
    @synchronized(self) {
        if(_defaultUser == nil) {
            _defaultUser = [[UAUser alloc] init];
        }
    }
    return _defaultUser;
}

+ (void)setDefaultUsername:(NSString *)defaultUsername withPassword:(NSString *)defaultPassword {
    
    NSString *storedUsername = [UAKeychainUtils getUsername:[[UAirship shared] appId]];
    
	// If the keychain username is present a user already exists, if not, save
	if (storedUsername == nil) {
        //Store un/pw
        [UAKeychainUtils createKeychainValueForUsername:defaultUsername withPassword:defaultPassword forIdentifier:[[UAirship shared] appId]];
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
    }
    
    return self;
}

#pragma mark -
#pragma mark Device Token

- (NSString*)serverDeviceToken {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kLastUpdatedDeviceTokenKey];
}

- (void)setServerDeviceToken:(NSString *)token {
    // Lowercase the string here because the server will send an upper case string, and we are parsing tokens
    // out of responses
    [[NSUserDefaults standardUserDefaults] setValue:[token lowercaseString] forKey:kLastUpdatedDeviceTokenKey];
}

- (BOOL)deviceTokenHasChanged {
    NSString *lastUpdatedToken = [self serverDeviceToken];
    NSString *currentDeviceToken = [[UAPush shared] deviceToken];
    // Can't use caseInsensitiveCompare, these values can be nil, which is an undefined result
    return ![[lastUpdatedToken lowercaseString] isEqualToString:[currentDeviceToken lowercaseString]];
}

- (void)initializeUser {
    
    @synchronized(self) {
        
        if (self.initialized) {
            return;
        }
        
        if (![UAirship shared].ready) {
            return;
        }
                
        NSString *storedUsername = [UAKeychainUtils getUsername:[[UAirship shared] appId]];
        NSString *storedPassword = [UAKeychainUtils getPassword:[[UAirship shared] appId]];
        
        if (storedUsername != nil && storedPassword != nil) {
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

// TODO: better user state representation
- (void)loadUser {

    if (self.creatingUser) {
        // if we're creating a user, do not load anything now
        // everything relevant has already beenloaded
        // and we don't want to step on the in-progress creation
        return;
    }

    // First thing we need to do is make sure we have a valid User.

    if (username != nil && password != nil) {
        // If the user and password are set, then we are not in a "no user"/"initial run" case - just set it in defaults
        // for the app to access with a Settings bundle
        [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"ua_user_id"];
    } else {
        // Either the user or password is not set, so the "no user"/"initial run" case is still true, try to recreate the user
        [self createUser];
    }

    [self updateUserState];
}

#pragma mark -
#pragma mark Update/Save User Data

/*
 saveUserData - Saves all the existing password and username data to disk.
 It then calls updateUserState to make sure the proper state is selected
 and then notifies all observers.
 */
- (void)saveUserData {
    
    [self updateUserState];
    
    NSString *storedUsername = [UAKeychainUtils getUsername:[[UAirship shared] appId]];
		
    if (!storedUsername) {
		// No username object stored in the keychain for this app, so let's create it
		// but only if we indeed have a username and password to store
		if (username != nil && password != nil) {
			[UAKeychainUtils createKeychainValueForUsername:self.username withPassword:self.password forIdentifier:[[UAirship shared] appId]];
		} else {
            UA_LINFO(@"Save failed: must have a username and password.");
            return;
        }
	}
    
    //Update keychain with latest username and password
    [UAKeychainUtils updateKeychainValueForUsername:self.username
                                       withPassword:self.password
                                      forIdentifier:[[UAirship shared] appId]];
    
    NSDictionary *dictionary = [[NSUserDefaults standardUserDefaults] objectForKey:[[UAirship shared] appId]];
    NSMutableDictionary *userDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionary];
    
    if (userDictionary == nil) {
        userDictionary = [NSMutableDictionary dictionary];
    }

    
    [userDictionary setValue:self.url forKey:kUserUrlKey];
    
    // Save in defaults for access with a Settings bundle
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"ua_user_id"];
    
    [[NSUserDefaults standardUserDefaults] setObject:userDictionary forKey:[[UAirship shared] appId]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)updateUserState {
    if (self.creatingUser) {
        userState = UAUserStateCreating;
    } else if (username == nil || password == nil) {
        userState = UAUserStateEmpty;
    } else {
        userState = UAUserStateCreated;
    }    
}

- (void)notifyObserversUserUpdated {
    [self notifyObservers:@selector(userUpdated)];
}

- (void)notifyObserversUserUpdateFailed {
    [self notifyObservers:@selector(userUpdateFailed)];
}

#pragma mark -
#pragma mark Create

- (BOOL)defaultUserCreated {
    
    if (![UAirship shared].ready) {
        return NO;
    }
    
    NSString *storedUsername = [UAKeychainUtils getUsername:[[UAirship shared] appId]];
	NSString *storedPassword = [UAKeychainUtils getPassword:[[UAirship shared] appId]];
	
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

- (void)createUser {
    
    self.creatingUser = YES;

    [self.apiClient createUserOnSuccess:^(UAUserData *data, NSString *deviceToken) {
        self.creatingUser = NO;
        self.username = data.username;
        self.password = data.password;
        self.url = data.url;

        [self saveUserData];

        if (deviceToken) {
            [self setServerDeviceToken:deviceToken];
        }

        //check to see if the device token has changed, and trigger an update
        [self updateDefaultDeviceToken];
        [self notifyObserversUserUpdated];
    } onFailure:^(UAHTTPRequest *request){
        [UAUtils logFailedRequest:request withMessage:@"UAUser Request"];
        self.creatingUser = NO;
        [self updateUserState];
        [self notifyObserversUserUpdateFailed];
    }];
}

#pragma mark -
#pragma mark Update

-(void)updateDefaultDeviceToken {

    UA_LDEBUG(@"Updating device token.");

    if (![[UAPush shared] deviceToken] || [self deviceTokenHasChanged] == NO || ![self defaultUserCreated]){
		UA_LDEBUG(@"Skipping device token update: no token, already up to date, or user is being updated.");
        return;
    }

    NSString *deviceToken = [[UAPush shared] deviceToken];

    [self.apiClient updateDeviceToken:deviceToken forUsername:self.username onSuccess:^(NSString *token) {
        // Cache the token, even if it's nil, because we may have uploaded a nil token on purpose
        [self setServerDeviceToken:token];
        UA_LDEBUG(@"Logged last updated key %@", token);
        [self notifyObserversUserUpdated];
    } onFailure:^(UAHTTPRequest *request) {
        [self notifyObserversUserUpdateFailed];
    }];
}

#pragma mark -
#pragma mark Device Token Listener

// Ensure the methods that need token are invoked even after inbox was created
- (void)listenForDeviceTokenReg {
    
    UA_LDEBUG(@"ListenForDeviceTokenReg");
    
    if (self.isObservingDeviceToken) {
        return;
    }
    
    // If the device token is already available just update it
    if([UAPush shared].deviceToken != nil) {
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
    
    if ( [keyPath isEqualToString:@"deviceToken"] ) {
        UA_LDEBUG(@"KVO device token modified");
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
