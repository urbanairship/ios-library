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

#import "InboxSampleAppDelegate.h"

#import "InboxSampleViewController.h"
#import "UAInboxPushHandler.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "InboxDelegate.h"
#import "PushNotificationDelegate.h"

#define kSimulatorWarningDisabledKey @"ua-simulator-warning-disabled"

@interface InboxSampleAppDelegate()
@property (nonatomic, strong) InboxDelegate *inboxDelegate;
@property (nonatomic, strong) PushNotificationDelegate *pushDelegate;
@end

@implementation InboxSampleAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    UINavigationController *strongNavigationController = self.navigationController;
    [self.window setRootViewController:strongNavigationController];
    [self.window makeKeyAndVisible];

    // Display a UIAlertView warning developers that push notifications do not work in the simulator
    // You should remove this in your app.
    [self failIfSimulator];

    // Set log level for debugging config loading (optional)
    // It will be set to the value in the loaded config upon takeOff
    [UAirship setLogLevel:UALogLevelTrace];

    // Call takeOff (which creates the UAirship singleton). This call is
    // required.
    //
    // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
    [UAirship takeOff];

    // Configure Inbox behavior before UAInboxPushHandler since it may need it
    // when launching from notification

    InboxSampleViewController *sampleViewController = self.viewController;

    // Set the inbox delegate to handle inbox display requests
    self.inboxDelegate = [[InboxDelegate alloc] init];
    [UAirship inbox].delegate = self.inboxDelegate;

    // Set the sample view controller as the push notification delegate
    self.pushDelegate = [[PushNotificationDelegate alloc] init];
    [UAirship push].pushNotificationDelegate = self.pushDelegate;


    // Set a default size for the sample popover interface
    sampleViewController.popoverSize = CGSizeMake(600, 1100);

    // Use an overlay UI for simple message display
    sampleViewController.useOverlay = YES;

    // User notifications will not be enabled until userPushNotificationsEnabled is
    // set YES on UAPush. Once enabled, the setting will be persisted and the user
    // will be prompted to allow notifications. You should wait for a more appropriate
    // time to enable push to increase the likelihood that the user will accept
    // notifications.
    [UAirship push].userPushNotificationsEnabled = YES;

    // Return value is ignored for push notifications, so it's safer to return
    // NO by default for other resources
    return NO;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    
    // Set the application's badge to the number of unread messages
    if ([UAirship inbox].messageList.unreadCount >= 0) {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[UAirship inbox].messageList.unreadCount];
    }
}

- (void)failIfSimulator {

    UA_LDEBUG(@"You will not be able to receive push notifications in the simulator.");

    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSimulatorWarningDisabledKey]) {
        return;
    }

    if ([[[UIDevice currentDevice] model] rangeOfString:@"Simulator"].location != NSNotFound) {
        UIAlertView *someError = [[UIAlertView alloc] initWithTitle:@"Notice"
                                                            message:@"You can see UAInbox in the simulator, but you will not be able to receive push notifications."
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:@"Disable Warning", nil];

        [someError show];
    }

}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{

    if (buttonIndex == alertView.firstOtherButtonIndex){
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kSimulatorWarningDisabledKey];
    }
}

@end
