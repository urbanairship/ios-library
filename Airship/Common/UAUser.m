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
#import "UAirship.h"
#import "UAPush.h"
#import "UAGlobal.h"
#import "UAUtils.h"
#import "UAKeychainUtils.h"
#import "UA_ASIHTTPRequest.h"
#import "UA_SBJSON.h"

static UAUser *_defaultUser;

@implementation UAUser

// UAUser()
@synthesize deviceTokenHasChanged = _deviceTokenHasChanged;
@synthesize deviceToken = _deviceToken;

// UAUser
@synthesize username;
@synthesize password;
@synthesize email;
@synthesize recoveryEmail;
@synthesize url;
@synthesize alias;
@synthesize tags;
@synthesize userState;
@synthesize recoveryStatusUrl;
@synthesize recoveryStarted;
@synthesize inRecovery;
@synthesize retrievingUser;
@synthesize sentRecoveryEmail;
@synthesize recoveryPoller;

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
    RELEASE_SAFELY(recoveryStatusUrl);
    RELEASE_SAFELY(username);
    RELEASE_SAFELY(password);
    RELEASE_SAFELY(email);
    RELEASE_SAFELY(recoveryEmail);
    RELEASE_SAFELY(url);
    RELEASE_SAFELY(alias);
    RELEASE_SAFELY(tags);
    RELEASE_SAFELY(recoveryPoller);
    
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
        // no action required for now..
    }
    
    return self;
}

#pragma mark -
#pragma mark Device Token Set

- (void)setDeviceToken:(NSString *)deviceToken {
    [_deviceToken release];
    _deviceToken = deviceToken;
    NSString *lastDeviceToken = [[NSUserDefaults standardUserDefaults] stringForKey:kLastDeviceTokenKey];
    if (![_deviceToken isEqualToString:lastDeviceToken]) {
        _deviceTokenHasChanged = YES;
        [[NSUserDefaults standardUserDefaults] setValue:_deviceToken forKey:kLastDeviceTokenKey];
    }
}

- (void)initializeUser {
    
    @synchronized(self) {
        
        if (initialized) {
            return;
        }
        
        if (![UAirship shared].ready) {
            return;
        }
        
        [self migrateUser];
        
        NSString *storedUsername = [UAKeychainUtils getUsername:[[UAirship shared] appId]];
        NSString *storedPassword = [UAKeychainUtils getPassword:[[UAirship shared] appId]];
        
        if (storedUsername != nil && storedPassword != nil) {
            self.username = storedUsername;
            self.password = storedPassword;
        }
        
        // Boot strap - including processing our user recovery status
        [self loadUser];
        
        [self performSelector:@selector(listenForDeviceTokenReg) withObject:nil afterDelay:0];
        
        initialized = YES;
                
    }
}

- (void)migrateUser {
    
    //check for old inbox and subscription keys in user dictionary
    //if they don't have stored values, return
    //if there are existing values, save to keychain, then remove from user dictionary
    
    // Local dict ref for handling recovery state
    NSMutableDictionary *userDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:[[UAirship shared] appId]];
    UALOG(@"Migrating User Info: %@", userDictionary);
    if (userDictionary == nil) {
        return;
    }
    
    //Check for an existing UAInboxMessageList user first
    NSString *existingUsername = [userDictionary objectForKey:kLegacyInboxUserKey];
    NSString *existingPassword = [userDictionary objectForKey:kLegacyInboxPassKey];
    
    //If there's not an UAInboxMessageList user, check for a Subscriptions user
    if (existingUsername == nil && existingPassword == nil) {
        existingUsername = [userDictionary objectForKey:kLegacySubscriptionsUserKey];
        existingPassword = [userDictionary objectForKey:kLegacySubscriptionsPassKey];
    }
    
    if (existingUsername != nil && existingPassword != nil) {
        
        UALOG(@"Migrating user to keychain with username=%@ and password=%@", existingUsername, existingPassword);
        
        // The Username has changed. This only happens in Recovery.
        // So now we need to delete the keychain and recreate it.
        [UAKeychainUtils deleteKeychainValue:[[UAirship shared] appId]];
        [UAKeychainUtils createKeychainValueForUsername:existingUsername withPassword:existingPassword forIdentifier:[[UAirship shared] appId]];
        
        //Remove old values and save
        [userDictionary removeObjectForKey:kLegacyInboxUserKey];
        [userDictionary removeObjectForKey:kLegacyInboxPassKey];
        [userDictionary removeObjectForKey:kLegacySubscriptionsUserKey];
        [userDictionary removeObjectForKey:kLegacySubscriptionsPassKey];
    }
    
    // Migrate subscription recovery keys to new keychain store
    // kLegacySubscriptionsEmailKey -> keychain
    NSString *existingEmail = [userDictionary objectForKey:kLegacySubscriptionsEmailKey];
    if (existingEmail != nil) {
        UALOG(@"Migrating email address '%@' to keychain", existingEmail);
        [UAKeychainUtils updateKeychainValueForUsername:[UAKeychainUtils getUsername:[[UAirship shared] appId]] 
                                           withPassword:[UAKeychainUtils getPassword:[[UAirship shared] appId]] 
                                       withEmailAddress:existingEmail
                                          forIdentifier:[[UAirship shared] appId]];
        [userDictionary removeObjectForKey:kLegacySubscriptionsEmailKey];
    }
    
    // Migrate from UAInboxMessageList keys to new UAUser keys
    // kLegacyInboxAliasKey to kAliasKey
    NSObject *existingAlias = [userDictionary objectForKey:kLegacyInboxAliasKey];
    if (existingAlias != nil) {
        [userDictionary setObject:existingAlias forKey:kAliasKey];
        [userDictionary removeObjectForKey:kLegacyInboxAliasKey];
    }
    
    // kLegacyInboxTagsKey to kTagsKey
    NSObject *existingTags = [userDictionary objectForKey:kLegacyInboxTagsKey];
    if (existingTags != nil) {
        [userDictionary setObject:existingTags forKey:kTagsKey];
        [userDictionary removeObjectForKey:kLegacyInboxTagsKey];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:userDictionary forKey:[[UAirship shared] appId]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
}

