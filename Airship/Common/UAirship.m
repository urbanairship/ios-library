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

#import <CoreLocation/CoreLocation.h>

#import "UAirship+Internal.h"

#import "UAUser.h"
#import "UAAnalytics+Internal.h"
#import "UAEvent.h"
#import "UAUtils.h"
#import "UAKeychainUtils.h"
#import "UALocationService.h"
#import "UAGlobal.h"
#import "UAPush.h"
#import "UAConfig.h"
#import "UAInboxPushHandler.h"

#import "UAAppDelegateProxy.h"
#import "UAAppDelegate.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAURLProtocol.h"

UA_VERSION_IMPLEMENTATION(UAirshipVersion, UA_VERSION)

//Exceptions
NSString * const UAirshipTakeOffBackgroundThreadException = @"UAirshipTakeOffBackgroundThreadException";

static UAirship *_sharedAirship;

static dispatch_once_t takeOffPred_;

// Logging info
// Default to ON and ERROR - options/plist will override
BOOL uaLoggingEnabled = YES;
UALogLevel uaLogLevel = UALogLevelError;

@implementation UAirship

#pragma mark -
#pragma mark Logging
+ (void)setLogging:(BOOL)value {
    uaLoggingEnabled = value;
}

+ (void)setLogLevel:(UALogLevel)level {
    uaLogLevel = level;
}

+ (void)load {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:[UAirship class] selector:@selector(handleAppDidFinishLaunchingNotification:) name:UIApplicationDidFinishLaunchingNotification object:nil];
    [center addObserver:[UAirship class] selector:@selector(handleAppTerminationNotification:) name:UIApplicationWillTerminateNotification object:nil];

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

- (id)init {
    self = [super init];
    if (self) {
        self.ready = NO;
        self.backgroundNotificationEnabled = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"] containsObject:@"remote-notification"]
                                    && kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0;
    }
    return self;
}

+ (void)takeOff {
    [UAirship takeOff:[UAConfig defaultConfig]];
}

+ (void)takeOff:(UAConfig *)config {

    // takeOff needs to be run on the main thread
    if (![[NSThread currentThread] isMainThread]) {
        NSException *mainThreadException = [NSException exceptionWithName:UAirshipTakeOffBackgroundThreadException
                                                                   reason:@"UAirship takeOff must be called on the main thread."
                                                                 userInfo:nil];
        [mainThreadException raise];
    }

    dispatch_once(&takeOffPred_, ^{
        [UAirship executeUnsafeTakeOff:config];
    });
}

/*
 * This is an unsafe version of takeOff - use takeOff: instead for dispatch_once
 */
