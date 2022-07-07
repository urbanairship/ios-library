/* Copyright Airship and Contributors */

#import "UAAutoIntegration.h"
#import "UASwizzler+Internal.h"
#import "UAGlobal.h"
#if TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif

static UAAutoIntegration *instance_;
@interface UAAutoIntegrationDummyDelegate : NSObject<UNUserNotificationCenterDelegate>
@end

@implementation UAAutoIntegrationDummyDelegate
static dispatch_once_t onceToken;
@end

@interface UAAutoIntegration()
@property (nonatomic, strong) UASwizzler *appDelegateSwizzler;
@property (nonatomic, strong) UASwizzler *extensionDelegateSwizzler;
@property (nonatomic, strong) UASwizzler *notificationDelegateSwizzler;
@property (nonatomic, strong) UASwizzler *notificationCenterSwizzler;
@property (nonatomic, strong) UAAutoIntegrationDummyDelegate *dummyNotificationDelegate;
@property (nonatomic, strong) id<UAAppIntegrationDelegate> delegate;

@end

@implementation UAAutoIntegration

+ (void)integrateWithDelegate:(id<UAAppIntegrationDelegate>)delegate {
    dispatch_once(&onceToken, ^{
        instance_ = [[UAAutoIntegration alloc] initWithDelegate:delegate];
        #if !TARGET_OS_WATCH
        [instance_ swizzleAppDelegate];
        #else
        [instance_ swizzleExtensionDelegate];
        #endif
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

- (instancetype)initWithDelegate:(id<UAAppIntegrationDelegate>)delegate {
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.dummyNotificationDelegate = [[UAAutoIntegrationDummyDelegate alloc] init];
    }

    return self;
}

#if !TARGET_OS_WATCH
- (void)swizzleAppDelegate NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
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
#endif

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

#if TARGET_OS_WATCH
- (void)swizzleExtensionDelegate{
    id delegate = [WKExtension sharedExtension].delegate;
    if (!delegate) {
        UA_LERR(@"Extension delegate not set, unable to perform automatic setup.");
        return;
    }

    Class class = [delegate class];
    self.extensionDelegateSwizzler = [UASwizzler swizzlerForClass:class];

    // Device token
    [self.extensionDelegateSwizzler swizzle:@selector(didRegisterForRemoteNotificationsWithDeviceToken:)
                             protocol:@protocol(WKExtensionDelegate)
                       implementation:(IMP)DidRegisterForRemoteNotificationsWithDeviceToken];
    
    // Device token errors
    [self.extensionDelegateSwizzler swizzle:@selector(didFailToRegisterForRemoteNotificationsWithError:)
                             protocol:@protocol(WKExtensionDelegate)
                       implementation:(IMP)DidFailToRegisterForRemoteNotificationsWithError];

    // Content-available notifications
    [self.extensionDelegateSwizzler swizzle:@selector(didReceiveRemoteNotification:fetchCompletionHandler:)
                             protocol:@protocol(WKExtensionDelegate)
                       implementation:(IMP)DidReceiveRemoteNotificationFetchCompletionHandler];
}
#endif

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

- (void)setExtensionDelegateSwizzler:(UASwizzler *)extensionDelegateSwizzler {
    if (_extensionDelegateSwizzler) {
        [_extensionDelegateSwizzler unswizzle];
    }
    _extensionDelegateSwizzler = extensionDelegateSwizzler;
}


#pragma mark -
#pragma mark UNUserNotificationCenterDelegate swizzled methods

void UserNotificationCenterWillPresentNotificationWithCompletionHandler(id self, SEL _cmd, UNUserNotificationCenter *notificationCenter, UNNotification *notification, void (^handler)(UNNotificationPresentationOptions)) {

    id<UAAppIntegrationDelegate> delegate = instance_.delegate;
    __block UNNotificationPresentationOptions mergedPresentationOptions = [delegate presentationOptionsForNotification:notification];
    
    dispatch_group_t dispatchGroup = dispatch_group_create();

    IMP original = [instance_.notificationDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        __block BOOL completionHandlerCalled = NO;
        void (^completionHandler)(UNNotificationPresentationOptions) = ^(UNNotificationPresentationOptions options) {

            // Make sure the app's completion handler is called on the main queue
            [UAAutoIntegration dispatchMain:^{
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

    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        __block BOOL completionHandlerCalled = NO;

        [delegate willPresentNotification:notification presentationOptions:mergedPresentationOptions completionHandler:^{
            if (completionHandlerCalled) {
                UA_LTRACE(@"Completion handler called multiple times.");
                return;
            }
            completionHandlerCalled = YES;
            handler(mergedPresentationOptions);
        }];
    });
}

#if !TARGET_OS_TV  // Delegate method not supported on tvOS
void UserNotificationCenterDidReceiveNotificationResponseWithCompletionHandler(id self, SEL _cmd, UNUserNotificationCenter *notificationCenter, UNNotificationResponse *response, void (^handler)(void)) {

    dispatch_group_t dispatchGroup = dispatch_group_create();

    IMP original = [instance_.notificationDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        dispatch_group_enter(dispatchGroup);

        __block BOOL completionHandlerCalled = NO;
        void (^completionHandler)(void) = ^() {

            // Make sure the app's completion handler is called on the main queue
            [UAAutoIntegration dispatchMain:^{
                if (completionHandlerCalled) {
                    UA_LTRACE(@"Completion handler called multiple times.");
                    return;
                }
                completionHandlerCalled = YES;
                dispatch_group_leave(dispatchGroup);
            }];
        };

        ((void(*)(id, SEL, UNUserNotificationCenter *, UNNotificationResponse *, void (^)(void)))original)(self, _cmd, notificationCenter, response, completionHandler);
    }

    dispatch_group_enter(dispatchGroup);
    
    __block BOOL completionHandlerCalled = NO;
    [instance_.delegate didReceiveNotificationResponse:response completionHandler:^{
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

#if !TARGET_OS_WATCH
void ApplicationPerformFetchWithCompletionHandler(id self,
                                                  SEL _cmd,
                                                  UIApplication *application,
                                                  void (^handler)(UIBackgroundFetchResult)) {

    [instance_.delegate onBackgroundAppRefresh];

    IMP original = [instance_.appDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        // Call the original implementation
        ((void(*)(id, SEL, UIApplication *, void (^)(UIBackgroundFetchResult)))original)(self, _cmd, application, handler);
    } else {
        handler(UIBackgroundFetchResultNoData);
    }
}

void ApplicationDidRegisterForRemoteNotificationsWithDeviceToken(id self, SEL _cmd, UIApplication *application, NSData *deviceToken) {
    [instance_.delegate didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];

    IMP original = [instance_.appDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        ((void(*)(id, SEL, UIApplication *, NSData*))original)(self, _cmd, application, deviceToken);
    }
}

void ApplicationDidFailToRegisterForRemoteNotificationsWithError(id self, SEL _cmd, UIApplication *application, NSError *error) {
    [instance_.delegate didFailToRegisterForRemoteNotificationsWithError:error];
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
            [UAAutoIntegration dispatchMain:^{
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

    dispatch_group_enter(dispatchGroup);
    __block BOOL completionHandlerCalled = NO;
    void (^completionHandler)(UIBackgroundFetchResult) = ^(UIBackgroundFetchResult result) {
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
    };
    
    [instance_.delegate didReceiveRemoteNotification:userInfo
                                     isForeground:application.applicationState == UIApplicationStateActive
                                completionHandler:completionHandler];
   
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        // all processing of fetch is complete
        handler(fetchResult);
    });
}
#else

void DidRegisterForRemoteNotificationsWithDeviceToken(id self, SEL _cmd, NSData *deviceToken) {
    [instance_.delegate didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];

    IMP original = [instance_.extensionDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        ((void(*)(id, SEL, NSData*))original)(self, _cmd, deviceToken);
    }
}

void DidFailToRegisterForRemoteNotificationsWithError(id self, SEL _cmd, NSError *error) {
    [instance_.delegate didFailToRegisterForRemoteNotificationsWithError:error];
    IMP original = [instance_.extensionDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        ((void(*)(id, SEL, NSError*))original)(self, _cmd, error);
    }
}

void DidReceiveRemoteNotificationFetchCompletionHandler(id self,
                                                                   SEL _cmd,
                                                                   NSDictionary *userInfo,
                                                                   void (^handler)(WKBackgroundFetchResult)) {

    __block WKBackgroundFetchResult fetchResult = WKBackgroundFetchResultNoData;

    dispatch_group_t dispatchGroup = dispatch_group_create();

    IMP original = [instance_.extensionDelegateSwizzler originalImplementation:_cmd];
    if (original) {
        __block BOOL completionHandlerCalled = NO;

        void (^completionHandler)(WKBackgroundFetchResult) = ^(WKBackgroundFetchResult result) {
            // Make sure the app's completion handler is called on the main queue
            [UAAutoIntegration dispatchMain:^{
                if (completionHandlerCalled) {
                    UA_LTRACE(@"Completion handler called multiple times.");
                    return;
                }
                completionHandlerCalled = YES;

                // Merge the WKBackgroundFetchResults. If final fetchResult is not already WKBackgroundFetchResultNewData
                // and the current result is not WKBackgroundFetchResultNoData, then set the fetchResult to result
                // (should be either WKBackgroundFetchFailed or WKBackgroundFetchResultNewData)
                if (fetchResult != WKBackgroundFetchResultNewData && result != WKBackgroundFetchResultNoData) {
                    fetchResult = result;
                }

                dispatch_group_leave(dispatchGroup);
            }];
        };

        // Call the original implementation
        dispatch_group_enter(dispatchGroup);
        ((void(*)(id, SEL, NSDictionary *, void (^)(WKBackgroundFetchResult)))original)(self, _cmd, userInfo, completionHandler);
    }

    dispatch_group_enter(dispatchGroup);
    __block BOOL completionHandlerCalled = NO;
    void (^completionHandler)(WKBackgroundFetchResult) = ^(WKBackgroundFetchResult result) {
        if (completionHandlerCalled) {
            UA_LTRACE(@"Completion handler called multiple times.");
            return;
        }
        completionHandlerCalled = YES;

        // Merge the WKBackgroundFetchResults. If final fetchResult is not already WKBackgroundFetchResultNewData
        // and the current result is not WKBackgroundFetchResultNoData, then set the fetchResult to result
        // (should be either WKBackgroundFetchFailed or WKBackgroundFetchResultNewData)
        if (fetchResult != WKBackgroundFetchResultNewData && result != WKBackgroundFetchResultNoData) {
            fetchResult = result;
        }

        dispatch_group_leave(dispatchGroup);
    };
    
    [instance_.delegate didReceiveRemoteNotification:userInfo
                                     isForeground:[WKExtension sharedExtension].applicationState == WKApplicationStateActive
                                completionHandler:completionHandler];
   
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(),^{
        // all processing of fetch is complete
        handler(fetchResult);
    });
}

#endif

+ (void)dispatchMain:(void (^)(void))block {
    dispatch_async(dispatch_get_main_queue(), block);
}
@end