#pragma mark -
#pragma mark Load

// TODO: better user state representation
- (void)loadUser {

    if (creatingUser) {
        // if we're creating a user, do not load anything now
        // everything relevant has already beenloaded
        // and we don't want to step on the in-progress creation
        return;
    }

	self.retrievingUser = NO;
    self.email = [UAKeychainUtils getEmailAddress:[[UAirship shared] appId]];
    
    // Local dict ref for handling recovery state
    NSMutableDictionary *userDictionary = [[NSUserDefaults standardUserDefaults] objectForKey:[[UAirship shared] appId]];
    UALOG(@"User Info: %@", userDictionary);
    
    if (userDictionary == nil && username != nil && password != nil) {
        //this is likely the first run after the app was uninstalled, then reinstalled, wiping the defaults dictionary
        //retrieve the user from the server, but drop it in the run queue so that it will not run on init
        [self performSelector:@selector(retrieveUser) withObject:nil afterDelay:0];
        return;
    }

    self.recoveryEmail = [userDictionary objectForKey:kRecoveryEmail];
    self.alias = [userDictionary objectForKey:kAliasKey];
    self.url = [userDictionary objectForKey:kUserUrlKey];
    self.tags = [NSMutableSet setWithArray:[userDictionary objectForKey:kTagsKey]];
    
    // Let's start out assuming that we do not need to recover an account's subscription data
    // self.inRecovery is the recovery state from the previous run, it will only be YES if a recovery process previously started and is not done
    //      This is saved out with a call to saveUserData.
    // self.recoveryStarted is the current session state, start with NO right now

    self.inRecovery = [(NSNumber*)[userDictionary objectForKey: kUserRecoveryKey] boolValue];
    self.sentRecoveryEmail = [(NSNumber*)[userDictionary objectForKey: kAlreadySentUserRecoveryEmail] boolValue];
    self.recoveryStatusUrl = [userDictionary objectForKey:kUserRecoveryStatusURL];
    self.recoveryStarted = NO;

    // First thing we need to do is make sure we have a valid User.

    if (username != nil && password != nil) {
        // If the user and password are set, then we are not in a "no user"/"initial run" case - just set it in defaults
        // for the app to access with a Settings bundle
        [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"ua_user_id"];
    } else {
        // Either the user or password is not set, so the "no user"/"initial run" case is still true, try to recreate the user

        // If we're in a startup recovery case with email only (no User/Pass), we shouldn't run createUser every time - it functions but
        // generates a lot of extra recovery emails which is not ideal/is confusing
        if (!self.inRecovery) {
            [self createUser];
        }
    }

    // Now, we have a good User object, let's figure out our recovery status
    if (self.recoveryStarted == NO && self.inRecovery == YES) {
        // If we have previously been in a recovery process (on a prior run) we have to finish it. It is not finished until .inRecovery == NO

        // We only want to make this call if we have yet to send the email - otherwise we want to skip straight to the logic in "(void)recoveryStarted:"
        // and begin polling for a response to the previously sent email - need some UI Chrome to handle this, and the option to restart the whole process
        // thus sending a new email.
        if (self.sentRecoveryEmail) {

            // User has already entered recovery at some point and did not finish, but got as far as having the email sent
            self.recoveryStarted = YES;
            self.sentRecoveryEmail = YES;
            [self saveUserData];
            [self startRecoveryPoller];
            
        } else {
            // Begin the recovery process from the beginning
            [self startRecovery];
        }
    } else {
        // The previous run either finished the recovery process or never started one, safe to just update the User Status
        [self updateUserState];
    }
}

