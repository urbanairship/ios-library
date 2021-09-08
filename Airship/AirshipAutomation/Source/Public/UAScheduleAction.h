/* Copyright Airship and Contributors */

#import "UAAirshipAutomationCoreImport.h"

/**
 * Action to schedule other actions.
 *
 * This action is registered under the names schedule_actions and ^sa.
 *
 * Expected argument values: NSDictionary representing a schedule info JSON.
 *
 * Valid situations: UASituationBackgroundPush, UASituationForegroundPush
 * UASituationWebViewInvocation, UASituationManualInvocation, and UASituationAutomation
 *
 * Result value: Schedule ID or nil if the schedule failed.
 */
NS_SWIFT_NAME(ScheduleAction)
@interface UAScheduleAction : NSObject<UAAction>

/**
 * Default registry name for schedule action.
 */
extern NSString * const UAScheduleActionDefaultRegistryName;

/**
 * Default registry alias for schedule action.
 */
extern NSString * const UAScheduleActionDefaultRegistryAlias;

/**
 * Represents the possible error conditions when deserializing schedules from JSON.
 */
typedef NS_ENUM(NSInteger, UAScheduleActionErrorCode) {
    /**
     * Indicates an error with the schedule JSON definition.
     */
    UAScheduleActionErrorCodeInvalidJSON,
};

@end
