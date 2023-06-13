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


- (BOOL (^)(id _Nullable, NSInteger))defaultPredicate {
    return nil;
}

- (NSArray<NSString *> *)defaultNames {
    return @[UACancelSchedulesActionDefaultRegistryAlias, UACancelSchedulesActionDefaultRegistryName];
}


- (BOOL)acceptsArgumentValue:(nullable id)arguments situation:(NSInteger)situation {
    switch (situation) {
        case UAActionSituationManualInvocation:
        case UAActionSituationWebViewInvocation:
        case UAActionSituationBackgroundPush:
        case UAActionSituationForegroundPush:
        case UAActionSituationAutomation:
            if ([arguments isKindOfClass:[NSDictionary class]]) {
                return arguments[UACancelSchedulesActionIDs] != nil || arguments[UACancelSchedulesActionGroups] != nil;
            }

            if ([arguments isKindOfClass:[NSString class]]) {
                return [arguments isEqualToString:UACancelSchedulesActionAll];
            }

            return NO;
    }

    return NO;
}

- (void)performWithArgumentValue:(nullable id)argument
                       situation:(NSInteger)situation
                    pushUserInfo:(nullable NSDictionary *)pushUserInfo
               completionHandler:(nonnull void (^)(void))completionHandler {

    // All
    if ([UACancelSchedulesActionAll isEqualToString:argument]) {
        [[UAInAppAutomation shared] cancelSchedulesWithType:UAScheduleTypeActions completionHandler:nil];
        completionHandler();
        return;
    }

    // Groups
    id groups = argument[UACancelSchedulesActionGroups];
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
    id ids = argument[UACancelSchedulesActionIDs];
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

    completionHandler();
}


@end
