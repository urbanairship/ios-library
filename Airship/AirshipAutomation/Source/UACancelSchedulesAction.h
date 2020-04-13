/* Copyright Airship and Contributors */

#import "UAAirshipAutomationCoreImport.h"

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
 * Default registry name for cancel schedules action.
 */
extern NSString * const UACancelSchedulesActionDefaultRegistryName;

/**
 * Default registry alias for cancel schedules action.
 */
extern NSString * const UACancelSchedulesActionDefaultRegistryAlias;

/**
 * Default registry name for cancel schedules action.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UACancelSchedulesActionDefaultRegistryName.
*/
extern NSString * const kUACancelSchedulesActionDefaultRegistryName DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UACancelSchedulesActionDefaultRegistryName.");

/**
 * Default registry alias for cancel schedules action.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UACancelSchedulesActionDefaultRegistryAlias.
*/
extern NSString * const kUACancelSchedulesActionDefaultRegistryAlias DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UACancelSchedulesActionDefaultRegistryAlias.");

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
