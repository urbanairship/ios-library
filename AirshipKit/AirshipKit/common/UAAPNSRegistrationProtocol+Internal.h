/* Copyright 2018 Urban Airship and Contributors */

#import "UAPush.h"
#import "UANotificationCategory.h"

NS_ASSUME_NONNULL_BEGIN

//---------------------------------------------------------------------------------------
// UAAPNSRegistrationProtocol Protocol
//---------------------------------------------------------------------------------------

@protocol UAAPNSRegistrationDelegate <NSObject>

@required

- (void)notificationRegistrationFinishedWithAuthorizedSettings:(UAAuthorizedNotificationSettings)authorizedSettings;

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
 * Get authorized notification settings from iOS.
 *
 * @param completionHandler A completion handler that will be called with the current authorized notification settings.
 */
-(void)getAuthorizedSettingsWithCompletionHandler:(void (^)(UAAuthorizedNotificationSettings))completionHandler;

/**
 * Updates APNS registration.
 *
 * @param options The notification options to register.
 * @param categories The categories to register
 */
-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UANotificationCategory *> *)categories;
@optional


#if !TARGET_OS_TV
/**
 * Required for iOS 8 & 9.
 *
 * Called by the UIApplicationDelegate's application:didRegisterUserNotificationSettings:
 * so UAPush can forward the delegate call to its registration delegate.
 *
 * @param application The application instance.
 * @param notificationSettings The resulting notificaiton settings.
 *
 * @deprecated Deprecated in iOS 10.
 */
- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings NS_DEPRECATED_IOS(8_0, 10_0, "Deprecated in iOS 10");
#endif
@end

NS_ASSUME_NONNULL_END
