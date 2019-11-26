/* Copyright Airship and Contributors */

@import Airship;

#import "AppDelegate.h"
#import "MessageCenterDelegate.h"
#import "PushHandler.h"
#import "HomeViewController.h"
#import "MessageCenterViewController.h"

#define kSimulatorWarningDisabledKey @"ua-simulator-warning-disabled"

NSString *const HomeStoryboardID = @"home";
NSString *const PushSettingsStoryboardID = @"push_settings";
NSString *const MessageCenterStoryboardID = @"message_center";
NSString *const DebugStoryboardID = @"debug";
NSString *const InAppAutomationStoryboardID = @"in_app_automation";

NSUInteger const HomeTab = 0;
NSUInteger const MessageCenterTab = 1;
NSUInteger const DebugTab = 2;

@interface AppDelegate () <UARegistrationDelegate, UADeepLinkDelegate>
@property(nonatomic, strong) MessageCenterDelegate *messageCenterDelegate;
@property(nonatomic, strong) PushHandler *pushHandler;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Display a warning to developers that push notifications do not work in the simulator
    // You should remove this in your app.
    [self failIfSimulator];

    // Set log level for debugging config loading (optional)
    // It will be set to the value in the loaded config upon takeOff
    [UAirship setLogLevel:UALogLevelTrace];

    // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
    // or set runtime properties here.
    UAConfig *config = [UAConfig defaultConfig];

    if (![config validate]) {
        [self showInvalidConfigAlert];
        return YES;
    }

    config.messageCenterStyleConfig = @"UAMessageCenterDefaultStyle";

    // You can then programmatically override the plist values:
    // config.developmentAppKey = @"YourKey";
    // etc.

    // Call takeOff (which creates the UAirship singleton)
    [UAirship takeOff:config];

    // Print out the application configuration for debugging (optional)
    NSLog(@"Config:\n%@", [config description]);

    // Call takeOff (which initializes the Airship DebugKit)
    [AirshipDebug takeOff];
    
    // Set the icon badge to zero on startup (optional)
    [[UAirship push] resetBadge];

    // Set the notification options required for the app (optional). This value defaults
    // to badge, alert and sound, so it's only necessary to set it if you want
    // to add or remove options.
    [UAirship push].notificationOptions = (UANotificationOptionAlert |
                                           UANotificationOptionBadge |
                                           UANotificationOptionSound);

    // Set a custom delegate for handling message center events
    self.messageCenterDelegate = [[MessageCenterDelegate alloc] initWithRootViewController:self.window.rootViewController];
    [UAMessageCenter shared].displayDelegate = self.messageCenterDelegate;

    self.pushHandler = [[PushHandler alloc] init];
    [UAirship push].pushNotificationDelegate = self.pushHandler;

    [UAirship push].registrationDelegate = self;
    [UAirship shared].deepLinkDelegate = self;

    // User notifications will not be enabled until userPushNotificationsEnabled is
    // set YES on UAPush. Once enabled, the setting will be persisted and the user
    // will be prompted to allow notifications. You should wait for a more appropriate
    // time to enable push to increase the likelihood that the user will accept
    // notifications.
    // [UAirship push].userPushNotificationsEnabled = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshMessageCenterBadge)
                                                 name:UAInboxMessageListUpdatedNotification object:nil];
    return YES;
}

- (void)showInvalidConfigAlert {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Invalid AirshipConfig.plist" message:@"The AirshipConfig.plist must be a part of the app bundle and include a valid appkey and secret for the selected production level." preferredStyle:UIAlertControllerStyleActionSheet];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Exit Application" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        exit(1);
    }]];

    dispatch_async(dispatch_get_main_queue(), ^{
        alertController.popoverPresentationController.sourceView = self.window.rootViewController.view;

        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    });
}

