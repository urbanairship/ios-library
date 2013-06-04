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
#import "UA_SBJSON.h"

static UAUser *_defaultUser;

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
    RELEASE_SAFELY(username);
    RELEASE_SAFELY(password);
    RELEASE_SAFELY(url);
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
        
        if (initialized) {
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
        
        initialized = YES;
                
    }
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
            UALOG(@"Save failed: must have a username and password.");
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
    if (creatingUser) {
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
    
    creatingUser = YES;

    NSString *urlString = [NSString stringWithFormat:@"%@%@",
                           [[UAirship shared] server],
                           @"/api/user/"];
	
    NSURL *createUrl = [NSURL URLWithString:urlString];
    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:createUrl method:@"POST"];

    NSMutableDictionary *data = [self createUserDictionary];

    UA_SBJsonWriter *writer = [[[UA_SBJsonWriter alloc] init] autorelease];
    NSString *body = [writer stringWithObject:data];

    UALOG(@"Create user with body: %@", body);

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    self.connection = [UAHTTPConnection connectionWithRequest:request
                                                     delegate:self
                                                      success:@selector(userCreated:)
                                                      failure:@selector(userCreationDidFail:)];
    [self.connection start];
}

- (void)userCreated:(UAHTTPRequest *)request {
    
    UALOG(@"User created: %d:%@", [request.response statusCode], [request responseString]);

    // done creating! or it failed..
    // wait to update the state enum until the next state is determined below
    creatingUser = NO;

    switch ([request.response statusCode]) {
        case 201://created
        {
            UA_SBJsonParser *parser = [[UA_SBJsonParser alloc] init];
            NSDictionary *result = [parser objectWithString:request.responseString];

            self.username = [result objectForKey:@"user_id"];
            self.password = [result objectForKey:@"password"];
            self.url = [result objectForKey:@"user_url"];
            
            [self saveUserData];
            
            // Check for device token. If it was present in the request, it was just updated, so set the flag in Airship
            if (request.body) {
                
                NSString *requestString = [[NSString alloc] initWithData:request.body encoding:NSUTF8StringEncoding];
                NSDictionary *requestDict = [parser objectWithString:requestString];
                
                [requestString release];
                
                if (requestDict != nil && [requestDict objectForKey:@"device_tokens"] != nil) {
                    
                    // created a user w/ a device token
                    UALOG(@"Created a user with a device token.");
                    
                    NSArray *deviceTokens = [requestDict objectForKey:@"device_tokens"];
                    
                    // get the first item from the request - we will only ever send 1 at most
                    NSString *deviceToken = [deviceTokens objectAtIndex:0];
                    
                    // If we did send a token, then it needs to be updated in the store
                    if (deviceToken) {
                        [self setServerDeviceToken:deviceToken];
                    }
                }
            }
			
            [parser release];
            
            //check to see if the device token has changed, and trigger an update
            [self updateDefaultDeviceToken];
            
            [self notifyObserversUserUpdated];
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

- (void)userCreationDidFail:(UAHTTPRequest *)request {
    creatingUser = NO;
    [self updateUserState];
    [self userRequestWentWrong:request];
}

#pragma mark -
#pragma mark HTTP Request Failure Handler

// Default failure handler, set in UAUtils helper function
- (void)requestWentWrong:(UAHTTPRequest *)request {
    
    [UAUtils logFailedRequest:request withMessage:@"UAUser Request"];

}

// For observer interested request
- (void)userRequestWentWrong:(UAHTTPRequest *)request {
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
    
    UALOG(@"Updating device token.");

    if (![[UAPush shared] deviceToken] || [self deviceTokenHasChanged] == NO || ![self defaultUserCreated]){
		UALOG(@"Skipping device token update: no token, already up to date, or user is being updated.");
        return;
    }
    
    NSString *deviceToken = [[UAPush shared] deviceToken];
    NSDictionary *dict = @{@"device_tokens" :@{@"add" : @[deviceToken]}};
    [self updateUserInfo:dict withDelegate:self finish:@selector(updatedDefaultDeviceToken:) fail:@selector(requestWentWrong:)];
    
}

- (void)updatedDefaultDeviceToken:(UAHTTPRequest *)request {

    if ([request.response statusCode] == 200 || [request.response statusCode] == 201){
        
        // The dictionary for the post body is built as follows in updateDeviceToken
        //    "device_tokens" =     {
        //        add =         (
        //                       a3dce91afd4aa3d2c44a66f2ef7be03b42ac05558ac6bdc2263a60b634f1c78a
        //                       );
        //    };
        // That's what we expect here, an NSDictionary for the key @"device_tokens" with a single NSArray for the key @"add"
        
        NSString *rawJson = [[[NSString alloc] initWithData:request.body  encoding:NSASCIIStringEncoding] autorelease];
        UA_SBJsonParser *parser = [[[UA_SBJsonParser alloc] init] autorelease];
        // If there is an error, it already failed on the server, and didn't get back here, so no use checking for JSON error
        NSDictionary *postBody = [parser objectWithString:rawJson];
        NSArray *add = [[postBody valueForKey:@"device_tokens"] valueForKey:@"add"];
        NSString *successfullyUploadedDeviceToken = ([add count] >= 1) ? [add objectAtIndex:0] : nil;
        
        // Cache the token, even if it's nil, because we may have uploaded a nil token on purpose
        [self setServerDeviceToken:successfullyUploadedDeviceToken];
        
        UALOG(@"Updated Device Token succeeded with response: %d", [request.response statusCode]);
        UALOG(@"Logged last updated key %@", successfullyUploadedDeviceToken);
    }
    else {
        // If we got an other than 200/201, that's just odd
        UALOG(@"Update request did not succeed with expected response: %d", [request.response statusCode]);
    }
}

#pragma mark -
#pragma mark User Update

- (NSMutableDictionary*)createUserDictionary {
 
    //set up basic payload
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                 [UAUtils deviceID], @"ua_device_id", nil ];
    
    [data setValue:self.url forKey:@"user_url"];
    [data setValue:@"true" forKey:@"airmail"];
    
    //if APN hasn't finished yet or is not enabled, don't include the deviceToken
    NSString* deviceToken = [UAPush shared].deviceToken;
	
    if (deviceToken != nil && [deviceToken length] > 0) {
        NSArray *deviceTokens = [NSArray arrayWithObjects:deviceToken, nil];
        [data setObject:deviceTokens forKey:@"device_tokens"];
    }

    [data autorelease];
    
    return data;
    
}


- (void)updateUserGetFinished:(UAHTTPRequest *)request {
	if([request.response statusCode] != 200) {
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
    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:updateUrl method:@"POST"];
    
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    
    UA_SBJsonWriter *writer = [[UA_SBJsonWriter new] autorelease];
    NSString *body = [writer stringWithObject:info];
    
    UALOG(@"Update user with content: %@", body);
    
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    self.connection = [UAHTTPConnection connectionWithRequest:request
                                                     delegate:self
                                                      success:finishSelector
                                                      failure:failSelector];
    [_connection start];
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
	UAHTTPRequest *getRequest = [UAUtils UAHTTPUserRequestWithURL:updateUrl method:@"GET"];

    UAHTTPConnection *connection = [UAHTTPConnection connectionWithRequest:getRequest];
	[connection startSynchronous];

	[self updateUserGetFinished:getRequest];
	
	NSMutableArray *deviceTokens = [[[NSMutableArray alloc] init] autorelease];
	BOOL contains = NO;
	
	if ([getRequest.response statusCode] == 200) {
		
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
    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:updateUrl method:@"PUT"];
    
	
    UA_SBJsonWriter *writer = [[[UA_SBJsonWriter alloc] init] autorelease];
    NSMutableDictionary *data = [self createUserDictionary];
	
	if([getRequest.response statusCode] == 200) {
		[data setObject:deviceTokens forKey:@"device_tokens"];		
	}

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    NSString* body = [writer stringWithObject:data];
    
    UALOG(@"Update user with content: %@", body);
    
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UAHTTPConnection *updateConnection = [UAHTTPConnection connectionWithRequest:request];
    updateConnection.delegate = (id)[selectors objectForKey:@"delegate"];
    updateConnection.successSelector = NSSelectorFromString([selectors objectForKey:@"finishSelector"]);
    updateConnection.failureSelector = NSSelectorFromString([selectors objectForKey:@"failSelector"]);

    [updateConnection start];

	[pool drain];  // Release the objects in the pool.
}

@end