#pragma mark -
#pragma mark Update/Save User Data

/*
 saveUserData - Saves all the existing password, username, email, and recovery data to disk.
 It then calls updateUserState to make sure the proper state is selected vis a vis email/password
 and then notifies all observers.
 */
- (void)saveUserData {
    
    [self updateUserState];
    
    NSString *storedUsername = [UAKeychainUtils getUsername:[[UAirship shared] appId]];
    
	// Handle cases where the username changed, or was just created
	if (storedUsername != nil) {
		
        if(![storedUsername isEqualToString:username]) {        
            // The Username has changed. This only happens in Recovery.
            // So now we need to delete the keychain and recreate it.
            [UAKeychainUtils deleteKeychainValue:[[UAirship shared] appId]];
            [UAKeychainUtils createKeychainValueForUsername:self.username withPassword:self.password forIdentifier:[[UAirship shared] appId]];   
        }
		
	} else {
		// No username object stored in the keychain for this app, so let's create it
		// but only if we indeed have a username and password to store
		if (username != nil && password != nil) {
			[UAKeychainUtils createKeychainValueForUsername:self.username withPassword:self.password forIdentifier:[[UAirship shared] appId]];
		} else {
            UALOG(@"Save failed: must have a username and password.");
            return;
        }
	}
    
    //Update keychain with lateset password and email
    [UAKeychainUtils updateKeychainValueForUsername:self.username 
                                       withPassword:self.password
                                   withEmailAddress:self.email 
                                      forIdentifier:[[UAirship shared] appId]];
    
    NSDictionary *dictionary = [[NSUserDefaults standardUserDefaults] objectForKey:[[UAirship shared] appId]];
    NSMutableDictionary *userDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionary];
    
    if (userDictionary == nil) {
        userDictionary = [NSMutableDictionary dictionary];
    }
    
    [userDictionary setObject:[NSNumber numberWithBool:self.inRecovery] forKey:kUserRecoveryKey];
    [userDictionary setObject:[NSNumber numberWithBool:self.sentRecoveryEmail] forKey:kAlreadySentUserRecoveryEmail];
    
    //uses setValue:forKey: to auto-remove values that have changed to nil
    [userDictionary setValue:self.recoveryEmail forKey:kRecoveryEmail];
    [userDictionary setValue:self.recoveryStatusUrl forKey:kUserRecoveryStatusURL];
    
    [userDictionary setValue:self.alias forKey:kAliasKey];
    [userDictionary setValue:self.url forKey:kUserUrlKey];
    [userDictionary setValue:[self.tags allObjects] forKey:kTagsKey];
    
    // Save in defaults for access with a Settings bundle
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"ua_user_id"];
    
    [[NSUserDefaults standardUserDefaults] setObject:userDictionary forKey:[[UAirship shared] appId]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)updateUserState {
    if (creatingUser) {
        userState = UAUserStateCreating;
    } else if (username == nil || password == nil) {
        userState = UAUserStateEmpty;
    } else {
        if (email == nil) {
            userState = UAUserStateNoEmail;
        } else {
            userState = UAUserStateWithEmail;
        }
    }
    
    if ((recoveryStarted == YES) && (inRecovery == YES)) {
        userState = UAUserStateInRecovery;
    }
}

- (void)notifyObserversUserUpdated {
    [self notifyObservers:@selector(userUpdated)];
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

- (void)createUserWithEmail:(NSString *)value {
    self.email = value;
    [self createUser];
}

- (void)createUser {
    
    creatingUser = YES;

    NSString *urlString = [NSString stringWithFormat:@"%@%@",
                           [[UAirship shared] server],
                           @"/api/user/"];
	
    NSURL *createUrl = [NSURL URLWithString:urlString];
    UA_ASIHTTPRequest *request = [UAUtils requestWithURL:createUrl
                                               method:@"POST"
                                             delegate:self
                                               finish:@selector(userCreated:)
                                                 fail:@selector(userCreationDidFail:)];

    NSMutableDictionary *data = [self createUserDictionary];

    UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    NSString* body = [writer stringWithObject:data];
    [writer release];
    UALOG(@"Create user with body: %@", body);

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendPostData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request startAsynchronous];
}

