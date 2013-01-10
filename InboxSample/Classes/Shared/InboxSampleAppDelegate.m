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
#import "InboxSampleAppDelegate.h"

#import "InboxSampleViewController.h"
#import "UAInboxDefaultJSDelegate.h"
#import "UAInboxPushHandler.h"
#import "UAInboxNavUI.h"
#import "UAInboxUI.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAPush.h"
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

    // Display a UIAlertView warning developers that push notifications do not work in the simulator
    // You should remove this in your app.
    [self failIfSimulator];
    
    //[UAInbox useCustomUI: [UAInboxNavUI class]];
    
    //Create Airship options dictionary and add the required UIApplication launchOptions
    NSMutableDictionary *takeOffOptions = [NSMutableDictionary dictionary];
    [takeOffOptions setValue:launchOptions forKey:UAirshipTakeOffOptionsLaunchOptionsKey];
    
    // To use your own pre-existing inbox credentials, uncomment and modify these lines:
    // [takeOffOptions setValue:@"TheExistingUsername" forKey:UAAirshipTakeOffOptionsDefaultUsername];
    // [takeOffOptions setValue:@"TheExistingPassword" forKey:UAAirshipTakeOffOptionsDefaultPassword];
    
    // Call takeOff (which creates the UAirship singleton), passing in the launch options so the
    // library can properly record when the app is launched from a push notification. This call is
    // required.
    //
    // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
    [UAirship takeOff:takeOffOptions];
    
    // Register for remote notfications with the UA Library. The library will register with
    // iOS if push is enabled on UAPush.
    [[UAPush shared] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                                         UIRemoteNotificationTypeSound |
                                                         UIRemoteNotificationTypeAlert)];

    // Configure Inbox behaviour before UAInboxPushHandler since it may need it
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
	
    // Handle an incoming Rich Push message
	if ([[UAInbox shared].pushHandler hasLaunchMessage]) {
		[[[UAInbox shared] uiClass] loadLaunchMessage];
	}

    // Return value is ignored for push notifications, so it's safer to return
    // NO by default for other resources
    return NO;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    UA_LINFO(@"APNS device token: %@", deviceToken);
    
    // Updates the device token and registers the token with UA. This call is required.
    [[UAPush shared] registerDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error {
    UA_LERR(@"did Fail To Register For Remote Notifications With Error: %@", error);
}


- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    
    // Send the alert to UA so that it can be handled and tracked as a direct response. This call
    // is required.
    [UAInboxPushHandler handleNotification:userInfo];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Tear down UA services
    [UAirship land];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    
    // Set the application's badge to the number of unread messages
    UAInbox *inbox = [UAInbox shared];
    if (inbox && inbox.messageList && inbox.messageList.unreadCount >= 0) {
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
