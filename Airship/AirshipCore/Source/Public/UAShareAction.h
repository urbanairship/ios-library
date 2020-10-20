/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#if !TARGET_OS_TV

#import "UAAction.h"

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
API_UNAVAILABLE(tvos)
@interface UAShareAction : UAAction

/**
 * Default registry name for share action.
 */
extern NSString * const UAShareActionDefaultRegistryName;

/**
 * Default registry alias for share action.
 */
extern NSString * const UAShareActionDefaultRegistryAlias;

@end

#endif