- (void)userCreated:(UA_ASIHTTPRequest*)request {
    
    UALOG(@"User created: %d:%@", request.responseStatusCode, request.responseString);

    // done creating! or it failed..
    // wait to update the state enum until the next state is determined below
    creatingUser = NO;

    switch (request.responseStatusCode) {
        case 201://created
        {
            UA_SBJsonParser *parser = [[UA_SBJsonParser alloc] init];
            NSDictionary *result = [parser objectWithString:request.responseString];

            self.username = [result objectForKey:@"user_id"];
            self.password = [result objectForKey:@"password"];
            self.url = [result objectForKey:@"user_url"];
            
            [self saveUserData];
            
            // Make sure we do a full user update with any device tokens, we'll unset this if it is not needed
            self.deviceTokenHasChanged = YES;
            
            // Check for device token. If it was present in the request, it was just updated, so set the flag in Airship
            if (request.postBody != nil) {
                
                NSString *requestString = [[NSString alloc] initWithData:request.postBody encoding:NSUTF8StringEncoding];
                NSDictionary *requestDict = [parser objectWithString:requestString];
                
                [requestString release];
                
                if (requestDict != nil && [requestDict objectForKey:@"device_tokens"] != nil) {
                    
                    // created a user w/ a device token
                    UALOG(@"Created a user with a device token.");
                    
                    NSArray *deviceTokens = [requestDict objectForKey:@"device_tokens"];
                    
                    // get the first item from the request - we will only ever send 1 at most
                    NSString *deviceToken = [deviceTokens objectAtIndex:0];
                    
                    if ([[[[UAPush shared] deviceToken] lowercaseString] isEqualToString:[deviceToken lowercaseString]]) {
                        UALOG(@"Device token is unchanged");
                        
                        self.deviceTokenHasChanged = NO;
                    }
                }
            }
			
            [parser release];
            
            //check to see if the device token has changed, and trigger an update
            [self updateDefaultDeviceToken];
            
            [self notifyObserversUserUpdated];
            break;
        }
        case 409:
        {
            // You will only hit this case if the default user (user with no email) was not created, and the first call to
            // createUser included the email address as a part for the PUT data - usually from settings
            // This means the user is truly unique, and if it exists we'll get a 409, and they should recover.
            self.recoveryEmail = self.email;
            [self startRecovery];
            break;
        }
        default:
        {
            [self updateUserState];
            [self userRequestWentWrong:request];
            break;
        }
    }
}

- (void)userCreationDidFail:(UA_ASIHTTPRequest *)request {
    creatingUser = NO;
    [self updateUserState];
    [self userRequestWentWrong:request];
}

#pragma mark -
#pragma mark Modify

- (BOOL)setUserEmail:(NSString *)address {
    BOOL set = YES;
    if (userState == UAUserStateEmpty) {
        [self createUserWithEmail:address];
    } else if (![email isEqualToString:address]) {
        [self modifyUserWithEmail:address];
    } else {
        set = NO;
    }
    return set;
}

/*
 modifyUserWithNewEmail - called from two places, UASubscriptionSettingsViewController, and locally from purchaseAndRecoverIfNeeded

 setUserEmail: If the user changes their email address manually, we have to save it.
 promptForEmail: if a user buys something (UASubscriptionProductDetailViewController), this prompt is invoked,
 and based on the user clicking OK on the alertView, modifyUserWithNewEmail will be called
 */
- (void)modifyUserWithEmail:(NSString *)value {
    
    self.email = value;
    self.recoveryEmail = value;
    
    //old (PUT) method
    //[self updateUserWithDelegate:self finish:@selector(modifyUserWithEmailUpdated:) fail:@selector(modifyUserWithEmailFailed:)];
    
    NSDictionary *dict;
    
    if(value) {
        dict = [NSDictionary dictionaryWithObject:value forKey:@"email"];
    }
    else {
        dict = [NSDictionary dictionaryWithObject:[NSNull null] forKey:@"email"];
    }
   
    [self updateUserInfo:dict withDelegate:self finish:@selector(modifyUserWithEmailUpdated:) fail:@selector(modifyUserWithEmailFailed:)];  
}

- (void)modifyUserWithEmailFailed:(UA_ASIHTTPRequest*)request {
    
    [UAUtils requestWentWrong:request keyword:@"Modify user with email failed."];
    [self notifyObservers:@selector(userUpdateFailed)];

}

