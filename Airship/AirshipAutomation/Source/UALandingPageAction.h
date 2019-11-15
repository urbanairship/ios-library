/* Copyright Airship and Contributors */

#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAAirshipAutomationCoreImport.h"

#define kUALandingPageActionDefaultRegistryName @"landing_page_action"
#define kUALandingPageActionDefaultRegistryAlias @"^p"

/**
 * Schedules a landing page to display ASAP.
 *
 * This action is registered under the names landing_page_action and ^p.
 *
 * Expected argument values:
 * ``url``: NSString or NSURL.
 * ``width``: Optional Int or String. Width should be specified in points or
 * as "fill" to fill current screen. Defaults to fill.
 * ``height``: Optional Int or String. Height should be specified in points or
 * ``fill`` to fill current screen. Defaults to fill.
 * ``aspect_lock``: Optional Boolean. Determines if aspect ratio is maintained during resizing
 * to fit screen size. Defaults to false.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Result value: nil
 *
 * Fetch result: UAActionFetchResultNewData, or UAActionFetchResultFailed if the data could not be fetched.
 *
 */
NS_ASSUME_NONNULL_BEGIN

/**
 * A protocol for extending the default conversion between legacy landing pages and scheduled HTML message landing pages.
 */
@protocol UALandingPageBuilderExtender <NSObject>

@optional

/**
 * Extends the in-app message schedule info builder converted from a legacy landing page.
 * Use this method to make use of the default conversion with minor overrides as needed.
 *
 * @param builder The automatically converted in-app message schedule info builder.
 */
- (void)extendScheduleInfoBuilder:(UAInAppMessageScheduleInfoBuilder *)builder;

/**
 * Extends the in-app message builder converted from a legacy landing page action.
 * Use this method to make use of the automatic conversion process with minor overrides as needed.
 *
 * @param builder The automatically converted in-app message builder.
 */
- (void)extendMessageBuilder:(UAInAppMessageBuilder *)builder;


@end

@interface UALandingPageAction : UAAction

/**
 * The URL key.
 */
extern NSString *const UALandingPageURLKey;

/**
 * The height key.
 */
extern NSString *const UALandingPageHeightKey;

/**
 * The width key.
 */
extern NSString *const UALandingPageWidthKey;

/**
 * The aspect lock key.
 */
extern NSString *const UALandingPageAspectLockKey;

/**
 * The fill constant.
 */
extern NSString *const UALandingPageFill;

/**
 * The default border radius in points.
 */
extern CGFloat const defaultBorderRadiusPoints;

/**
 * The border radius in points. Defaults to defaultBorderRadiusPoints if left unset.
 */
@property(nonatomic, assign, nullable) NSNumber *borderRadiusPoints;

/**
 * Optional message builder extender. Set this to customize aspects of the conversion between legacy landing pages and
 * the new scheduled HTML messages.
 */
@property(nonatomic, weak) id<UALandingPageBuilderExtender> builderExtender;

@end

NS_ASSUME_NONNULL_END
