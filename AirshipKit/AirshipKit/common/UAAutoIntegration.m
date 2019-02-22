/* Copyright Urban Airship and Contributors */

#import "UAAutoIntegration+Internal.h"
#import "UAirship+Internal.h"
#import "UAAppIntegration+Internal.h"
#import "UASwizzler+Internal.h"
#import "UADispatcher+Internal.h"

static UAAutoIntegration *instance_;

@implementation UAAutoIntegrationDummyDelegate
static dispatch_once_t onceToken;
@end

@interface UAAutoIntegration()
@property (nonatomic, strong) UASwizzler *appDelegateSwizzler;
@property (nonatomic, strong) UASwizzler *notificationDelegateSwizzler;
@property (nonatomic, strong) UASwizzler *notificationCenterSwizzler;
@property (nonatomic, strong) UAAutoIntegrationDummyDelegate *dummyNotificationDelegate;
@end

@implementation UAAutoIntegration

+ (void)integrate {
    dispatch_once(&onceToken, ^{
        instance_ = [[UAAutoIntegration alloc] init];
        [instance_ swizzleAppDelegate];
        [instance_ swizzleNotificationCenter];
    });
}

+ (void)reset {
    if (instance_) {
        onceToken = 0;
        instance_.appDelegateSwizzler = nil;
        instance_.notificationDelegateSwizzler = nil;
        instance_.notificationCenterSwizzler = nil;
        instance_.dummyNotificationDelegate = nil;
        instance_ = nil;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.dummyNotificationDelegate = [[UAAutoIntegrationDummyDelegate alloc] init];
    }

    return self;
}

- (void)swizzleAppDelegate {
    id delegate = [UIApplication sharedApplication].delegate;
    if (!delegate) {
        UA_LERR(@"App delegate not set, unable to perform automatic setup.");
        return;
    }

    Class class = [delegate class];

    self.appDelegateSwizzler = [UASwizzler swizzlerForClass:class];

    // Device token
    [self.appDelegateSwizzler swizzle:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
                             protocol:@protocol(UIApplicationDelegate)
                       implementation:(IMP)ApplicationDidRegisterForRemoteNotificationsWithDeviceToken];

    // Device token errors
    [self.appDelegateSwizzler swizzle:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)
                             protocol:@protocol(UIApplicationDelegate)
                       implementation:(IMP)ApplicationDidFailToRegisterForRemoteNotificationsWithError];

    // Content-available notifications
    [self.appDelegateSwizzler swizzle:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
                             protocol:@protocol(UIApplicationDelegate)
                       implementation:(IMP)ApplicationDidReceiveRemoteNotificationFetchCompletionHandler];

    // Background app refresh
    [self.appDelegateSwizzler swizzle:@selector(application:performFetchWithCompletionHandler:)
                             protocol:@protocol(UIApplicationDelegate)
                       implementation:(IMP)ApplicationPerformFetchWithCompletionHandler];
}

- (void)swizzleNotificationCenter {
    Class class = [UNUserNotificationCenter class];
    if (!class) {
        UA_LERR(@"UNUserNotificationCenter not available, unable to perform automatic setup.");
        return;
    }

    self.notificationCenterSwizzler = [UASwizzler swizzlerForClass:class];

    // setDelegate:
    [self.notificationCenterSwizzler swizzle:@selector(setDelegate:) implementation:(IMP)UserNotificationCenterSetDelegate];

    id notificationCenterDelegate = [UNUserNotificationCenter currentNotificationCenter].delegate;
    if (notificationCenterDelegate) {
        [self swizzleNotificationCenterDelegate:notificationCenterDelegate];
    } else {
        [UNUserNotificationCenter currentNotificationCenter].delegate = instance_.dummyNotificationDelegate;
    }
}

- (void)swizzleNotificationCenterDelegate:(id<UNUserNotificationCenterDelegate>)delegate {
    Class class = [delegate class];

    self.notificationDelegateSwizzler = [UASwizzler swizzlerForClass:class];

    [self.notificationDelegateSwizzler swizzle:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)
                                      protocol:@protocol(UNUserNotificationCenterDelegate)
                                implementation:(IMP)UserNotificationCenterWillPresentNotificationWithCompletionHandler];

