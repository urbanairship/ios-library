/* Copyright Airship and Contributors */

#import "UAAction.h"

/**
 * Enables channel capture for a set period of time.
 *
 * This action is registered under the names channel_capture_action and ^cc.
 *
 * Expected argument values: NSNumber specifying the number of seconds to enable 
 * channel capture for.
 *
 * Valid situations: UASituationBackgroundPush and UASituationManualInvocation
 *
 * Result value: nil
 */
@interface UAChannelCaptureAction : UAAction

/**
 * Default registry name for channel capture action.
 */
extern NSString * const UAChannelCaptureActionDefaultRegistryName;

/**
 * Default registry alias for channel capture action.
 */
extern NSString * const UAChannelCaptureActionDefaultRegistryAlias;

/**
 * Default registry name for channel capture action.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAChannelCaptureActionDefaultRegistryName.
*/
extern NSString * const kUAChannelCaptureActionDefaultRegistryName DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAChannelCaptureActionDefaultRegistryName.");

/**
 * Default registry alias for channel capture action.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAChannelCaptureActionDefaultRegistryAlias.
*/
extern NSString * const kUAChannelCaptureActionDefaultRegistryAlias DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAChannelCaptureActionDefaultRegistryAlias.");

@end
