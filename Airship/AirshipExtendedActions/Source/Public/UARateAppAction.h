/* Copyright Airship and Contributors */

#import "UAExtendedActionsCoreImport.h"

/**
 * Links directly to app store review page or opens an app rating prompt.
 *
 * This action is registered under the names rate_app_action and ^ra.
 *
 * The rate app action requires your application to provide an itunes ID as an argument value, or have it
 * set on the UARuntimeConfig instance used for takeoff. The itunes ID can be set on the UARuntimeConfig instance directly
 * via UARuntimeConfig's itunesID property, or by setting the itunesID as an NSString value in the AirshipConfig.plist
 * under the key ``itunesID``.
 *
 * Expected argument values:
 * ``show_link_prompt``:Required Boolean. If NO action will link directly to the iTunes app
 * review page, if YES action will display a rating prompt. Defaults to NO if nil.
 * ``link_prompt_title``: Optional String. String to override the link prompt's title.
 *   Title over 24 characters will be rejected. Header defaults to "Enjoying <CFBundleDisplayName>?" if nil.
 * ``link_prompt_body``: Optional String. String to override the link prompt's body.
 *  Bodies over 50 characters will be rejected. Body defaults to "Tap Rate App to rate it on the
 *  App Store." if nil.
 * ``itunes_id``: Optional String. The iTunes ID for the application to be rated.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush, UASituationWebViewInvocation
 * UASituationManualInvocation, UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Result value: nil
 */
@interface UARateAppAction : NSObject<UAAction>

/**
 * Default registry name for rate-app action action.
 */
extern NSString * const UARateAppActionDefaultRegistryName;

/**
 * Default registry alias for rate-app action action.
 */
extern NSString * const UARateAppActionDefaultRegistryAlias;

/**
 * The show link prompt key.
 */
extern NSString *const UARateAppShowLinkPromptKey;

/**
 * The itunes ID key.
 */
extern NSString *const UARateAppItunesIDKey;

@end
