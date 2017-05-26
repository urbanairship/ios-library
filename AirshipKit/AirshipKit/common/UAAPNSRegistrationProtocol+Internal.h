/* Copyright 2017 Urban Airship and Contributors */

#import "UAPush.h"
#import "UANotificationCategory.h"

NS_ASSUME_NONNULL_BEGIN

//---------------------------------------------------------------------------------------
// UAAPNSRegistrationProtocol Protocol
//---------------------------------------------------------------------------------------

@protocol UAAPNSRegistrationDelegate <NSObject>

@required

- (void)notificationRegistrationFinishedWithOptions:(UANotificationOptions)options;

@end

/**
 * Protocol to be implemented by internal APNS registration instances. All methods are optional.
 */
@protocol UAAPNSRegistrationProtocol<NSObject>

///---------------------------------------------------------------------------------------
/// @name APNS Registration Protocol Internal Methods
///---------------------------------------------------------------------------------------

@required

@property (nonatomic, weak, nullable) id<UAAPNSRegistrationDelegate> registrationDelegate;


/**
 * Get current authorized notification options from APNS.
 *
 * @param completionHandler A completion handler that will be called with the current authorized notification options.
 */
-(void)getCurrentAuthorizationOptionsWithCompletionHandler:(void (^)(UANotificationOptions))completionHandler;

/**
 * Updates APNS registration.
 *
 * @param options The notification options to register.
 * @param categories The categories to register
 */
-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UANotificationCategory *> *)categories;
@optional

/**
 * Required for iOS 8 & 9.
 *
 * Called by the UIApplicationDelegate's application:didRegisterUserNotificationSettings:
 * so UAPush can forward the delegate call to its registration delegate.
 *
 * @param application The application instance.
 * @param notificationSettings The resulting notificaiton settings.
 */
- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings;

@end

NS_ASSUME_NONNULL_END
