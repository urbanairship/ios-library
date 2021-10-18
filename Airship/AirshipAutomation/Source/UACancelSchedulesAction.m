/* Copyright Airship and Contributors */

#import "UACancelSchedulesAction.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppAutomation+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NSString *const UACancelSchedulesActionAll = @"all";
NSString *const UACancelSchedulesActionIDs = @"ids";
NSString *const UACancelSchedulesActionGroups = @"groups";

@implementation UACancelSchedulesAction

NSString * const UACancelSchedulesActionDefaultRegistryName = @"cancel_scheduled_actions";
NSString * const UACancelSchedulesActionDefaultRegistryAlias = @"^csa";

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
        [[UAInAppAutomation shared] cancelSchedulesWithType:UAScheduleTypeActions completionHandler:nil];
        completionHandler([UAActionResult emptyResult]);
        return;
    }

    // Groups
    id groups = arguments.value[UACancelSchedulesActionGroups];
    if (groups) {

        // Single group
        if ([groups isKindOfClass:[NSString class]]) {
            [[UAInAppAutomation shared] cancelActionSchedulesWithGroup:groups completionHandler:nil];
        } else if ([groups isKindOfClass:[NSArray class]]) {

            // Array of groups
            for (id value in groups) {
                if ([value isKindOfClass:[NSString class]]) {
                    [[UAInAppAutomation shared] cancelActionSchedulesWithGroup:value completionHandler:nil];
                }
            }
        }
    }

    // IDs
    id ids = arguments.value[UACancelSchedulesActionIDs];
    if (ids) {

        // Single ID
        if ([ids isKindOfClass:[NSString class]]) {
            [[UAInAppAutomation shared] cancelScheduleWithID:ids completionHandler:nil];
        } else if ([ids isKindOfClass:[NSArray class]]) {

            // Array of IDs
            for (id value in ids) {
                if ([value isKindOfClass:[NSString class]]) {
                    [[UAInAppAutomation shared] cancelScheduleWithID:value completionHandler:nil];
                }
            }
        }
    }

    completionHandler([UAActionResult emptyResult]);
}

@end