#if !TARGET_OS_TV  // Delegate method not supported on tvOS
    [self.notificationDelegateSwizzler swizzle:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)
                                      protocol:@protocol(UNUserNotificationCenterDelegate)
                                implementation:(IMP)UserNotificationCenterDidReceiveNotificationResponseWithCompletionHandler];
#endif
}


- (void)setNotificationCenterSwizzler:(UASwizzler *)notificationCenterSwizzler {
    if (_notificationCenterSwizzler) {
        [_notificationCenterSwizzler unswizzle];
    }
    _notificationCenterSwizzler = notificationCenterSwizzler;
}

- (void)setNotificationDelegateSwizzler:(UASwizzler *)notificationDelegateSwizzler {
    if (_notificationDelegateSwizzler) {
        [_notificationDelegateSwizzler unswizzle];
    }
    _notificationDelegateSwizzler = notificationDelegateSwizzler;
}

- (void)setAppDelegateSwizzler:(UASwizzler *)appDelegateSwizzler {
    if (_appDelegateSwizzler) {
        [_appDelegateSwizzler unswizzle];
    }
    _appDelegateSwizzler = appDelegateSwizzler;
}



#pragma mark -
#pragma mark UNUserNotificationCenterDelegate swizzled methods

void UserNotificationCenterWillPresentNotificationWithCompletionHandler(id self, SEL _cmd, UNUserNotificationCenter *notificationCenter, UNNotification *notification, void (^handler)(UNNotificationPresentationOptions)) {

    __block UNNotificationPresentationOptions mergedPresentationOptions = UNNotificationPresentationOptionNone;

    dispatch_group_t dispatchGroup = dispatch_group_create();

    IMP original = [instance_.notificationDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        __block BOOL completionHandlerCalled = NO;
        void (^completionHandler)(UNNotificationPresentationOptions) = ^(UNNotificationPresentationOptions options) {

            // Make sure the app's completion handler is called on the main queue
            [[UADispatcher mainDispatcher] dispatchAsync:^{
                if (completionHandlerCalled) {
                    UA_LTRACE(@"Completion handler called multiple times.");
                    return;
                }
                completionHandlerCalled = YES;

                mergedPresentationOptions |= options;

                dispatch_group_leave(dispatchGroup);
            }];
        };

        dispatch_group_enter(dispatchGroup);
        ((void(*)(id, SEL, UNUserNotificationCenter *, UNNotification *, void (^)(UNNotificationPresentationOptions)))original)(self, _cmd, notificationCenter, notification, completionHandler);
    }


    // Call UAPush
    __block BOOL completionHandlerCalled = NO;
    dispatch_group_enter(dispatchGroup);
    [UAAppIntegration userNotificationCenter:notificationCenter willPresentNotification:notification withCompletionHandler:^(UNNotificationPresentationOptions options) {
        // Make sure the app's completion handler is called on the main queue
        [[UADispatcher mainDispatcher] dispatchAsync:^{
            if (completionHandlerCalled) {
                UA_LTRACE(@"Completion handler called multiple times.");
                return;
            }
            completionHandlerCalled = YES;

            mergedPresentationOptions |= options;

            dispatch_group_leave(dispatchGroup);
        }];
    }];

    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        // all processing of notification is complete
        [UAAppIntegration handleForegroundNotification:notification mergedOptions:mergedPresentationOptions withCompletionHandler:^{
            handler(mergedPresentationOptions);
        }];
    });
}