+ (void)executeUnsafeTakeOff:(UAConfig *)config {
    // Airships only take off once!
    if (_sharedAirship) {
        return;
    }

    [UAirship setLogLevel:config.logLevel];

    _sharedAirship = [[UAirship alloc] init];
    _sharedAirship.config = config;

    // Ensure that app credentials have been passed in
    if (![config validate]) {

        UA_LERR(@"The AirshipConfig.plist file is missing and no application credentials were specified at runtime.");

        // Bail now. Don't continue the takeOff sequence.
        return;
    }

    UA_LINFO(@"App Key: %@", _sharedAirship.config.appKey);
    UA_LINFO(@"App Secret: %@", _sharedAirship.config.appSecret);
    UA_LINFO(@"Server: %@", _sharedAirship.config.deviceAPIURL);

    if (config.automaticSetupEnabled) {

        _sharedAirship.appDelegate = [[UAAppDelegateProxy alloc ]init];

        //swap pointers with the initial app delegate
        @synchronized ([UIApplication sharedApplication]) {
            _sharedAirship.appDelegate.originalAppDelegate = [UIApplication sharedApplication].delegate;
            _sharedAirship.appDelegate.airshipAppDelegate = [[UAAppDelegate alloc] init];
            [UIApplication sharedApplication].delegate = _sharedAirship.appDelegate;
        }
    }


    // Build a custom user agent with the app key and name
    [_sharedAirship configureUserAgent];

    // Set up analytics
    _sharedAirship.analytics = [[UAAnalytics alloc] initWithConfig:_sharedAirship.config];
    [_sharedAirship.analytics delayNextSend:UAAnalyticsFirstBatchUploadInterval];

    /*
     * Handle Debug Options
     */

    //For testing, set this value in AirshipConfig to clear out
    //the keychain credentials, as they will otherwise be persisted
    //even when the application is uninstalled.
    if (config.clearKeychain) {

        UA_LDEBUG(@"Deleting the keychain credentials");
        [UAKeychainUtils deleteKeychainValue:_sharedAirship.config.appKey];

        UA_LDEBUG(@"Deleting the UA device ID");
        [UAKeychainUtils deleteKeychainValue:kUAKeychainDeviceIDKey];
    }

    if (!config.inProduction) {
        [_sharedAirship validate];
    }

    if (config.cacheDiskSizeInMB > 0) {
        UA_LINFO("Registering UAURLProtocol");
        [NSURLProtocol registerClass:[UAURLProtocol class]];
    }

    // The singleton is now ready for use!
    _sharedAirship.ready = true;


    //create/setup user (begin listening for device token changes)
    [[UAUser defaultUser] initializeUser];

}

+ (void)handleAppDidFinishLaunchingNotification:(NSNotification *)notification {

    [[NSNotificationCenter defaultCenter] removeObserver:[UAirship class] name:UIApplicationDidFinishLaunchingNotification object:nil];

    if (!_sharedAirship) {
        UA_LERR(@"[UAirship takeOff] was not called in application:didFinishLaunchingWithOptions:");
        UA_LERR(@"Please ensure that [UAirship takeOff] is called synchronously before application:didFinishLaunchingWithOptions: returns");
        return;
    }

    NSDictionary *remoteNotification = [notification.userInfo objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];

    _sharedAirship.analytics.notificationUserInfo = remoteNotification;
    [_sharedAirship.analytics refreshSessionWhenActive];

    //Send Startup Analytics Info
    //init first event
    [_sharedAirship.analytics addEvent:[UAEventAppInit eventWithContext:nil]];


    // If the device is running iOS7 or greater, and the app delegate responds to
    // application:didReceiveRemoteNotification:fetchCompletionHandler:, it will
    // call the app delegate right after launch.
    
    BOOL skipNotifyPush = [[UIApplication sharedApplication].delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]
    && kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0;

    if (remoteNotification && !skipNotifyPush) {
        [[UAPush shared] handleNotification:remoteNotification
                           applicationState:[UIApplication sharedApplication].applicationState];
        [UAInboxPushHandler handleNotification:remoteNotification];
    }

    // Register now
    if ([UAirship shared].config.automaticSetupEnabled) {
        [[UAPush shared] registerForRemoteNotifications];
    }
}

+ (void)handleAppTerminationNotification:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:[UAirship class]  name:UIApplicationWillTerminateNotification object:nil];
    [UAirship land];
}

+ (void)land {

    if (!_sharedAirship) {
        return;
    }

    // add app_exit event
    [_sharedAirship.analytics addEvent:[UAEventAppExit eventWithContext:nil]];

    if (_sharedAirship.config.automaticSetupEnabled) {
        // swap pointers back to the initial app delegate
        @synchronized ([UIApplication sharedApplication]) {
            [UIApplication sharedApplication].delegate = _sharedAirship.appDelegate.originalAppDelegate;
        }
    }

    //Land common classes
    [UAUser land];
    
    //Land the modular libaries first
    [NSClassFromString(@"UAPush") land];
    [NSClassFromString(@"UAInbox") land];
    
    //Finally, release the airship!
    _sharedAirship = nil;

    takeOffPred_ = 0; // reset the dispatch_once_t flag for testing
}

