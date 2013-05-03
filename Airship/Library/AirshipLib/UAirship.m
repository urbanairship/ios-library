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

#import <CoreLocation/CoreLocation.h>
#import "UAirship.h"
#import "UAirship+Internal.h"

#import "UAUser.h"
#import "UAAnalytics.h"
#import "UAEvent.h"
#import "UAUtils.h"
#import "UAKeychainUtils.h"
#import "UALocationService.h"
#import "UAGlobal.h"
#import "UAPush.h"

UA_VERSION_IMPLEMENTATION(AirshipVersion, UA_VERSION)

NSString * const UALocationServicePreferences = @"UALocationServicePreferences";
NSString * const UAirshipTakeOffOptionsAirshipConfigKey = @"UAirshipTakeOffOptionsAirshipConfigKey";
NSString * const UAirshipTakeOffOptionsLaunchOptionsKey = @"UAirshipTakeOffOptionsLaunchOptionsKey";
NSString * const UAirshipTakeOffOptionsAnalyticsKey = @"UAirshipTakeOffOptionsAnalyticsKey";
NSString * const UAirshipTakeOffOptionsDefaultUsernameKey = @"UAirshipTakeOffOptionsDefaultUsernameKey";
NSString * const UAirshipTakeOffOptionsDefaultPasswordKey = @"UAirshipTakeOffOptionsDefaultPasswordKey";

//Exceptions
NSString * const UAirshipTakeOffBackgroundThreadException = @"UAirshipTakeOffBackgroundThreadException";

static UAirship *_sharedAirship;

// Logging info
// Default to ON and DEBUG - options/plist will override
BOOL uaLoggingEnabled = YES;
UALogLevel uaLogLevel = UALogLevelUndefined;

@implementation UAirship

#pragma mark -
#pragma mark Logging
+ (void)setLogging:(BOOL)value {
    uaLoggingEnabled = value;
}

+ (void)setLogLevel:(UALogLevel)level {
    uaLogLevel = level;
}

#pragma mark -
#pragma mark Location Get/Set Methods

- (UALocationService *)locationService {
    if (!_locationService) {
        _locationService = [[UALocationService alloc] init];
    }

    return _locationService;
}

#pragma mark -
#pragma mark Object Lifecycle
- (void)dealloc {
    self.appId = nil;
    self.appSecret = nil;
    self.server = nil;
    
    // Analytics contains an NSTimer, and the invalidate method is required
    // before dealloc
    [self.analytics invalidate];
    self.analytics = nil;
    self.locationService = nil;
    
    [super dealloc];
}

- (id)initWithId:(NSString *)appkey identifiedBy:(NSString *)secret {
    if (self = [super init]) {
        self.appId = appkey;
        self.appSecret = secret;
    }
    return self;
}

