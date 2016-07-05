/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

// Import the Urban Airship umbrella header using the framework
#import <AirshipKit/AirshipKit.h>
#import "AppDelegate.h"
#import "InboxDelegate.h"
#import "PushHandler.h"

#define kSimulatorWarningDisabledKey @"ua-simulator-warning-disabled"

@interface AppDelegate () <UARegistrationDelegate>
@property(nonatomic, strong) InboxDelegate *inboxDelegate;
@property(nonatomic, strong) PushHandler *pushHandler;

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

    config.messageCenterStyleConfig = @"UAMessageCenterDefaultStyle";

    // You can then programmatically override the plist values:
    // config.developmentAppKey = @"YourKey";
    // etc.

    // Call takeOff (which creates the UAirship singleton)
    [UAirship takeOff:config];

    // Print out the application configuration for debugging (optional)
    NSLog(@"Config:\n%@", [config description]);

    // Set the icon badge to zero on startup (optional)
    [[UAirship push] resetBadge];

    // Set the notification options required for the app (optional). This value defaults
    // to badge, alert and sound, so it's only necessary to set it if you want
    // to add or remove options.
    [UAirship push].notificationOptions = (UANotificationOptionAlert |
                                           UANotificationOptionBadge |
                                           UANotificationOptionSound);


    // Set a custom delegate for handling message center events
    self.inboxDelegate = [[InboxDelegate alloc] initWithRootViewController:self.window.rootViewController];
    [UAirship inbox].delegate = self.inboxDelegate;

    self.pushHandler = [[PushHandler alloc] init];
    [UAirship push].pushNotificationDelegate = self.pushHandler;

    [UAirship push].registrationDelegate = self;

    // User notifications will not be enabled until userPushNotificationsEnabled is
    // set YES on UAPush. Once enabled, the setting will be persisted and the user
    // will be prompted to allow notifications. You should wait for a more appropriate
    // time to enable push to increase the likelihood that the user will accept
    // notifications.
    // [UAirship push].userPushNotificationsEnabled = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshMessageCenterBadge) name:UAInboxMessageListUpdatedNotification object:nil];

    return YES;
}

- (void)refreshMessageCenterBadge {

    UITabBarItem *messageCenterTab = [[[(UITabBarController *)self.window.rootViewController tabBar] items] objectAtIndex:2];

    if ([UAirship inbox].messageList.unreadCount > 0) {
        [messageCenterTab setBadgeValue:[NSString stringWithFormat:@"%ld", (long)[UAirship inbox].messageList.unreadCount]];
    } else {
        [messageCenterTab setBadgeValue:nil];
    }
}

- (void)failIfSimulator {

    // If it's not a simulator return early
    if (TARGET_OS_SIMULATOR == 0 && TARGET_IPHONE_SIMULATOR == 0) {
        return;
    }

    NSLog(@"You will not be able to receive push notifications in the simulator.");

    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSimulatorWarningDisabledKey]) {
        return;
    }

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Notice"
                                                                             message:@"You will not be able to receive push notifications in the simulator."
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *disableAction = [UIAlertAction actionWithTitle:@"Disable Warning" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kSimulatorWarningDisabledKey];
                                                          }];

    [alertController addAction:disableAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:cancelAction];

    // Let the UI finish launching first so it doesn't complain about the lack of a root view controller
    // Delay execution of the block for 1/2 second.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    });
}

-(void)applicationWillEnterForeground:(UIApplication *)application {
    [self refreshMessageCenterBadge];
}

- (void)registrationSucceededForChannelID:(NSString *)channelID deviceToken:(nonnull NSString *)deviceToken {

    [[NSNotificationCenter defaultCenter] postNotificationName:@"channelIDUpdated" object:self userInfo:nil];
}

@end
