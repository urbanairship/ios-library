/* Copyright Airship and Contributors */

#import "UACancelSchedulesAction.h"
#import "UAActionAutomation.h"
#import "UAAirshipAutomationCoreImport.h"

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
        [[UAActionAutomation shared] cancelAll];

        completionHandler([UAActionResult emptyResult]);
        return;
    }

    // Groups
    id groups = arguments.value[UACancelSchedulesActionGroups];
    if (groups) {

        // Single group
        if ([groups isKindOfClass:[NSString class]]) {
            [[UAActionAutomation shared] cancelSchedulesWithGroup:groups];
        } else if ([groups isKindOfClass:[NSArray class]]) {

            // Array of groups
            for (id value in groups) {
                if ([value isKindOfClass:[NSString class]]) {
                    [[UAActionAutomation shared] cancelSchedulesWithGroup:value];
                }
            }
        }
    }

    // IDs
    id ids = arguments.value[UACancelSchedulesActionIDs];
    if (ids) {

        // Single ID
        if ([ids isKindOfClass:[NSString class]]) {
            [[UAActionAutomation shared] cancelScheduleWithID:ids];
        } else if ([ids isKindOfClass:[NSArray class]]) {

            // Array of IDs
            for (id value in ids) {
                if ([value isKindOfClass:[NSString class]]) {
                    [[UAActionAutomation shared] cancelScheduleWithID:value];
                }
            }
        }
    }

    completionHandler([UAActionResult emptyResult]);
}

@end
