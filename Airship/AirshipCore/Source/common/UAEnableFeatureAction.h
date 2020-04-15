/* Copyright Airship and Contributors */

#import "UAAction.h"

/**
 * Default registry name for enable feature action.
 */
extern NSString * const UAEnableFeatureActionDefaultRegistryName;

/**
 * Default registry alias for enable feature action.
 */
extern NSString * const UAEnableFeatureActionDefaultRegistryAlias;

/**
 * Default registry name for enable feature action.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAEnableFeatureActionDefaultRegistryName.
*/
extern NSString * const kUAEnableFeatureActionDefaultRegistryName DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAEnableFeatureActionDefaultRegistryName.");

/**
 * Default registry alias for enable feature action.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAEnableFeatureActionDefaultRegistryAlias.
*/
extern NSString * const kUAEnableFeatureActionDefaultRegistryAlias DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAEnableFeatureActionDefaultRegistryAlias.");

/**
 * Argument value to enable user notifications.
 */
extern NSString *const UAEnableUserNotificationsActionValue;

/**
 * Argument value to enable user location.
 */
extern NSString *const UAEnableLocationActionValue;

/**
 * Argument value to enable background location.
 */
extern NSString *const UAEnableBackgroundLocationActionValue;


/**
 * Enables an Airship feature.
 *
 * This action is registered under the names enable_feature and ^ef.
 *
 * Expected argument values: 
 * - "user_notifications": To enable user notifications.
 * - "location": To enable location updates.
 * - "background_location": To enable location and allow background updates.
 *
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Default predicate: Rejects foreground pushes with visible display options.
 *
 * Result value: Empty.
 */
@interface UAEnableFeatureAction : UAAction


@end


