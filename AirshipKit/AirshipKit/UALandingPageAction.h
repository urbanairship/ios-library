/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAAction.h"

/**
 * Opens a landing page URL in a rich content window.
 *
 * This action is registered under the names landing_page_action and ^p.
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
 * UASituationWebViewInvocation, UASituationManualInvocation, UASituationBackgroundPush,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * In situation UASituationBackgroundPush, the action will attempt to pre-fetch
 * the data and cache it for later use.
 *
 * Result value: nil
 *
 * Fetch result: UAActionFetchResultNewData, or UAActionFetchResultFailed if the data could not be fetched.
 *
 */
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


@end
