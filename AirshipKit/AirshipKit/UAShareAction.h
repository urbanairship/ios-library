/* Copyright 2017 Urban Airship and Contributors */


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

@end