- (void)modifyUserWithEmailUpdated:(UA_ASIHTTPRequest*)request {

    UALOG(@"User updated: %d:%@, URL: %@", request.responseStatusCode,
          request.responseString, [request.url absoluteString]);

    if(request.responseStatusCode == 409) {
        self.email = [UAKeychainUtils getEmailAddress:[[UAirship shared] appId]];
        // Data for this user exists already, so we need to start the recovery flow
        [self startRecovery];

    } else if (request.responseStatusCode == 200) {
        // Need to save user data and also loadSubscriptions
        [self saveUserData];
	
        [self notifyObserversUserUpdated];
    } else {
        [self modifyUserWithEmailFailed:request];
    }

}

#pragma mark -
#pragma mark Recover

- (void)startRecovery {
    
    UALOG(@"Start Recovery");

    self.recoveryStarted = YES;
    self.inRecovery = YES;
    [self saveUserData];

    [self notifyObservers:@selector(userRecoveryStarted)];

    NSString *urlString = [NSString stringWithFormat: @"%@%@",
                           [[UAirship shared] server],
                           @"/api/user/recover/"];

    UA_ASIHTTPRequest *request = [UAUtils requestWithURL:[NSURL URLWithString:urlString]
                                               method:@"POST"
                                             delegate:self
                                               finish:@selector(recoveryRequestSucceeded:)
                                                 fail:@selector(recoveryRequestFailed:)];

    UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    NSDictionary* data = [[NSDictionary alloc] initWithObjectsAndKeys:
                          self.recoveryEmail,
                          @"email",
                          [UAUtils deviceID],
                          @"ua_device_id",
                          nil];

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    NSString* body = [writer stringWithObject:data];

    [request appendPostData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request startAsynchronous];
    [writer release];
    [data release];
    
}

- (void)recoveryRequestSucceeded:(UA_ASIHTTPRequest*)request {

    // Check for an API rejection of the recovery
    if(request.responseStatusCode != 200) {
        [self cancelRecovery];

        [self notifyObservers:@selector(userRecoveryFailed)];

    } else {
        // No API rejection, so we're OK to continue with recovery

        UALOG(@"Recovery Started: %d:%@, URL: %@", request.responseStatusCode,
              request.responseString, [request.url absoluteString]);
        UALOG(@"Request Method: %@", request.requestMethod);

        UA_SBJsonParser *parser = [UA_SBJsonParser new];
        NSDictionary *result = [parser objectWithString: request.responseString];
        self.recoveryStatusUrl = [NSString stringWithString: [result objectForKey: @"recovery_status_url"]];
        [parser release];

        // Need to save a status flag here that we successfully sent the recovery email
        self.recoveryStarted = YES;
        self.sentRecoveryEmail = YES;
        [self saveUserData];
        [self startRecoveryPoller];
    }
}

- (void)recoveryRequestFailed:(UA_ASIHTTPRequest*)request {

    // Send the bad request to error handling
    [self requestWentWrong:request];

    // Request failed, cleanup recovery process
    [self cancelRecovery];

    [self notifyObservers:@selector(userRecoveryFailed)];
}

- (void)cancelRecovery {
    [self stopRecoveryPoller];

    // Make sure emails are cleared out as well as recovery links - this is only called if we're stopping the process
    self.recoveryStarted = NO;
    self.inRecovery = NO;
    self.recoveryEmail = @"";
    self.email = @"";
    self.sentRecoveryEmail = NO;
    self.recoveryStatusUrl = @"";

    [self saveUserData];
}

#pragma mark Recovery Poller

- (void)startRecoveryPoller {
    
    [self stopRecoveryPoller];
    recoveryPoller = [NSTimer scheduledTimerWithTimeInterval: 5
                                                      target: self
                                                    selector: @selector(checkRecoveryStatus:)
                                                    userInfo: nil
                                                     repeats: YES];
    // automatically stop the polling after 3 mins if user didn't click
    // the recover link
    [self performSelector:@selector(stopRecoveryPoller)
               withObject:nil
               afterDelay:60*3];
    
}

- (void)stopRecoveryPoller {
    
    if (recoveryPoller != nil) {
        UALOG(@"Stop recovery polling");
        [recoveryPoller invalidate];
        recoveryPoller = nil;
    }
    
}

- (void)checkRecoveryStatus:(NSTimer *)timer {

    UALOG(@"Checking Recovery Status");
    UALOG(@"recovery status url: %@", self.recoveryStatusUrl);

    UA_ASIHTTPRequest *request = [UAUtils requestWithURL: [NSURL URLWithString: self.recoveryStatusUrl]
                                               method: @"GET"
                                             delegate: self
                                               finish: @selector(recoveryStatusUpdated:)];
    [request startAsynchronous];
}

