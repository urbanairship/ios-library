/*
Copyright 2009-2010 Urban Airship Inc. All rights reserved.

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
#import "UAUser.h"
#import "UAUtils.h"
#import "UA_ASIHTTPRequest.h"
#import "UA_SBJSON.h"
#import "UAKeychainUtils.h"

#define kAirshipProductionServer @"https://go.urbanairship.com"

#define kLastDeviceTokenKey @"UADeviceTokenChanged" 

UA_VERSION_IMPLEMENTATION(AirshipVersion, UA_VERSION)

NSString * const UAirshipTakeOffOptionsLaunchOptionsKey = @"UAirshipTakeOffOptionsLaunchOptionsKey";
NSString * const UAirshipTakeOffOptionsAnalyticsKey = @"UAirshipTakeOffOptionsAnalyticsKey";
NSString * const UAirshipTakeOffOptionsDefaultUsernameKey = @"UAirshipTakeOffOptionsDefaultUsernameKey";
NSString * const UAirshipTakeOffOptionsDefaultPasswordKey = @"UAirshipTakeOffOptionsDefaultPasswordKey";

static UAirship *_sharedAirship;
BOOL releaseLogging = false;

@implementation UAirship

@synthesize server;
@synthesize appId;
@synthesize appSecret;
@synthesize deviceTokenHasChanged;
@synthesize analytics;

+(void)setReleaseLogging:(BOOL)value {
    releaseLogging = value;
}

-(void)dealloc {
    RELEASE_SAFELY(appId);
    RELEASE_SAFELY(appSecret);
    RELEASE_SAFELY(server);
    RELEASE_SAFELY(registerRequest);
    RELEASE_SAFELY(deviceToken);
    RELEASE_SAFELY(analytics);

    [super dealloc];
}

-(id)initWithId:(NSString *)appkey identifiedBy:(NSString *)secret {
    if (self = [super init]) {
        self.appId = appkey;
        self.appSecret = secret;
        deviceTokenHasChanged = NO;
        deviceToken = nil;
    }
    return self;
}

+(void)takeOff:(NSString *)appid identifiedBy:(NSString *)secret {
    [UAirship takeOff:appid identifiedBy:secret withOptions:nil];
}

+(void)takeOff:(NSString*)appid identifiedBy:(NSString *)secret withOptions:(NSDictionary *)options {
    if(!_sharedAirship) {
        
        //Application launch options
        NSDictionary *launchOptions = [options objectForKey:UAirshipTakeOffOptionsLaunchOptionsKey];
        
        //Set up analytics - record when app is opened from a push
        NSMutableDictionary *analyticsOptions = [options objectForKey:UAirshipTakeOffOptionsAnalyticsKey];
        if (analyticsOptions == nil) {
            analyticsOptions = [[[NSMutableDictionary alloc] init] autorelease];
        }
        [analyticsOptions setValue:[launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey] 
                            forKey:UAAnalyticsOptionsRemoteNotificationKey];
        
        //optionally read custom configuration information from AirshipConfig.plist
        NSString *path = [[NSBundle mainBundle]
                                    pathForResource:@"AirshipConfig" ofType:@"plist"];
        if (path != nil){
            NSMutableDictionary *config = [[[NSMutableDictionary alloc] initWithContentsOfFile:path] autorelease];

            NSString *APP_KEY = [config objectForKey:@"APP_KEY"];
            NSString *APP_SECRET = [config objectForKey:@"APP_SECRET"];
            NSString *AIRSHIP_SERVER = [config objectForKey:@"AIRSHIP_SERVER"];
            NSString *ANALYTICS_SERVER = [config objectForKey:@"ANALYTICS_SERVER"];
            
            _sharedAirship = [[UAirship alloc] initWithId:APP_KEY
                                            identifiedBy:APP_SECRET];
            _sharedAirship.server = AIRSHIP_SERVER;
            
            //Add the server to the analytics options
            if (ANALYTICS_SERVER != nil) {
                [analyticsOptions setObject:ANALYTICS_SERVER forKey:UAAnalyticsOptionsServerKey];
            }
            //For testing, set this value in AirshipConfig to clear out
            //the keychain credentials, as they will otherwise be persisted
            //even when the application is uninstalled.
            BOOL deleteKeychainCredentials = 
                [[config objectForKey:@"DELETE_KEYCHAIN_CREDENTIALS"] boolValue];
            
            if (deleteKeychainCredentials) {
                UALOG(@"Deleting the keychain credentials");
                [UAKeychainUtils deleteKeychainValue:[[UAirship shared] appId]];
            }
            
        } else {
            if([appid isEqual: @"YOUR_APP_KEY"] || [secret isEqual: @"YOUR_APP_SECRET"]) {
                NSString* okStr = @"OK";
                NSString* errorMessage =
                @"Application KEY and/or SECRET not set, please"
                " insert your application key from http://go.urbanairship.com into"
                " the Airship initialization located in your App Delegate's"
                " didFinishLaunching method";
                NSString *errorTitle = @"Ooopsie";
                UIAlertView *someError = [[UIAlertView alloc] initWithTitle:errorTitle
                                                                    message:errorMessage
                                                                   delegate:nil
                                                          cancelButtonTitle:okStr
                                                          otherButtonTitles:nil];

                [someError show];
                [someError release];
            }

            _sharedAirship = [[UAirship alloc] initWithId:appid identifiedBy:secret];
            _sharedAirship.server = kAirshipProductionServer;
        }
        UALOG(@"App Key: %@", _sharedAirship.appId);
        UALOG(@"App Secret: %@", _sharedAirship.appSecret);
        UALOG(@"Server: %@", _sharedAirship.server);
        
        _sharedAirship.analytics = [[UAAnalytics alloc] initWithOptions:analyticsOptions];
    }
    
    //Send Startup Analytics Info
    //init first event
    [_sharedAirship.analytics addEvent:[_sharedAirship.analytics buildStartupMetadataDictionary] withType:@"app_init"];
    [_sharedAirship.analytics send];
    
    //Handle custom options
    if (options != nil) {
    
        NSString *defaultUsername = [options valueForKey:UAirshipTakeOffOptionsDefaultUsernameKey];
        NSString *defaultPassword = [options valueForKey:UAirshipTakeOffOptionsDefaultPasswordKey];
        if (defaultUsername != nil && defaultPassword != nil) {
            [UAUser setDefaultUsername:defaultUsername withPassword:defaultPassword];
        }
        
    }
    
    //create/setup user (begin listening for device token changes)
    [UAUser defaultUser];

}

+ (void)land {

    //Land the modular libaries first
    [NSClassFromString(@"UAInbox") land];
    [NSClassFromString(@"StoreFront") land];
    [NSClassFromString(@"UASubscriptionManager") land];
    
    //Land common classes
    [NSClassFromString(@"UAUser") land];
    
    //Finally, release the airship!
    [_sharedAirship release];
    _sharedAirship = nil;
}

+(UAirship *)shared {
    if (_sharedAirship == nil) {
        [NSException raise:@"InstanceNotExists"
                    format:@"Attempted to access instance before initializaion. Please call takeOff:identifiedBy: first."];
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
        [self notifyObservers:@selector(unRegisterDeviceTokenSucceeded)];
    }
}

#pragma mark -
#pragma mark UA Registration request methods

- (void)registerDeviceTokenWithExtraInfo:(NSDictionary *)info {
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
}

- (void)registerDeviceToken:(NSData *)token withAlias:(NSString *)alias {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (alias != nil) {
        [body setObject:alias forKey:@"alias"];
    }
    [self registerDeviceToken:token withExtraInfo:body];
}

- (void)unRegisterDeviceToken {
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

-(void)registerDeviceToken:(NSData *)token {
    // succeed register APN device token, then register on UA server
    [self registerDeviceToken:token withExtraInfo:nil];
}

@end
