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
#import "InboxSampleAppDelegate.h"

#import "InboxSampleViewController.h"
#import "UAInboxDefaultJSDelegate.h"
#import "UAInboxPushHandler.h"
#import "UAInboxNavUI.h"
#import "UAInboxUI.h"

#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessageList.h"


@implementation InboxSampleAppDelegate

@synthesize window;
@synthesize viewController;
@synthesize navigationController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.navigationController = [[[UINavigationController alloc] init] autorelease];
    [navigationController pushViewController:viewController animated:NO];
    [window addSubview:navigationController.view];
    [window makeKeyAndVisible];

    [self failIfSimulator];
    
    //[UAInbox useCustomUI: [UAInboxNavUI class]];
    
    //Init Airship launch options
    NSMutableDictionary *takeOffOptions = [[[NSMutableDictionary alloc] init] autorelease];
    [takeOffOptions setValue:launchOptions forKey:UAirshipTakeOffOptionsLaunchOptionsKey];
    
    NSMutableDictionary *analyticsOptions = [[[NSMutableDictionary alloc] init] autorelease];
    [analyticsOptions setValue:@"NO" forKey:UAAnalyticsOptionsLoggingKey];
    [takeOffOptions setValue:analyticsOptions forKey:UAirshipTakeOffOptionsAnalyticsKey];
    
    // To use your own pre-existing inbox credentials, uncomment and modify these lines:
    //[takeOffOptions setValue:@"4cf54407a9ee256d9400000c" forKey:UAAirshipTakeOffOptionsDefaultUsername];
    //[takeOffOptions setValue:@"GUvTvih4RcaqZZOAsLvKXQ" forKey:UAAirshipTakeOffOptionsDefaultPassword];
    
    // Create Airship singleton that's used to talk to Urban Airship servers.
    // Please populate AirshipConfig.plist with your info from http://go.urbanairship.com
    [UAirship takeOff:takeOffOptions];
    
    // Register for notifications
    [[UIApplication sharedApplication]
     registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                         UIRemoteNotificationTypeSound |
                                         UIRemoteNotificationTypeAlert)];

    // Config Inbox behaviour before UAInboxPushHandler since it may need it
    // when launching from notification
    
    [UAInbox useCustomUI:[UAInboxUI class]];
    [UAInbox shared].pushHandler.delegate = [UAInboxUI shared];

    // Optional: Delegate for JavaScript callback
    jsDelegate = [[UAInboxDefaultJSDelegate alloc] init];
    [UAInbox shared].jsDelegate = jsDelegate;
    
    // For modal UI:
    [UAInboxUI shared].inboxParentController = navigationController;
    [UAInboxUI shared].useOverlay = YES;
    
    // For Navigation UI:
    [UAInboxNavUI shared].inboxParentController = navigationController;
    [UAInboxNavUI shared].useOverlay = YES;
    [UAInboxNavUI shared].popoverSize = CGSizeMake(600, 1100);
    
    
    //TODO: think about clean up / dealloc for multiple UI classes
    
    [UAInboxPushHandler handleLaunchOptions:launchOptions];
	
	if([[UAInbox shared].pushHandler hasLaunchMessage]) {
		[[[UAInbox shared] uiClass] loadLaunchMessage];
	}

    // Return value is ignored for push notifications, so it's safer to return
    // NO by default for other resources
    return NO;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    UALOG(@"APN device token: %@", deviceToken);
    // Updates the device token and registers the token with UA
    [[UAirship shared] registerDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error {
    UALOG(@"did Fail To Register For Remote Notifications With Error: %@", error);
}

// Copy and paste this method into your AppDelegate to recieve push
// notifications for your application while the app is running.
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [UAInboxPushHandler handleNotification:userInfo];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    
    //TODO: clean up all UI classes
    
    [UAirship land];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    UAInbox *inbox = [UAInbox shared];
    if (inbox != nil && inbox.messageList != nil && inbox.messageList.unreadCount >= 0) {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:inbox.messageList.unreadCount];
    }
}

- (void)dealloc {
    RELEASE_SAFELY(jsDelegate);
    self.viewController = nil;
    self.navigationController = nil;
    self.window = nil;
    
    [super dealloc];
}

- (void)failIfSimulator {
    if ([[[UIDevice currentDevice] model] rangeOfString:@"Simulator"].location != NSNotFound) {
        UIAlertView *someError = [[UIAlertView alloc] initWithTitle:@"Notice"
                                                            message:@"You can see UAInbox in the simulator, but you will not be able to recieve push notifications"
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];

        [someError show];
        [someError release];
    }
}

@end