- (void)recoveryStatusUpdated:(UA_ASIHTTPRequest *)request {

    if (request.responseStatusCode == 200) {

        UA_SBJsonParser *parser = [UA_SBJsonParser new];
        NSDictionary *result = [parser objectWithString: request.responseString];

        [parser release];

        NSString *status = [result objectForKey:@"status"];

        UALOG(@"Status update received: %@", status);
        UALOG(@"Response: %d\n%@\n", request.responseStatusCode,
              request.responseString);

        // Only process this update if it is for status "complete" - meaning the server has registered that the user clicked the recovery link
        if ([status isEqualToString: @"complete"]) {

            // Stop polling.
            [self stopRecoveryPoller];

            // We can only get this far with a completely valid user, so set the state and save this data
            NSDictionary* user_data = [result objectForKey: @"user_data"];
            NSString* user_id = [user_data objectForKey: @"user_id"];
            NSString* pw = [user_data objectForKey: @"password"];
            
            UALOG(@"New U/P: %@/%@", user_id, pw);

            self.username = user_id;
            self.password = pw;
            self.url = [user_data objectForKey:@"user_url"];
            self.email = self.recoveryEmail;
            self.recoveryStatusUrl = @"";
            self.sentRecoveryEmail = NO;
            
            
            //The user's existing tags and alias must now be retrieved
            UA_ASIHTTPRequest *getRequest = [UAUtils userRequestWithURL:[NSURL URLWithString:self.url]
                                                              method:@"GET"
                                                            delegate:nil 
                                                              finish:nil
                                                                fail:nil];
            [getRequest startSynchronous];
			
            if (getRequest.responseStatusCode == 200) {
                
                parser = [UA_SBJsonParser new];
                NSDictionary *getResult = [parser objectWithString:getRequest.responseString];
                [parser release];
                
                UALOG(@"Recover User GET result: %@", [getResult descriptionWithLocale: nil indent: 1]);
                
                self.tags = [NSMutableSet setWithArray:[getResult objectForKey:@"tags"]];
                self.alias = [getResult objectForKey:@"alias"];
                
                // Ensure that the device token is updated if it's available
                NSArray *deviceTokens = [getResult objectForKey:@"device_tokens"];

				if([deviceTokens count] > 0) {
					
					BOOL contains = NO;
					
					// If there are device tokens in the array, check them against the local one, if no match then need to update
					for (NSString *deviceToken in deviceTokens) {

						if ([[UAPush shared] deviceToken] != nil && [[[[UAPush shared] deviceToken] lowercaseString] isEqualToString:[deviceToken lowercaseString]]) {
							contains = YES;
						}
					}
					
					if(!contains) {
						UALOG(@"Device token(s) has changed");
						self.deviceTokenHasChanged = YES;
					}
					
				} else {
					// If there are no device tokens in the array, but we have one locally, need to update
					if([[UAPush shared] deviceToken] != nil) {
						UALOG(@"Device token has changed");
						self.deviceTokenHasChanged = YES;
					}
				}
				
            } else {
                UALOG(@"Get existing alias and tags failed.");
            }
            
            // Current session is now done recovering.
            self.inRecovery = NO;
        
            [self saveUserData];
            
			// Update the default device token - this will do the right thing based on deviceTokenHasChanged status set above
            [self updateDefaultDeviceToken];
			
            // Tell the world that we're done recovering
            [self notifyObservers:@selector(userRecoveryFinished)];
        }
    } else {
        // Send the bad request to error handling
        [self requestWentWrong:request];
    }
}

#pragma mark -
#pragma mark Merge User (Autorenewables)


- (void)didMergeWithUser:(NSDictionary *)userData {
    
    self.username = [userData objectForKey:@"user_id"];
    self.password = [userData objectForKey:@"password"];
    self.url = [userData objectForKey:@"user_url"];
    self.alias = [userData objectForKey:@"alias"];
    self.tags = [userData objectForKey:@"tags"];
    
    [self saveUserData];
}


#pragma mark -
#pragma mark Retrieve User

- (void)retrieveUser {
    self.retrievingUser = YES;
    
    [self notifyObservers:@selector(userRetrieveStarted)];
    
    NSString *retrieveUrlString = [NSString stringWithFormat:@"%@%@%@/",
                                 [[UAirship shared] server],
                                 @"/api/user/",
                                 [self username]];
    
    UA_ASIHTTPRequest *getRequest = [UAUtils userRequestWithURL:[NSURL URLWithString:retrieveUrlString]
                                                         method:@"GET"
                                                       delegate:self 
                                                         finish:@selector(retrieveRequestSucceeded:)
                                                           fail:@selector(retrieveRequestFailed:)];
    [getRequest startAsynchronous];
}

