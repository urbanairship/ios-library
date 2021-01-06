/* Copyright Airship and Contributors */

#import "UAAction.h"

/**
 * Modifies attributes This Action is registered under the
 * names ^a and "modify_attributes_action".
 *
 * An example JSON payload:
 *
 * {
 *     "channel": {
 *         set: [{"key": value}, ...],
 *         remove: ["attribute", ....]
 *     },
 *     "named_user": {
 *         set: [{"key": value}, ...],
 *         remove: ["attribute", ....]
 *     }
 * }
 *
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush
 * UASituationWebViewInvocation, UASituationForegroundInteractiveButton,
 * UASituationBackgroundInteractiveButton, UASituationManualInvocation, and
 * UASituationAutomation
 *
 * Default predicate: Rejects foreground pushes with visible display options
 *
 * Result value: nil
 *
 * Error: nil
 *
 * Fetch result: UAActionFetchResultNoData
 */

NS_ASSUME_NONNULL_BEGIN

@interface UAModifyAttributesAction : UAAction

/**
 * Default registry name for modify attributes action.
 */
extern NSString * const UAModifyAttributesActionDefaultRegistryName;

/**
 * Default registry alias for modify attributes action.
 */
extern NSString * const UAModifyAttributesActionDefaultRegistryAlias;

@end

NS_ASSUME_NONNULL_END
