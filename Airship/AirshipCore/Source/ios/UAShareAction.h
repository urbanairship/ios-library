/* Copyright Airship and Contributors */

#import "UAAction.h"
#import <UIKit/UIKit.h>


/**
 * Shares text using UAActivityViewController.
 *
 * This action is registered under the names share_action and ^s.
 *
 * Expected argument value is an NSString.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Default predicate: Rejects situation UASituationForegroundPush.
 *
 * Result value: nil
 *
 */
@interface UAShareAction : UAAction

/**
 * Default registry name for share action.
 */
extern NSString * const UAShareActionDefaultRegistryName;

/**
 * Default registry alias for share action.
 */
extern NSString * const UAShareActionDefaultRegistryAlias;

/**
 * Default registry name for share action.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAShareActionDefaultRegistryName.
*/
extern NSString * const kUAShareActionDefaultRegistryName DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAShareActionDefaultRegistryName.");

/**
 * Default registry alias for share action.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAShareActionDefaultRegistryAlias.
*/
extern NSString * const kUAShareActionDefaultRegistryAlias DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAShareActionDefaultRegistryAlias.");

@end
