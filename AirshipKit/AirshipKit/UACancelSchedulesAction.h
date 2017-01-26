/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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
 * Action to cancel automation schedules.
 *
 * This action is registered under the names cancel_scheduled_actions and ^csa.
 *
 * Expected argument values: NSString with the value "all" or an NSDictionary with:
 *  - "groups": A schedule group or an array of schedule groups.
 *  - "ids": A schedule ID or an array of schedule IDs.
 *
 * Valid situations: UASituationBackgroundPush, UASituationForegroundPush
 * UASituationWebViewInvocation, UASituationManualInvocation, and UASituationAutomation
 *
 * Result value: nil.
 */
@interface UACancelSchedulesAction : UAAction

/**
 * Argument value to cancel all schedules.
 */
extern NSString *const UACancelSchedulesActionAll;

/**
 * Key in the argument value map to list the schedule IDs to cancel.
 */
extern NSString *const UACancelSchedulesActionIDs;

/**
 * Key in the argument value map to list the schedule groups to cancel.
 */
extern NSString *const UACancelSchedulesActionGroups;


@end
