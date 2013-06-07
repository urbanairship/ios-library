/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

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

#import "SampleAppDelegate.h"

#import "UAConfig.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAAnalytics.h"

@implementation SampleAppDelegate

@synthesize window;
@synthesize controller;

- (void)dealloc {
    [controller release];
    [window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Override point for customization after application launch
    [window addSubview:controller.view];
    [window makeKeyAndVisible];
    
    // Display a UIAlertView warning developers that push notifications do not work in the simulator
    // You should remove this in your app.
    [self failIfSimulator];
    
    // This prevents the UA Library from registering with UIApplcation by default when
    // registerForRemoteNotifications is called. This will allow you to prompt your
    // users at a later time. This gives your app the opportunity to explain the benefits
    // of push or allows users to turn it on explicitly in a settings screen.
    // If you just want everyone to immediately be prompted for push, you can
    // leave this line out.
    [UAPush setDefaultPushEnabledValue:NO];

    // Set log level for debugging config loading
    // It will be set to the value in the loaded config on takeOff
    [UAirship setLogLevel:UALogLevelTrace];

    // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
    // or set runtime properties here.
    UAConfig *config = [UAConfig defaultConfig];

    // Call takeOff (which creates the UAirship singleton)
    [UAirship takeOff:config];

    UA_LDEBUG(@"Config:\n%@", [config description]);

    // Set the icon badge to zero on startup (optional)
    [[UAPush shared] resetBadge];
    
    // Register for remote notfications with the UA Library. With the default value of push set to no,
    // UAPush will record the desired remote notifcation types, but not register for
    // push notfications as mentioned above. When push is enabled at a later time, the registration
    // will occur normally. This call is required.
    [[UAPush shared] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                                         UIRemoteNotificationTypeSound |
                                                         UIRemoteNotificationTypeAlert)];
    
    // Handle any incoming incoming push notifications.
    // This will invoke `handleBackgroundNotification` on your UAPushNotificationDelegate.
    // TODO: call this automatically? figure this out with the new delegate structure
    [[UAPush shared] handleNotification:[launchOptions valueForKey:UIApplicationLaunchOptionsRemoteNotificationKey]
                       applicationState:application.applicationState];

    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    UA_LDEBUG(@"Application did become active.");
    
    // Set the icon badge to zero on resume (optional)
    [[UAPush shared] resetBadge];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    
    UA_LINFO(@"Received remote notification (in appDelegate): %@", userInfo);

    // Optionally provide a delegate that will be used to handle notifications received while the app is running
    // [UAPush shared].delegate = your custom push delegate class conforming to the UAPushNotificationDelegate protocol
    
    // Reset the badge after a push received (optional)
    [[UAPush shared] resetBadge];
}

- (void)failIfSimulator {
    if ([[[UIDevice currentDevice] model] rangeOfString:@"Simulator"].location != NSNotFound) {
        UIAlertView *someError = [[UIAlertView alloc] initWithTitle:@"Notice"
                                                            message:@"You will not be able to recieve push notifications in the simulator."
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];

        [someError show];
        [someError release];
    }
}

@end