#if !TARGET_OS_TV  // Delegate method not supported on tvOS
void UserNotificationCenterDidReceiveNotificationResponseWithCompletionHandler(id self, SEL _cmd, UNUserNotificationCenter *notificationCenter, UNNotificationResponse *response, void (^handler)(void)) {

    dispatch_group_t dispatchGroup = dispatch_group_create();

    IMP original = [instance_.notificationDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        __block BOOL completionHandlerCalled = NO;
        void (^completionHandler)(void) = ^() {

            // Make sure the app's completion handler is called on the main queue
            [[UADispatcher mainDispatcher] dispatchAsync:^{
                if (completionHandlerCalled) {
                    UA_LTRACE(@"Completion handler called multiple times.");
                    return;
                }
                completionHandlerCalled = YES;

                dispatch_group_leave(dispatchGroup);
            }];
        };

        dispatch_group_enter(dispatchGroup);
        ((void(*)(id, SEL, UNUserNotificationCenter *, UNNotificationResponse *, void (^)(void)))original)(self, _cmd, notificationCenter, response, completionHandler);
    }

    // Call UAPush
    __block BOOL completionHandlerCalled = NO;
    dispatch_group_enter(dispatchGroup);
    [UAAppIntegration userNotificationCenter:notificationCenter
              didReceiveNotificationResponse:response
                       withCompletionHandler:^() {
                           if (completionHandlerCalled) {
                               UA_LTRACE(@"Completion handler called multiple times.");
                               return;
                           }
                           completionHandlerCalled = YES;

                           dispatch_group_leave(dispatchGroup);
                       }];

    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        // all processing of response is complete
        handler();
    });
}
#endif

#pragma mark -
#pragma mark UNUserNotificationCenter swizzled methods

void UserNotificationCenterSetDelegate(id self, SEL _cmd, id<UNUserNotificationCenterDelegate>delegate) {

    // Call through to original setter
    IMP original = [instance_.notificationCenterSwizzler originalImplementation:_cmd];
    if (original) {
        ((void(*)(id, SEL, id))original)(self, _cmd, delegate);
    }

    if (!delegate) {
        // set our dummy delegate back
        [UNUserNotificationCenter currentNotificationCenter].delegate = instance_.dummyNotificationDelegate;
    } else {
        [instance_ swizzleNotificationCenterDelegate:delegate];
    }
}

#pragma mark -
#pragma mark App delegate (UIApplicationDelegate) swizzled methods

void ApplicationPerformFetchWithCompletionHandler(id self,
                                                  SEL _cmd,
                                                  UIApplication *application,
                                                  void (^handler)(UIBackgroundFetchResult)) {

    __block UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;

    dispatch_group_t dispatchGroup = dispatch_group_create();

    IMP original = [instance_.appDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        __block BOOL completionHandlerCalled = NO;

        void (^completionHandler)(UIBackgroundFetchResult) = ^(UIBackgroundFetchResult result) {

            // Make sure the app's completion handler is called on the main queue
            [[UADispatcher mainDispatcher] dispatchAsync:^{
                if (completionHandlerCalled) {
                    UA_LTRACE(@"Completion handler called multiple times.");
                    return;
                }
                completionHandlerCalled = YES;

                // Merge the UIBackgroundFetchResults. If final fetchResult is not already UIBackgroundFetchResultNewData
                // and the current result is not UIBackgroundFetchResultNoData, then set the fetchResult to result
                // (should be either UIBackgroundFetchFailed or UIBackgroundFetchResultNewData)
                if (fetchResult != UIBackgroundFetchResultNewData && result != UIBackgroundFetchResultNoData) {
                    fetchResult = result;
                }

                dispatch_group_leave(dispatchGroup);
            }];
        };

        // Call the original implementation
        dispatch_group_enter(dispatchGroup);
        ((void(*)(id, SEL, UIApplication *, void (^)(UIBackgroundFetchResult)))original)(self, _cmd, application, completionHandler);
    }

    __block BOOL completionHandlerCalled = NO;
    dispatch_group_enter(dispatchGroup);
    [UAAppIntegration application:application performFetchWithCompletionHandler:^(UIBackgroundFetchResult result) {
        if (completionHandlerCalled) {
            UA_LTRACE(@"Completion handler called multiple times.");
            return;
        }
        completionHandlerCalled = YES;

        // Merge the UIBackgroundFetchResults. If final fetchResult is not already UIBackgroundFetchResultNewData
        // and the current result is not UIBackgroundFetchResultNoData, then set the fetchResult to result
        // (should be either UIBackgroundFetchFailed or UIBackgroundFetchResultNewData)
        if (fetchResult != UIBackgroundFetchResultNewData && result != UIBackgroundFetchResultNoData) {
            fetchResult = result;
        }
        dispatch_group_leave(dispatchGroup);
    }];

    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        // all processing of fetch is complete
        handler(fetchResult);
    });

}

