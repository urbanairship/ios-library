/*
Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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

#import "UAirship.h"

#import "UA_ASIHTTPRequest.h"
#import "UA_SBJSON.h"

#import "UAUser.h"
#import "UAEvent.h"
#import "UAUtils.h"
#import "UAKeychainUtils.h"

#define kAirshipProductionServer @"https://go.urbanairship.com"
#define kLastDeviceTokenKey @"UADeviceTokenChanged" 

UA_VERSION_IMPLEMENTATION(AirshipVersion, UA_VERSION)

NSString * const UAirshipTakeOffOptionsAirshipConfigKey = @"UAirshipTakeOffOptionsAirshipConfigKey";
NSString * const UAirshipTakeOffOptionsLaunchOptionsKey = @"UAirshipTakeOffOptionsLaunchOptionsKey";
NSString * const UAirshipTakeOffOptionsAnalyticsKey = @"UAirshipTakeOffOptionsAnalyticsKey";
NSString * const UAirshipTakeOffOptionsDefaultUsernameKey = @"UAirshipTakeOffOptionsDefaultUsernameKey";
NSString * const UAirshipTakeOffOptionsDefaultPasswordKey = @"UAirshipTakeOffOptionsDefaultPasswordKey";

static UAirship *_sharedAirship;
BOOL logging = false;

@implementation UAirship

@synthesize server;
@synthesize appId;
@synthesize appSecret;
@synthesize deviceTokenHasChanged;
@synthesize ready;
@synthesize analytics;

+ (void)setLogging:(BOOL)value {
    logging = value;
}

- (void)dealloc {
    RELEASE_SAFELY(appId);
    RELEASE_SAFELY(appSecret);
    RELEASE_SAFELY(server);
    RELEASE_SAFELY(registerRequest);
    RELEASE_SAFELY(deviceToken);
    RELEASE_SAFELY(analytics);

    [super dealloc];
}

- (id)initWithId:(NSString *)appkey identifiedBy:(NSString *)secret {
    if (self = [super init]) {
        self.appId = appkey;
        self.appSecret = secret;
        deviceTokenHasChanged = NO;
        deviceToken = nil;
    }
    return self;
}

+ (void)takeOff:(NSDictionary *)options {
    
    //Airships only take off once!
    if (_sharedAirship) {
        return;
    }
    
    //Application launch options
    NSDictionary *launchOptions = [options objectForKey:UAirshipTakeOffOptionsLaunchOptionsKey];
    
    //Set up analytics - record when app is opened from a push
    NSMutableDictionary *analyticsOptions = [options objectForKey:UAirshipTakeOffOptionsAnalyticsKey];
    if (analyticsOptions == nil) {
        analyticsOptions = [[[NSMutableDictionary alloc] init] autorelease];
    }
    [analyticsOptions setValue:[launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey] 
                        forKey:UAAnalyticsOptionsRemoteNotificationKey];
    
    
    
    // Load configuration
    // Primary configuration comes from the UAirshipTakeOffOptionsAirshipConfig dictionary and will
    // override any options defined in AirshipConfig.plist
    NSMutableDictionary *config;
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"AirshipConfig" ofType:@"plist"];
    
    if (configPath) {
        config = [[[NSMutableDictionary alloc] initWithContentsOfFile:configPath] autorelease];
        [config addEntriesFromDictionary:[options objectForKey:UAirshipTakeOffOptionsAirshipConfigKey]];
    } else {
        config = [NSMutableDictionary dictionaryWithDictionary:[options objectForKey:UAirshipTakeOffOptionsAirshipConfigKey]];
    }

    if ([config count] > 0) {
        
        BOOL inProduction = [[config objectForKey:@"APP_STORE_OR_AD_HOC_BUILD"] boolValue];
        
        NSString *loggingOptions = [config objectForKey:@"LOGGING_ENABLED"];
        
        if (loggingOptions != nil) {
            // If it is present, use it
            [UAirship setLogging:[[config objectForKey:@"LOGGING_ENABLED"] boolValue]];
        } else {
            // If it is missing
            if (inProduction) {
                [UAirship setLogging:NO];
            } else {
                [UAirship setLogging:YES];
            }
        }
        
        NSString *configAppKey;
        NSString *configAppSecret;
        
        if (inProduction) {
            configAppKey = [config objectForKey:@"PRODUCTION_APP_KEY"];
            configAppSecret = [config objectForKey:@"PRODUCTION_APP_SECRET"];
        } else {
            configAppKey = [config objectForKey:@"DEVELOPMENT_APP_KEY"];
            configAppSecret = [config objectForKey:@"DEVELOPMENT_APP_SECRET"];
            
            //set release logging to yes because static lib is built in release mode
            //[UAirship setLogging:YES];
        }
        
        // strip leading and trailing whitespace
        configAppKey = [configAppKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        configAppSecret = [configAppSecret stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        //Check for a custom UA server value
        NSString *airshipServer = [config objectForKey:@"AIRSHIP_SERVER"];
        if (airshipServer == nil) {
            airshipServer = kAirshipProductionServer;
        }
        
        _sharedAirship = [[UAirship alloc] initWithId:configAppKey identifiedBy:configAppSecret];
        _sharedAirship.server = airshipServer;
        
        //Add the server to the analytics options, but do not delete if not set as
        //it may also be set in the options parameters
        NSString *analyticsServer = [config objectForKey:@"ANALYTICS_SERVER"];
        if (analyticsServer != nil) {
            [analyticsOptions setObject:analyticsServer forKey:UAAnalyticsOptionsServerKey];
        }
        
        
        //For testing, set this value in AirshipConfig to clear out
        //the keychain credentials, as they will otherwise be persisted
        //even when the application is uninstalled.
        if ([[config objectForKey:@"DELETE_KEYCHAIN_CREDENTIALS"] boolValue]) {
            UALOG(@"Deleting the keychain credentials");
            [UAKeychainUtils deleteKeychainValue:[[UAirship shared] appId]];
        }
        
    } else {
        NSString* okStr = @"OK";
        NSString* errorMessage = @"The AirshipConfig.plist file is missing.";
        NSString *errorTitle = @"Error";
        UIAlertView *someError = [[UIAlertView alloc] initWithTitle:errorTitle
                                                            message:errorMessage
                                                           delegate:nil
                                                  cancelButtonTitle:okStr
                                                  otherButtonTitles:nil];
        
        [someError show];
        [someError release];
        
        //Use blank credentials to prevent app from crashing while error msg
        //is displayed
        _sharedAirship = [[UAirship alloc] initWithId:@"" identifiedBy:@""];
        
        return;

    }
    
    UALOG(@"App Key: %@", _sharedAirship.appId);
    UALOG(@"App Secret: %@", _sharedAirship.appSecret);
    UALOG(@"Server: %@", _sharedAirship.server);
    
    
    //Check the format of the app key and password.
    //If they're missing or malformed, stop takeoff
    //and prevent the app from connecting to UA.
    NSPredicate *matchPred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^\\S{22}+$"];
    BOOL match = [matchPred evaluateWithObject:_sharedAirship.appId] 
                    && [matchPred evaluateWithObject:_sharedAirship.appSecret];  
    
    if (!match) {
        NSString* okStr = @"OK";
        NSString* errorMessage =
            @"Application KEY and/or SECRET not set properly, please"
            " insert your application key from http://go.urbanairship.com into"
            " your AirshipConfig.plist file";
        NSString *errorTitle = @"Error";
        UIAlertView *someError = [[UIAlertView alloc] initWithTitle:errorTitle
                                                            message:errorMessage
                                                           delegate:nil
                                                  cancelButtonTitle:okStr
                                                  otherButtonTitles:nil];
        
        [someError show];
        [someError release];
        return;
        
    }
    
    _sharedAirship.ready = true;
    _sharedAirship.analytics = [[[UAAnalytics alloc] initWithOptions:analyticsOptions] autorelease];
    
    //Send Startup Analytics Info
    //init first event
    [_sharedAirship.analytics addEvent:[UAEventAppInit eventWithContext:nil]];
    
    //Handle custom options
    if (options != nil) {
        
        NSString *defaultUsername = [options valueForKey:UAirshipTakeOffOptionsDefaultUsernameKey];
        NSString *defaultPassword = [options valueForKey:UAirshipTakeOffOptionsDefaultPasswordKey];
        if (defaultUsername != nil && defaultPassword != nil) {
            [UAUser setDefaultUsername:defaultUsername withPassword:defaultPassword];
        }
        
    }
    
    //create/setup user (begin listening for device token changes)
    [[UAUser defaultUser] initializeUser];
}

+ (void)land {

	// add app_exit event
    [_sharedAirship.analytics addEvent:[UAEventAppExit eventWithContext:nil]];
	
    //Land the modular libaries first
    [NSClassFromString(@"UAInbox") land];
    [NSClassFromString(@"UAStoreFront") land];
    [NSClassFromString(@"UASubscriptionManager") land];
    
    //Land common classes
    [NSClassFromString(@"UAUser") land];
    
    //Finally, release the airship!
    [_sharedAirship release];
    _sharedAirship = nil;
}

+ (UAirship *)shared {
    if (_sharedAirship == nil) {
        [NSException raise:@"InstanceNotExists"
                    format:@"Attempted to access instance before initializaion. Please call takeOff: first."];
    }
    return _sharedAirship;
}

#pragma mark -
#pragma mark DeviceToken get/set/utils

- (NSString*)deviceToken {
    return deviceToken;
}

- (NSString*)parseDeviceToken:(NSString*)tokenStr {
    return [[[tokenStr stringByReplacingOccurrencesOfString:@"<" withString:@""]
                       stringByReplacingOccurrencesOfString:@">" withString:@""]
                       stringByReplacingOccurrencesOfString:@" " withString:@""];
}

- (void)setDeviceToken:(NSString*)tokenStr {
    [deviceToken release];
    deviceToken = [[self parseDeviceToken:tokenStr] retain];
    UALOG(@"Device token: %@", deviceToken);

    // Check to see if the device token has changed
    NSString* oldValue = [[NSUserDefaults standardUserDefaults] objectForKey:kLastDeviceTokenKey];
    if(![oldValue isEqualToString: deviceToken]) {
        deviceTokenHasChanged = YES;
        [[NSUserDefaults standardUserDefaults] setObject:deviceToken forKey:kLastDeviceTokenKey];
    }
}

- (void)updateDeviceToken:(NSData*)tokenData {
    self.deviceToken = [self parseDeviceToken:[tokenData description]];
}


#pragma mark -
#pragma mark UA Registration callbacks

- (void)registerDeviceTokenFailed:(UA_ASIHTTPRequest *)request {
    [UAUtils requestWentWrong:request keyword:@"registering device token"];
    [self notifyObservers:@selector(registerDeviceTokenFailed:)
               withObject:request];
}

- (void)registerDeviceTokenSucceeded:(UA_ASIHTTPRequest *)request {
    if(request.responseStatusCode != 200 && request.responseStatusCode != 201) {
        [self registerDeviceTokenFailed:request];
    } else {
        UALOG(@"Device token registered on Urban Airship successfully.");
        [self notifyObservers:@selector(registerDeviceTokenSucceeded)];
    }
}

- (void)unRegisterDeviceTokenFailed:(UA_ASIHTTPRequest *)request {
    [UAUtils requestWentWrong:request keyword:@"unRegistering device token"];
    [self notifyObservers:@selector(unRegisterDeviceTokenFailed:)
               withObject:request];
}

- (void)unRegisterDeviceTokenSucceeded:(UA_ASIHTTPRequest *)request {
    if (request.responseStatusCode != 204){
        [self unRegisterDeviceTokenFailed:request];
    } else {
        UALOG(@"Device token unregistered on Urban Airship successfully.");
        self.deviceToken = nil;
        [self notifyObservers:@selector(unRegisterDeviceTokenSucceeded)];
    }
}

#pragma mark -
#pragma mark UA Registration request methods

- (void)registerDeviceTokenWithExtraInfo:(NSDictionary *)info {

    IF_IOS4_OR_GREATER(
                       // if the application is backgrounded, do not send a registration
                       if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
                           UALOG(@"App is running in the background - Skipping DT registration. The app is currently backgrounded.");
                           return;
                       }
    )
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@/",
                           server, @"/api/device_tokens/",
                           deviceToken];
    NSURL *url = [NSURL URLWithString:urlString];
    UA_ASIHTTPRequest *request = [UAUtils requestWithURL:url
                                       method:@"PUT"
                                     delegate:self
                                       finish:@selector(registerDeviceTokenSucceeded:)
                                         fail:@selector(registerDeviceTokenFailed:)];
    if (info != nil) {
        [request addRequestHeader: @"Content-Type" value: @"application/json"];
        UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
        [request appendPostData:[[writer stringWithObject:info] dataUsingEncoding:NSUTF8StringEncoding]];
        [writer release];
    }

    [request startAsynchronous];
    
}

- (void)registerDeviceToken:(NSData *)token withExtraInfo:(NSDictionary *)info {
    
    [self updateDeviceToken:token];
    [self registerDeviceTokenWithExtraInfo:info];
    
    // add device_registration event
    [self.analytics addEvent:[UAEventDeviceRegistration eventWithContext:nil]];
}

- (void)registerDeviceToken:(NSData *)token withAlias:(NSString *)alias {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (alias != nil) {
        [body setObject:alias forKey:@"alias"];
    }
    [self registerDeviceToken:token withExtraInfo:body];
}

- (void)unRegisterDeviceToken {
    
    if (deviceToken == nil) {
        UALOG(@"Skipping unRegisterDeviceToken: no device token found.");
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/api/device_tokens/%@/",
                           server,
                           deviceToken];
    NSURL *url = [NSURL URLWithString:urlString];
    UALOG(@"Request to unregister device token.");
    UA_ASIHTTPRequest *request = [UAUtils requestWithURL:url
                                       method:@"DELETE"
                                     delegate:self
                                       finish:@selector(unRegisterDeviceTokenSucceeded:)
                                         fail:@selector(unRegisterDeviceTokenFailed:)];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Callback for succeed register APN device token

- (void)registerDeviceToken:(NSData *)token {
	
    // succeed register APN device token, then register on UA server
    [self registerDeviceToken:token withExtraInfo:nil];
	
}

@end
