/* Copyright 2017 Urban Airship and Contributors */

#import "UAAction.h"

#define kUARateAppActionDefaultRegistryName @"rate_app_action"
#define kUARateAppActionDefaultRegistryAlias @"^ra"

/**
 * Opens an app rating dialog.
 *
 * This action is registered under the names rate_app_action and ^ra.
 *
 * Expected argument values:
 * ``showDialog``:Required Boolean. If NO action will link directly to the iTunes app
 * review page, if YES action will display a rating prompt.
 * ``itunesID``: Required String. iTunes ID for application.
 * ``linkPromptHeaderKey``: Optional String. String to override the link prompt's header.
 *   Header over 24 characters will be rejected. Header defaults to "Enjoying <CFBundleDisplayName>?" if nil.
 * ``linkPromptDescriptionKey``: Optional String. String to override the link prompt's description.
 *  Decriptions over 50 characters will be rejected. Decription defaults to "Tap Rate App to rate it on the
 *  App Store." if nil.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush, UASituationWebViewInvocation
 * UASituationManualInvocation, UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Result value: nil
 */
@interface UARateAppAction : UAAction

/**
 * The show dialog key.
 */
extern NSString *const UARateAppShowDialogKey;

/**
 * The iTunes ID key.
 */
extern NSString *const UARateAppItunesIDKey;

/**
 * The link prompt's header key.
 */
extern NSString *const UARateAppLinkPromptHeaderKey;

/**
 * The link prompt's decription key.
 */
extern NSString *const UARateAppLinkPromptDescriptionKey;

/**
 * Returns an NSArray of NSNumbers representing the time intervals for each call to display the link prompt since epoch.
 * Timestamps older than 1 year are automatically removed. Timestamps will only be collected for release builds.
 */
-(NSArray *)rateAppLinkPromptTimestamps;

/**
 * Returns an NSArray of NSNumbers representing the time intervals for each call to display the system prompt since epoch.
 * Timestamps older than 1 year are automatically removed. Timestamps will only be collected for release builds.
 */
-(NSArray *)rateAppPromptTimestamps;

@end
