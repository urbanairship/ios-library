/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

// Import the Urban Airship umbrella header, using either
// the framework or the header search paths
#if __has_include("AirshipKit/AirshipKit.h")
#import <AirshipKit/AirshipKit.h>
#else
#import "AirshipLib.h"
#endif

#import "AppDelegate.h"

#define kSimulatorWarningDisabledKey @"ua-simulator-warning-disabled"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Display a UIAlertView warning developers that push notifications do not work in the simulator
    // You should remove this in your app.
    [self failIfSimulator];

    // Set log level for debugging config loading (optional)
    // It will be set to the value in the loaded config upon takeOff
    [UAirship setLogLevel:UALogLevelTrace];

    // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
    // or set runtime properties here.
    UAConfig *config = [UAConfig defaultConfig];

    // You can then programmatically override the plist values:
    // config.developmentAppKey = @"YourKey";
    // etc.

    // Call takeOff (which creates the UAirship singleton)
    [UAirship takeOff:config];

    // Print out the application configuration for debugging (optional)
    UA_LDEBUG(@"Config:\n%@", [config description]);

    // Set the icon badge to zero on startup (optional)
    [[UAirship push] resetBadge];

    // Set the notification types required for the app (optional). This value defaults
    // to badge, alert and sound, so it's only necessary to set it if you want
    // to add or remove types.
    [UAirship push].userNotificationTypes = (UIUserNotificationTypeAlert |
                                             UIUserNotificationTypeBadge |
                                             UIUserNotificationTypeSound);

    // User notifications will not be enabled until userPushNotificationsEnabled is
    // set YES on UAPush. Once enabled, the setting will be persisted and the user
    // will be prompted to allow notifications. You should wait for a more appropriate
    // time to enable push to increase the likelihood that the user will accept
    // notifications.
    // [UAirship push].userPushNotificationsEnabled = YES;

    return YES;
}

- (void)failIfSimulator {

    // If it's not a simulator return early
    if (TARGET_OS_SIMULATOR == 0 && TARGET_IPHONE_SIMULATOR == 0) {
        return;
    }

    UA_LDEBUG(@"You will not be able to receive push notifications in the simulator.");

    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSimulatorWarningDisabledKey]) {
        return;
    }

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Notice"
                                                                             message:@"You will not be able to receive push notifications in the simulator."
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *disableAction = [UIAlertAction actionWithTitle:@"Disable Warning" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kSimulatorWarningDisabledKey];}];

    [alertController addAction:disableAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:cancelAction];

    // Let the UI finish launching first so it doesn't complain about the lack of a root view controller
    // Delay execution of the block for 1/2 second.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    });
}

- (void)registrationSucceededForChannelID:(NSString *)channelID deviceToken:(nonnull NSString *)deviceToken {

    [[NSNotificationCenter defaultCenter] postNotificationName:@"channelIDUpdated" object:self userInfo:nil];
}

@end
