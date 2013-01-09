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

#import "AppDelegate_Phone.h"

#import "UAirship.h"
#import "UAPush.h"
#import "UAAnalytics.h"

@implementation AppDelegate_Phone

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
    
    //Init Airship launch options
    NSMutableDictionary *takeOffOptions = [NSMutableDictionary dictionaryWithObject:launchOptions
                                                                             forKey:UAirshipTakeOffOptionsLaunchOptionsKey];

    // Call takeOff (which creates the UAirship singleton), passing in the launch options so the
    // library can properly record when the app is launched from a push notification
    //
    // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
    [UAirship takeOff:takeOffOptions];

    // Set the icon badge to zero on startup (optional)
    [[UAPush shared] resetBadge];
    
    // Register for remote notfications. With the default value of push set to no,
    // UAPush will record the desired remote notifcation types, but not register for
    // push notfications as mentioned above.
    // When push is enabled at a later time, the registration will occur as normal.
    [[UAPush shared] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                                         UIRemoteNotificationTypeSound |
                                                         UIRemoteNotificationTypeAlert)];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    UA_LDEBUG(@"Application did become active.");
    
    // Set the icon badge to zero on resume (optional)
    [[UAPush shared] resetBadge];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    UA_LINFO(@"APNS device token: %@", deviceToken);
    
    // Updates the device token and registers the token with UA. This won't occur until
    // push is enabled if the outlined process is followed.
    // This call is required.
    [[UAPush shared] registerDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error {
    UA_LERR(@"Failed To Register For Remote Notifications With Error: %@", error);
}


- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    
    UA_LINFO(@"Received remote notification: %@", userInfo);
    
    // Send the alert to UA so that it can be handled and tracked as a direct response (required).
    [[UAPush shared] handleNotification:userInfo applicationState:application.applicationState];
    
    // Optionally provide a delegate that will be used to handle notifications received while the app is running
    // [UAPush shared].delegate = your custom push delegate class conforming to the UAPushNotificationDelegate protocol
    
    // Reset the badge after a push received (optional)
    [[UAPush shared] resetBadge];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    
    // Tear down UA services
    [UAirship land];
}

- (void)failIfSimulator {
    if ([[[UIDevice currentDevice] model] compare:@"iPhone Simulator"] == NSOrderedSame) {
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