- (void)refreshMessageCenterBadge {
    dispatch_async(dispatch_get_main_queue(), ^{
        UITabBarItem *messageCenterTab = [[[(UITabBarController *)self.window.rootViewController tabBar] items] objectAtIndex:MessageCenterTab];

        if ([UAMessageCenter shared].messageList.unreadCount > 0) {
            [messageCenterTab setBadgeValue:[NSString stringWithFormat:@"%ld", (long)[UAMessageCenter shared].messageList.unreadCount]];
        } else {
            [messageCenterTab setBadgeValue:nil];
        }
    });
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
        alertController.popoverPresentationController.sourceView = self.window.rootViewController.view;

        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    });
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [self refreshMessageCenterBadge];
}

#pragma mark -
#pragma mark Deep link handling

// Available Deep Links:
//    - <scheme>://deeplink/home
//    - <scheme>://deeplink/inbox
//    - <scheme>://deeplink/inbox/message/<messageId>
//    - <scheme>://deeplink/settings
//    - <scheme>://deeplink/settings/tags

- (void)receivedDeepLink:(NSURL *_Nonnull)url completionHandler:(void (^_Nonnull)(void))completionHandler {
    NSMutableArray<NSString *>*pathComponents = [url.pathComponents mutableCopy];
    if ([pathComponents[0] isEqualToString:@"/"]) {
        [pathComponents removeObjectAtIndex:0];
    }

    UITabBarController *tabController = (UITabBarController *)self.window.rootViewController;

    // map existing deep links to new paths
    if ([[pathComponents[0] lowercaseString] isEqualToString:PushSettingsStoryboardID]) {
        pathComponents = [[[NSURL URLWithString:@"settings"] pathComponents] mutableCopy];
    } else if ([[pathComponents[0] lowercaseString] isEqualToString:InAppAutomationStoryboardID]) {
        pathComponents = [[[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",DebugStoryboardID,AirshipDebug.automationViewName]] pathComponents] mutableCopy];
    }
    
    // map deeplinks to storyboards paths
    if ([[pathComponents[0] lowercaseString] isEqualToString:@"home"]) {
        pathComponents[0] = HomeStoryboardID;
    } else if ([[pathComponents[0] lowercaseString] isEqualToString:@"inbox"]) {
        pathComponents[0] = MessageCenterStoryboardID;
    } else if ([[pathComponents[0] lowercaseString] isEqualToString:@"settings"]) {
        NSMutableArray<NSString *>*newPathComponents = [[[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",DebugStoryboardID,AirshipDebug.deviceInfoViewName]] pathComponents] mutableCopy];
        [pathComponents removeObjectAtIndex:0];
        if (pathComponents.count > 0) {
            if ([[pathComponents[0] lowercaseString] isEqualToString:@"tags"]) {
                [newPathComponents addObject:AirshipDebug.tagsViewName];
            } else {
                [newPathComponents addObjectsFromArray:pathComponents];
            }
        }
        pathComponents = newPathComponents;
    }

    // execute deep link
    if ([[pathComponents[0] lowercaseString] isEqualToString:HomeStoryboardID]) {
        // switch to home tab
        tabController.selectedIndex = HomeTab;
    } else if ([[pathComponents[0] lowercaseString] isEqualToString:MessageCenterStoryboardID]) {
        // switch to inbox tab
        tabController.selectedIndex = MessageCenterTab;
        
        // get rest of deep link
        [pathComponents removeObjectAtIndex:0];
        
        if ((pathComponents.count == 0) || (![pathComponents[0] isEqualToString:@"message"])) {
            [[UAMessageCenter shared] display];
        } else {
            // remove "message" from front of url
            [pathComponents removeObjectAtIndex:0];
            NSString *messageId;
            if (pathComponents.count > 0) {
                messageId = pathComponents[0];
            }
            [[UAMessageCenter shared] displayMessageForID:messageId];
        }
    } else if ([[pathComponents[0] lowercaseString] isEqualToString:DebugStoryboardID]) {
        // switch to debug tab
        tabController.selectedIndex = DebugTab;
        
        // get rest of deep link
        [pathComponents removeObjectAtIndex:0];
        [AirshipDebug showView:[NSURL fileURLWithPath:[NSString pathWithComponents:pathComponents]]];
    }

    completionHandler();
}

@end
