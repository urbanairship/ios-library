/* Copyright 2017 Urban Airship and Contributors */

#import <AirshipKit/AirshipKit.h>

/**
 * Opens an app rating dialog.
 *
 * This action is registered under the names rate_app_action and ^ra.
 *
 * Expected argument values:
 * ``url``: NSString or NSURL. Short url formats are in the form
 * of "u:<content-id>" and will be used to construct a new URL using the content-id.
 * ``width``: Optional Int or String. Width should be specified in points or
 * as "fill" to fill current screen. Defaults to fill.
 * ``height``: Optional Int or String. Height should be specified in points or
 * ``fill`` to fill current screen. Defaults to fill.
 * ``aspect_lock``: Optional Boolean. Determines if aspect ratio is maintained during resizing
 * to fit screen size. Defaults to false.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush,
 * UASituationManualInvocation, UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Result value: nil
 *
 */
@interface UARateAppAction : UAAction

@end