+ (void)takeOff:(NSDictionary *)options {
    
    // Airships only take off once!
    if (_sharedAirship) {
        return;
    }
    
    // takeOff needs to be run on the main thread
    if (![[NSThread currentThread] isMainThread]) {
        NSException *mainThreadException = [NSException exceptionWithName:UAirshipTakeOffBackgroundThreadException
                                                                   reason:@"UAirship takeOff must be called on the main thread."
                                                                 userInfo:nil];
        [mainThreadException raise];
    }
    
    // Load configuration
    // Primary configuration comes from the UAirshipTakeOffOptionsAirshipConfig dictionary and will
    // override any options defined in AirshipConfig.plist
    NSMutableDictionary *config = nil;
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"AirshipConfig" ofType:@"plist"];
    
    if (configPath) {
        config = [[[NSMutableDictionary alloc] initWithContentsOfFile:configPath] autorelease];
        [config addEntriesFromDictionary:[options objectForKey:UAirshipTakeOffOptionsAirshipConfigKey]];
    } else {
        config = [NSMutableDictionary dictionaryWithDictionary:[options objectForKey:UAirshipTakeOffOptionsAirshipConfigKey]];
    }
  
    BOOL inProduction = [[config objectForKey:@"APP_STORE_OR_AD_HOC_BUILD"] boolValue];
    
    /*
     * Set up log levels
     */
    
    // Set up logging - enabled flag and loglevels
    NSString *configLogLevel = [config objectForKey:@"LOG_LEVEL"];
    NSString *configLoggingEnabled = [config objectForKey:@"LOGGING_ENABLED"];

    // Logging defaults to ON, but use config value if available
    if (configLoggingEnabled) {
        [UAirship setLogging:[configLoggingEnabled boolValue]];
    }

    // Set the default to ERROR for production apps, DEBUG for dev apps
    UALogLevel defaultLogLevel = inProduction ? UALogLevelError : UALogLevelDebug;
    
    // Respect the config value if set
    UALogLevel newLogLevel = configLogLevel ? [configLogLevel intValue] : defaultLogLevel;
    
    //only update the log level if it wasn't already defined in code
    if (UALogLevelUndefined == uaLogLevel) {
        [UAirship setLogLevel:newLogLevel];
    }
    
    /*
     * Validate options - Now that logging is set up, peform some additional validation
     */
    
    if (!options) {
        UA_LERR(@"[UAirship takeOff] was called without options. The options dictionary must"
                " include the UIApplication launch options (key: UAirshipTakeOffOptionsLaunchOptionsKey).");
    }

    // Ensure that app credentials have been passed in
    if ([config count] <= 0) {
        
        UA_LERR(@"The AirshipConfig.plist file is missing and no application credentials were specified at runtime.");
        
        //Use blank credentials to prevent app from crashing while error msg
        //is displayed
        _sharedAirship = [[UAirship alloc] initWithId:@"" identifiedBy:@""];
        
        return;
    }
    
    /*
     * Read and validate App Key, Secret and REST API server
     */
    
    NSString *configAppKey;
    NSString *configAppSecret;
    
    if (inProduction) {
        configAppKey = [config objectForKey:@"PRODUCTION_APP_KEY"];
        configAppSecret = [config objectForKey:@"PRODUCTION_APP_SECRET"];
    } else {
        configAppKey = [config objectForKey:@"DEVELOPMENT_APP_KEY"];
        configAppSecret = [config objectForKey:@"DEVELOPMENT_APP_SECRET"];
    }
    
    // strip leading and trailing whitespace
    configAppKey = [configAppKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    configAppSecret = [configAppSecret stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    //Check for a custom UA server value
    NSString *airshipServer = [config objectForKey:@"AIRSHIP_SERVER"];
    if (!airshipServer) {
        airshipServer = kAirshipProductionServer;
    }
    
    _sharedAirship = [[UAirship alloc] initWithId:configAppKey identifiedBy:configAppSecret];
    _sharedAirship.server = airshipServer;
    
    UA_LINFO(@"App Key: %@", _sharedAirship.appId);
    UA_LINFO(@"App Secret: %@", _sharedAirship.appSecret);
    UA_LINFO(@"Server: %@", _sharedAirship.server);
    
    //Check the format of the app key and password.
    //If they're missing or malformed, stop takeoff
    //and prevent the app from connecting to UA.
    NSPredicate *matchPred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^\\S{22}+$"];
    BOOL match = [matchPred evaluateWithObject:_sharedAirship.appId] 
                    && [matchPred evaluateWithObject:_sharedAirship.appSecret];  
    
    if (!match) {
        UA_LERR(
            @"Application KEY and/or SECRET not set properly, please"
            " insert your application key from http://go.urbanairship.com into"
                " your AirshipConfig.plist file");
        
        //Use blank credentials to prevent app from crashing
        _sharedAirship = [[UAirship alloc] initWithId:@"" identifiedBy:@""];
        return;
    }
    
    // Build a custom user agent with the app key and name
    [_sharedAirship configureUserAgent];

    /*
     * Handle Debug Options
     */
    
    //For testing, set this value in AirshipConfig to clear out
    //the keychain credentials, as they will otherwise be persisted
    //even when the application is uninstalled.
    if ([[config objectForKey:@"DELETE_KEYCHAIN_CREDENTIALS"] boolValue]) {
        
        UA_LDEBUG(@"Deleting the keychain credentials");
        [UAKeychainUtils deleteKeychainValue:[[UAirship shared] appId]];
        
        UA_LDEBUG(@"Deleting the UA device ID");
        [UAKeychainUtils deleteKeychainValue:kUAKeychainDeviceIDKey];
    }
    
    // The singleton is now ready for use!
    _sharedAirship.ready = true;
    
    /*
     * Set up Analytics Manager
     */
    
    // Set up analytics - record when app is opened from a push
    
    // Application launch options
    NSDictionary *launchOptions = [options objectForKey:UAirshipTakeOffOptionsLaunchOptionsKey];
    NSMutableDictionary *analyticsOptions = [options objectForKey:UAirshipTakeOffOptionsAnalyticsKey];
    if (!analyticsOptions) {
        analyticsOptions = [NSMutableDictionary dictionary];
    }
    [analyticsOptions setValue:[launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey]
                        forKey:UAAnalyticsOptionsRemoteNotificationKey];
    
    // Add the server to the analytics options, but do not delete if not set as
    // it may also be set in the options parameters
    NSString *analyticsServer = [config objectForKey:@"ANALYTICS_SERVER"];
    if (analyticsServer) {
        [analyticsOptions setObject:analyticsServer forKey:UAAnalyticsOptionsServerKey];
    }
    _sharedAirship.analytics = [[[UAAnalytics alloc] initWithOptions:analyticsOptions] autorelease];
    
    //Send Startup Analytics Info
    //init first event
    [_sharedAirship.analytics addEvent:[UAEventAppInit eventWithContext:nil]];
    
    /*
     * Set up UAUser
     */
    
    //Handle custom options
    NSString *defaultUsername = [options valueForKey:UAirshipTakeOffOptionsDefaultUsernameKey];
    NSString *defaultPassword = [options valueForKey:UAirshipTakeOffOptionsDefaultPasswordKey];
    if (defaultUsername && defaultPassword) {
        [UAUser setDefaultUsername:defaultUsername withPassword:defaultPassword];
    }
    
    //create/setup user (begin listening for device token changes)
    [[UAUser defaultUser] initializeUser];
}

+ (void)land {

	// add app_exit event
    [_sharedAirship.analytics addEvent:[UAEventAppExit eventWithContext:nil]];
	
    //Land common classes
    [UAUser land];
    
    //Land the modular libaries first
    [NSClassFromString(@"UAPush") land];
    [NSClassFromString(@"UAInbox") land];
    
    //Finally, release the airship!
    [_sharedAirship release];
    _sharedAirship = nil;
}

+ (UAirship *)shared {
    if (_sharedAirship == nil) {
        [NSException raise:@"InstanceNotExists"
                    format:@"Attempted to access UAirship instance before initializaion. Please call [UAirship takeOff:] first."];
    }
    return _sharedAirship;
}

#pragma mark -
#pragma mark DeviceToken get/set/utils

- (NSString *)deviceToken {
    return [[UAPush shared] deviceToken];
}

- (void)configureUserAgent
{
    /*
     * [LIB-101] User agent string should be:
     * App 1.0 (iPad; iPhone OS 5.0.1; UALib 1.1.2; <app key>; en_US)
     */
    
    UIDevice *device = [UIDevice currentDevice];
    
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *info = [bundle infoDictionary];
    
    NSString *appName = [info objectForKey:(NSString*)kCFBundleNameKey];
    NSString *appVersion = [info objectForKey:(NSString*)kCFBundleVersionKey];
    
    NSString *deviceModel = [device model];
    NSString *osName = [device systemName];
    NSString *osVersion = [device systemVersion];
    
    NSString *libVersion = [AirshipVersion get];
    NSString *locale = [[NSLocale currentLocale] localeIdentifier];
    
    NSString *userAgent = [NSString stringWithFormat:@"%@ %@ (%@; %@ %@; UALib %@; %@; %@)",
                           appName, appVersion, deviceModel, osName, osVersion, libVersion, self.appId, locale];
    
    UALOG(@"Setting User-Agent for UA requests to %@", userAgent);
    [UAHTTPConnection setDefaultUserAgentString:userAgent];
}

#pragma mark -
#pragma mark UAPush Methods


- (void)registerDeviceToken:(NSData *)token {
    [[UAPush shared] registerDeviceToken:token withExtraInfo:nil];
}

- (void)registerDeviceToken:(NSData *)token withAlias:(NSString *)alias {
    [[UAPush shared] registerDeviceToken:token withAlias:alias];
}

- (void)registerDeviceToken:(NSData *)token withExtraInfo:(NSDictionary *)info {
    [[UAPush shared] registerDeviceToken:token withExtraInfo:info];
}

- (void)registerDeviceTokenWithExtraInfo:(NSDictionary *)info {
    [[UAPush shared] registerDeviceTokenWithExtraInfo:info];
}

- (void)unRegisterDeviceToken {
    [[UAPush shared] unRegisterDeviceToken];
}

@end
