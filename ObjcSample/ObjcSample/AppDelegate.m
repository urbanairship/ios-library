/* Copyright Urban Airship and Contributors */

#import "AppDelegate.h"

@import AirshipWrapper;

@interface AppDelegate () <UADeepLinkDelegate, UAMessageCenterDisplayDelegate,
                           UAPreferenceCenterOpenDelegate>

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.

    UAConfig *cfg = [UAConfig defaultConfigWithError: nil];
    cfg.developmentLogLevel = UAAirshipLogLevelVerbose;
    cfg.productionLogLevel = UAAirshipLogLevelVerbose;

    [UAAirship takeOff:cfg launchOptions:launchOptions error: nil];
    UAAirship.deepLinkDelegate = self;

    UAMessageCenter *messageCenter = [UAMessageCenter new];
    [messageCenter display];
    messageCenter.displayDelegate = self;

    UAPush *push = [UAPush new];
    push.notificationOptions = UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionSound;
    push.defaultPresentationOptions = UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList ;
    push.autobadgeEnabled = YES;

    UAPreferenceCenter *pc = [UAPreferenceCenter new];
    pc.openDelegate = self;

    return YES;
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:
        (UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return
        [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                       sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application
    didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running,
    // this will be called shortly after
    // application:didFinishLaunchingWithOptions. Use this method to release any
    // resources that were specific to the discarded scenes, as they will not
    // return.
}

- (void)receivedDeepLink:(NSURL *_Nonnull)deepLink
       completionHandler:(void (^_Nonnull)(void))completionHandler {
}

- (void)dismissMessageCenter {
}

- (void)displayMessageCenter {
}

- (void)displayMessageCenterForMessageID:(NSString *_Nonnull)messageID {
}

- (BOOL)openPreferenceCenter:(NSString *_Nonnull)preferenceCenterID {
    return YES;
}

@end
