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
 * Represents the possible error conditions
 * when running a `UAAddCustomEventAction`.
 */
typedef NS_ENUM(NSInteger, UAAddCustomEventActionErrorCode) {
    /**
     * Indicates that the eventName is invalid.
     */
    UAAddCustomEventActionErrorCodeInvalidEventName
};

NS_ASSUME_NONNULL_BEGIN

/**
 * The domain for errors encountered when running a `UAAddCustomEventAction`.
 */
extern NSString * const UAAddCustomEventActionErrorDomain;

/**
 * An action that adds a custom event.
 *
 * This action is registered under the name "add_custom_event_action".
 *
 * Expected argument values: A dictionary of keys for the custom event. When a
 * custom event action is triggered from a Message Center Rich Push Message,
 * the interaction type and ID will automatically be filled for the message if
 * they are left blank.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation, UASituationBackgroundPush,
 * UASituationForegroundInteractiveButton, UASituationBackgroundInteractiveButton,
 * and UASituationAutomation
 *
 * 
 * Result value: nil
 *
 * Fetch result: UAActionFetchResultNoData
 *
 * Default predicate: Only accepts UASituationWebViewInvocation and UASituationManualInvocation
 *
 */
@interface UAAddCustomEventAction : UAAction

@end

NS_ASSUME_NONNULL_END
