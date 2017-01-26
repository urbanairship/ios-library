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

#import "UACancelSchedulesAction.h"
#import "UAirship.h"
#import "UAAutomation.h"

NSString *const UACancelSchedulesActionAll = @"all";
NSString *const UACancelSchedulesActionIDs = @"ids";
NSString *const UACancelSchedulesActionGroups = @"groups";

@implementation UACancelSchedulesAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    switch (arguments.situation) {
        case UASituationManualInvocation:
        case UASituationWebViewInvocation:
        case UASituationBackgroundPush:
        case UASituationForegroundPush:
        case UASituationAutomation:
            if ([arguments.value isKindOfClass:[NSDictionary class]]) {
                return arguments.value[UACancelSchedulesActionIDs] != nil || arguments.value[UACancelSchedulesActionGroups] != nil;
            }

            if ([arguments.value isKindOfClass:[NSString class]]) {
                return [arguments.value isEqualToString:UACancelSchedulesActionAll];
            }

            return NO;

        case UASituationLaunchedFromPush:
        case UASituationBackgroundInteractiveButton:
        case UASituationForegroundInteractiveButton:
            return NO;
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {


    // All
    if ([UACancelSchedulesActionAll isEqualToString:arguments.value]) {
        [[UAirship automation] cancelAll];

        completionHandler([UAActionResult emptyResult]);
        return;
    }

    // Groups
    id groups = arguments.value[UACancelSchedulesActionGroups];
    if (groups) {

        // Single group
        if ([groups isKindOfClass:[NSString class]]) {
            [[UAirship automation] cancelSchedulesWithGroup:groups];
        } else if ([groups isKindOfClass:[NSArray class]]) {

            // Array of groups
            for (id value in groups) {
                if ([value isKindOfClass:[NSString class]]) {
                    [[UAirship automation] cancelSchedulesWithGroup:value];
                }
            }
        }
    }

    // IDs
    id ids = arguments.value[UACancelSchedulesActionIDs];
    if (ids) {

        // Single ID
        if ([ids isKindOfClass:[NSString class]]) {
            [[UAirship automation] cancelScheduleWithIdentifier:ids];
        } else if ([ids isKindOfClass:[NSArray class]]) {

            // Array of IDs
            for (id value in ids) {
                if ([value isKindOfClass:[NSString class]]) {
                    [[UAirship automation] cancelScheduleWithIdentifier:value];
                }
            }
        }
    }

    completionHandler([UAActionResult emptyResult]);
}

@end