- (void)retrieveRequestSucceeded:(UA_ASIHTTPRequest*)request {
    UALOG(@"User retrieved: %d:%@", request.responseStatusCode, request.responseString);
    
    if (request.responseStatusCode == 200) {
        UA_SBJsonParser *parser = [UA_SBJsonParser new];
        NSDictionary *result = [parser objectWithString:request.responseString];
        
        self.url = [result objectForKey:@"user_url"];
        self.tags = [NSMutableSet setWithArray:[result objectForKey:@"tags"]];
        self.alias = [result objectForKey:@"alias"];
        
        [self saveUserData];
        
        [parser release];
        
        self.retrievingUser = NO;
        
        [self updateUserState];
        
        //check to see if the device token has changed, and trigger an update
        [self updateDefaultDeviceToken];
        
        [self notifyObserversUserUpdated];
        [self notifyObservers:@selector(userRetrieveFinished)];
    } else {
        [self retrieveRequestFailed:request];
    }
}

- (void)retrieveRequestFailed:(UA_ASIHTTPRequest*)request {
    UALOG(@"User retrieval failed: %d:%@", request.responseStatusCode, request.responseString);
    self.retrievingUser = NO;
    
    [self notifyObservers:@selector(userRetrieveFailed)];
    
}

#pragma mark -
#pragma mark HTTP Request Failure Handler

// Default failure handler, set in UAUtils helper function
- (void)requestWentWrong:(UA_ASIHTTPRequest*)request {
    
    [UAUtils requestWentWrong:request];

}

// For observer interested request
- (void)userRequestWentWrong:(UA_ASIHTTPRequest*)request {
    [self requestWentWrong:request];
    [self notifyObservers:@selector(userUpdateFailed)];
}

#pragma mark -
#pragma mark Device Token Listener

// Ensure the methods that need token are invoked even after inbox was created
- (void)listenForDeviceTokenReg {
    
    UALOG(@"ListenForDeviceTokenReg");
    
    if (isObservingDeviceToken) {
        return;
    }
    
    // If the device token is already available just update it
    if([UAPush shared].deviceToken != nil) {
        [self cancelListeningForDeviceToken];
        [self updateDefaultDeviceToken];
        return;
    }
    
    // Listen for changes to the device token
    isObservingDeviceToken = YES;
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
        UALOG(@"KVO device token modified");
        [self cancelListeningForDeviceToken];
        [self updateDefaultDeviceToken];
    }
}

-(void)cancelListeningForDeviceToken {
    if (isObservingDeviceToken) {
        [[UAPush shared] removeObserver:self forKeyPath:@"deviceToken"];
        isObservingDeviceToken = NO;
    }
}

-(void)updateDefaultDeviceToken {
    
    UALOG(@"Updating device token");
    
    self.deviceToken = [[UAPush shared] deviceToken];
    
    if (!_deviceToken || self.deviceTokenHasChanged == NO || self.inRecovery || ![self defaultUserCreated] || self.retrievingUser) {
		UALOG(@"Skipping device token update: no token, already up to date, or user is being updated.");
        return;
    }
    
    //I sure wish there were an easier way to construct dictionaries
    NSDictionary *dict = [NSDictionary dictionaryWithObject:
                          [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:_deviceToken] forKey:@"add"]
                                                     forKey:@"device_tokens"];
    
    [self updateUserInfo:dict withDelegate:self finish:@selector(updatedDefaultDeviceToken:) fail:@selector(requestWentWrong:)];
    
}

- (void)updatedDefaultDeviceToken:(UA_ASIHTTPRequest*)request {
    self.deviceTokenHasChanged = NO;
    UALOG(@"Updated Device Token response: %d", request.responseStatusCode);
}

#pragma mark -
#pragma mark User Update

- (NSMutableDictionary*)createUserDictionary {
 
    //set up basic payload
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                 [UAUtils deviceID], @"ua_device_id", nil ];
    
    [data setValue:self.alias forKey:@"alias"];                             
    [data setValue:self.url forKey:@"user_url"];
    [data setValue:@"true" forKey:@"airmail"];
    
    //if APN hasn't finished yet or is not enabled, don't include the deviceToken
    NSString* deviceToken = [UAPush shared].deviceToken;
	
    if (deviceToken != nil && [deviceToken length] > 0) {
        NSArray *deviceTokens = [NSArray arrayWithObjects:deviceToken, nil];
        [data setObject:deviceTokens forKey:@"device_tokens"];
    }
    
    if (self.email != nil) {
        [data setObject:email forKey:@"email"];
    }
    
    if ([tags count] > 0) {
        [data setObject:[self.tags allObjects] forKey:@"tags"];
    }
    
    [data autorelease];
    
    return data;
    
}


- (void)updateUserGetFinished:(UA_ASIHTTPRequest *)request {
	if(request.responseStatusCode != 200) {
		[self requestWentWrong:request];
	}
}