void ApplicationDidRegisterForRemoteNotificationsWithDeviceToken(id self, SEL _cmd, UIApplication *application, NSData *deviceToken) {
    [UAAppIntegration application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];

    IMP original = [instance_.appDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        ((void(*)(id, SEL, UIApplication *, NSData*))original)(self, _cmd, application, deviceToken);
    }
}

void ApplicationDidFailToRegisterForRemoteNotificationsWithError(id self, SEL _cmd, UIApplication *application, NSError *error) {
    UA_LERR(@"Application failed to register for remote notifications with error: %@", error);
    [UAAppIntegration application:application didFailToRegisterForRemoteNotificationsWithError:error];

    IMP original = [instance_.appDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        ((void(*)(id, SEL, UIApplication *, NSError*))original)(self, _cmd, application, error);
    }
}

void ApplicationDidReceiveRemoteNotificationFetchCompletionHandler(id self,
                                                                   SEL _cmd,
                                                                   UIApplication *application,
                                                                   NSDictionary *userInfo,
                                                                   void (^handler)(UIBackgroundFetchResult)) {

    __block UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;

    dispatch_group_t dispatchGroup = dispatch_group_create();

    IMP original = [instance_.appDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        __block BOOL completionHandlerCalled = NO;

        void (^completionHandler)(UIBackgroundFetchResult) = ^(UIBackgroundFetchResult result) {

            // Make sure the app's completion handler is called on the main queue
            [[UADispatcher mainDispatcher] dispatchAsync:^{
                if (completionHandlerCalled) {
                    UA_LTRACE(@"Completion handler called multiple times.");
                    return;
                }
                completionHandlerCalled = YES;

                // Merge the UIBackgroundFetchResults. If final fetchResult is not already UIBackgroundFetchResultNewData
                // and the current result is not UIBackgroundFetchResultNoData, then set the fetchResult to result
                // (should be either UIBackgroundFetchFailed or UIBackgroundFetchResultNewData)
                if (fetchResult != UIBackgroundFetchResultNewData && result != UIBackgroundFetchResultNoData) {
                    fetchResult = result;
                }

                dispatch_group_leave(dispatchGroup);
            }];
        };

        // Call the original implementation
        dispatch_group_enter(dispatchGroup);
        ((void(*)(id, SEL, UIApplication *, NSDictionary *, void (^)(UIBackgroundFetchResult)))original)(self, _cmd, application, userInfo, completionHandler);
    }


    // Our completion handler is called by the action framework on the main queue
    __block BOOL completionHandlerCalled = NO;
    dispatch_group_enter(dispatchGroup);
    [UAAppIntegration application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:^(UIBackgroundFetchResult result) {
        if (completionHandlerCalled) {
            UA_LTRACE(@"Completion handler called multiple times.");
            return;
        }
        completionHandlerCalled = YES;

        // Merge the UIBackgroundFetchResults. If final fetchResult is not already UIBackgroundFetchResultNewData
        // and the current result is not UIBackgroundFetchResultNoData, then set the fetchResult to result
        // (should be either UIBackgroundFetchFailed or UIBackgroundFetchResultNewData)
        if (fetchResult != UIBackgroundFetchResultNewData && result != UIBackgroundFetchResultNoData) {
            fetchResult = result;
        }

        dispatch_group_leave(dispatchGroup);
    }];

    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        // all processing of fetch is complete
        handler(fetchResult);
    });
}

@end

