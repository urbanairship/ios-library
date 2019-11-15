/* Copyright Airship and Contributors */

#import "UAScheduleAction.h"
#import "UAActionAutomation.h"
#import "UAActionScheduleInfo+Internal.h"
#import "UASchedule.h"
#import "UAAirshipAutomationCoreImport.h"

@implementation UAScheduleAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    switch (arguments.situation) {
        case UASituationManualInvocation:
        case UASituationWebViewInvocation:
        case UASituationBackgroundPush:
        case UASituationForegroundPush:
        case UASituationAutomation:
            return [arguments.value isKindOfClass:[NSDictionary class]];
        case UASituationLaunchedFromPush:
        case UASituationBackgroundInteractiveButton:
        case UASituationForegroundInteractiveButton:
            return NO;
    }
}


- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    NSError *error = nil;

    UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo scheduleInfoWithJSON:arguments.value error:&error];
    if (!scheduleInfo) {
        UA_LERR(@"Unable to schedule actions. Invalid schedule payload: %@", scheduleInfo);
        completionHandler([UAActionResult resultWithError:error]);
        return;
    }

    [[UAActionAutomation shared] scheduleActions:scheduleInfo completionHandler:^(UASchedule *schedule) {
        completionHandler([UAActionResult resultWithValue:schedule.identifier]);
    }];
}

@end