- (void)updateUserInfo:(NSDictionary *)info withDelegate:(id)delegate finish:(SEL)finishSelector fail:(SEL)failSelector {

    UALOG(@"Updating user");
    
    NSString *updateUrlString = [NSString stringWithFormat:@"%@%@%@/",
								 [[UAirship shared] server],
								 @"/api/user/",
								 [self username]];
	
    NSURL *updateUrl = [NSURL URLWithString: updateUrlString];
	
	// Now do the user update, and pass out "master list" of deviceTokens back to the server
    UA_ASIHTTPRequest *request = [UAUtils userRequestWithURL:updateUrl
                                                      method:@"POST"
                                                    delegate:delegate
                                                      finish:finishSelector
                                                        fail:failSelector];
	
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    
    UA_SBJsonWriter *writer = [[UA_SBJsonWriter new] autorelease];
    NSString *body = [writer stringWithObject:info];
    
    UALOG(@"Update user with content: %@", body);
    
    [request appendPostData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request startAsynchronous];
}

- (void)updateUserWithDelegate:(id)delegate finish:(SEL)finishSelector fail:(SEL)failSelector {

	NSMutableDictionary *options = [[[NSMutableDictionary alloc] init] autorelease];
	
	[options setValue:delegate forKey:@"delegate"];
	[options setValue:NSStringFromSelector(finishSelector) forKey:@"finishSelector"];
	[options setValue:NSStringFromSelector(failSelector) forKey:@"failSelector"];
	
	// We have to do a GET before the modify, so let's do this in a new thread.
	[self performSelectorInBackground:@selector(doUpdateUserWithDelegate:) withObject:options];
	
}	
	
- (void)doUpdateUserWithDelegate:(NSMutableDictionary *)selectors { 	
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // Top-level pool
	
    UALOG(@"Updating user");
	
	NSString *updateUrlString = [NSString stringWithFormat:@"%@%@%@/",
								 [[UAirship shared] server],
								 @"/api/user/",
								 [self username]];
	
    NSURL *updateUrl = [NSURL URLWithString: updateUrlString];
	
	//The user's existing tags and alias must now be retrieved
	UA_ASIHTTPRequest *getRequest = [UAUtils userRequestWithURL:updateUrl
														 method:@"GET"
													   delegate:nil 
														 finish:nil
														   fail:nil];
	[getRequest startSynchronous];
	
	[self updateUserGetFinished:getRequest];
	
	NSMutableArray *deviceTokens = [[[NSMutableArray alloc] init] autorelease];
	BOOL contains = NO;
	
	if (getRequest.responseStatusCode == 200) {
		
		UA_SBJsonParser *parser = [UA_SBJsonParser new];
		NSDictionary *getResult = [parser objectWithString:getRequest.responseString];
		[parser release];
		
		UALOG(@"Update User GET result: %@", [getResult descriptionWithLocale: nil indent: 1]);
		
		// Ensure that the device token is updated if it's available
		[deviceTokens addObjectsFromArray:[getResult objectForKey:@"device_tokens"]];
		
		// If there are device tokens in the array, check them against the local one, if no match then need to update
		for (NSString *deviceToken in deviceTokens) {
			
			if ([[UAPush shared] deviceToken] != nil && [[[[UAPush shared] deviceToken] lowercaseString] isEqualToString:[deviceToken lowercaseString]]) {
				contains = YES;
			}
		}
		
		if((!contains) && ([[UAPush shared] deviceToken] != nil)) {
			UALOG(@"Add device token");
			[deviceTokens addObject:[[UAPush shared] deviceToken]];
		}
		
	} else {
		UALOG(@"Update User - Get existing deviceTokens failed.");
	}
	
	// Now do the user update, and pass out "master list" of deviceTokens back to the server
    UA_ASIHTTPRequest *request = [UAUtils userRequestWithURL:updateUrl
                                                      method:@"PUT"
                                                    delegate:(id)[selectors objectForKey:@"delegate"] 
                                                      finish:NSSelectorFromString([selectors objectForKey:@"finishSelector"])
                                                        fail:NSSelectorFromString([selectors objectForKey:@"failSelector"])];
	
    UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    NSMutableDictionary *data = [self createUserDictionary];
	
	if(getRequest.responseStatusCode == 200) {
		[data setObject:deviceTokens forKey:@"device_tokens"];		
	}

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    NSString* body = [writer stringWithObject:data];
    
    UALOG(@"Update user with content: %@", body);
    
    [request appendPostData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request startAsynchronous];
    
    [writer release];
	
	[pool release];  // Release the objects in the pool.
}

@end