+ (UAirship *)shared {
    return _sharedAirship;
}

#pragma mark -
#pragma mark DeviceToken get/set/utils

- (NSString *)deviceToken {
    return [[UAPush shared] deviceToken];
}

- (void)configureUserAgent {
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
    
    NSString *libVersion = [UAirshipVersion get];
    NSString *locale = [[NSLocale currentLocale] localeIdentifier];
    
    NSString *userAgent = [NSString stringWithFormat:@"%@ %@ (%@; %@ %@; UALib %@; %@; %@)",
                           appName, appVersion, deviceModel, osName, osVersion, libVersion, self.config.appKey, locale];
    
    UALOG(@"Setting User-Agent for UA requests to %@", userAgent);
    [UAHTTPRequest setDefaultUserAgentString:userAgent];
}

- (void)validate {
    // Background notification validation
    if (self.backgroundNotificationEnabled) {

        if (self.config.automaticSetupEnabled) {
            id delegate = self.appDelegate.originalAppDelegate;

            // If its automatic setup up, make sure if they are implementing their own app delegates, that they are
            // also implementing the new application:didReceiveRemoteNotification:fetchCompletionHandler: call.
            if ([delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:)]
                && ![delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {

                UA_LWARN(@"Application is set up to receive background notifications, but the app delegate only implements application:didReceiveRemoteNotification: and not application:didReceiveRemoteNotification:fetchCompletionHandler.  application:didReceiveRemoteNotification: will be ignored.");
            }
        } else {
            id delegate = [UIApplication sharedApplication].delegate;

            // They must implement application:didReceiveRemoteNotification:fetchCompletionHandler: to handle background
            // notifications
            if ([delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:)]
                && ![delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {

                UA_LWARN(@"Application is set up to receive background notifications, but the app delegate does not implements application:didReceiveRemoteNotification:fetchCompletionHandler:. Use either UAirship automaticSetupEnabled or implement a proper application:didReceiveRemoteNotification:fetchCompletionHandler: in the app delegate.");
            }
        }
    }

    // Push notification delegate validation
    id appDelegate = [UIApplication sharedApplication].delegate;
    if ([appDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
        id pushDelegate = [UAPush shared].pushNotificationDelegate;

        if ([pushDelegate respondsToSelector:@selector(receivedForegroundNotification:)]
            && ! [pushDelegate respondsToSelector:@selector(receivedForegroundNotification:fetchCompletionHandler:)]) {

             UA_LWARN(@"Application is configured with background remote notifications. PushNotificationDelegate should implement receivedForegroundNotification:fetchCompletionHandler: instead of receivedForegroundNotification:.  receivedForegroundNotification: will still be called.");

        }

        if ([pushDelegate respondsToSelector:@selector(launchedFromNotification:)]
            && ! [pushDelegate respondsToSelector:@selector(launchedFromNotification:fetchCompletionHandler:)]) {

            UA_LWARN(@"Application is configured with background remote notifications. PushNotificationDelegate should implement launchedFromNotification:fetchCompletionHandler: instead of launchedFromNotification:.  launchedFromNotification: will still be called.");
        }

        if ([pushDelegate respondsToSelector:@selector(receivedBackgroundNotification:)]
            && ! [pushDelegate respondsToSelector:@selector(receivedBackgroundNotification:fetchCompletionHandler:)]) {

            UA_LWARN(@"Application is configured with background remote notifications. PushNotificationDelegate should implement receivedBackgroundNotification:fetchCompletionHandler: instead of receivedBackgroundNotification:.  receivedBackgroundNotification: will still be called.");
        }
    }

    // -ObjC linker flag is set
    if (![[NSJSONSerialization class] respondsToSelector:@selector(stringWithObject:)]) {
        UA_LERR(@"UAirship library requires the '-ObjC' linker flag set in 'Other linker flags'.");
    }
}
@end

