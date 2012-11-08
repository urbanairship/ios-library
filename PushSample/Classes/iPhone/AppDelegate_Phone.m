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
    [self failIfSimulator];
    
    //Init Airship launch options
    NSMutableDictionary *takeOffOptions = [[[NSMutableDictionary alloc] init] autorelease];
    [takeOffOptions setValue:launchOptions forKey:UAirshipTakeOffOptionsLaunchOptionsKey];
    
    // By setting the default push enabled value to no, you can avoid presenting the user with push notifications
    // right at the first installation of the app. By navigating to the Settings screen in app and setting the toggle
    // to on, you'll trigger the actual registration with UIApplication and the UIAlertView asking for permission
    // for Push notifications.
    [UAPush setDefaultPushEnabledValue:NO];
    
    // Create Airship singleton that's used to talk to Urban Airhship servers.
    // Please populate AirshipConfig.plist with your info from http://go.urbanairship.com
    [UAirship takeOff:takeOffOptions];

    [[UAPush shared] resetBadge];//zero badge on startup
    
    // Register for remote notfications as normal. With the default value of push set to no, UAPush will
    // record the desired remote notifcation types, but not register for push notfications with UIApplication until
    // push is enabled.
    [[UAPush shared] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                                         UIRemoteNotificationTypeSound |
                                                         UIRemoteNotificationTypeAlert)];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    UALOG(@"Application did become active.");
    [[UAPush shared] resetBadge]; //zero badge when resuming from background
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    UALOG(@"APN device token: %@", deviceToken);
    // Updates the device token and registers the token with UA
    [[UAPush shared] registerDeviceToken:deviceToken];
    
    
    /*
     * Some example cases where user notification may be warranted
     *
     * This code will alert users who try to enable notifications
     * from the settings screen, but cannot do so because
     * notications are disabled in some capacity through the settings
     * app.
     * 
     */
    
    /*
    
    //Do something when notifications are disabled altogther
    if ([application enabledRemoteNotificationTypes] == UIRemoteNotificationTypeNone) {
        UALOG(@"iOS Registered a device token, but nothing is enabled!");
        
        //only alert if this is the first registration, or if push has just been
        //re-enabled
        if ([UAirship shared].deviceToken != nil) { //already been set this session
            NSString* okStr = @"OK";
            NSString* errorMessage =
            @"Unable to turn on notifications. Use the \"Settings\" app to enable notifications.";
            NSString *errorTitle = @"Error";
            UIAlertView *someError = [[UIAlertView alloc] initWithTitle:errorTitle
                                                                message:errorMessage
                                                               delegate:nil
                                                      cancelButtonTitle:okStr
                                                      otherButtonTitles:nil];
            
            [someError show];
            [someError release];
        }
        
    //Do something when some notification types are disabled
    } else if ([application enabledRemoteNotificationTypes] != [UAPush shared].notificationTypes) {
        
        UALOG(@"Failed to register a device token with the requested services. Your notifications may be turned off.");
        
        //only alert if this is the first registration, or if push has just been
        //re-enabled
        if ([UAirship shared].deviceToken != nil) { //already been set this session
            
            UIRemoteNotificationType disabledTypes = [application enabledRemoteNotificationTypes] ^ [UAPush shared].notificationTypes;
            
            
            
            NSString* okStr = @"OK";
            NSString* errorMessage = [NSString stringWithFormat:@"Unable to turn on %@. Use the \"Settings\" app to enable these notifications.", [UAPush pushTypeString:disabledTypes]];
            NSString *errorTitle = @"Error";
            UIAlertView *someError = [[UIAlertView alloc] initWithTitle:errorTitle
                                                                message:errorMessage
                                                               delegate:nil
                                                      cancelButtonTitle:okStr
                                                      otherButtonTitles:nil];
            
            [someError show];
            [someError release];
        }
    }
     
     */
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error {
    UALOG(@"Failed To Register For Remote Notifications With Error: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    UALOG(@"Received remote notification: %@", userInfo);
    [[UAPush shared] handleNotification:userInfo applicationState:application.applicationState];
    [[UAPush shared] resetBadge]; // zero badge after push received
}

- (void)applicationWillTerminate:(UIApplication *)application {
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
