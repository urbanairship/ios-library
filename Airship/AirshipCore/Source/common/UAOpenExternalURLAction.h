/* Copyright Airship and Contributors */

#import "UAAction.h"

/**
 * Represents the possible error conditions
 * when running a `UAOpenExternalURLAction`.
 */
typedef NS_ENUM(NSInteger, UAOpenExternalURLActionErrorCode) {
    /**
     * Indicates that the URL failed to open.
     */
    UAOpenExternalURLActionErrorCodeURLFailedToOpen
};

NS_ASSUME_NONNULL_BEGIN

/**
 * Default registry name for open external URL action
 */
extern NSString * const UAOpenExternalURLActionDefaultRegistryName;

/**
 * Default registry alias for open external URL action
 */
extern NSString * const UAOpenExternalURLActionDefaultRegistryAlias;

/**
 * Default registry name for open external URL action
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAOpenExternalURLActionDefaultRegistryName.
*/
extern NSString * const kUAOpenExternalURLActionDefaultRegistryName DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAOpenExternalURLActionDefaultRegistryName.");

/**
 * Default registry alias for open external URL action
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0. Please use UAOpenExternalURLActionDefaultRegistryAlias.
*/
extern NSString * const kUAOpenExternalURLActionDefaultRegistryAlias DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Please use UAOpenExternalURLActionDefaultRegistryAlias.");

/**
 * The domain for errors encountered when running a `UAOpenExternalURLAction`.
 */
extern NSString * const UAOpenExternalURLActionErrorDomain;

/**
 * Opens a URL, either in safari or using custom URL schemes. This action is 
 * registered under the names ^u and open_external_url_action.
 *
 * Expected argument values: NSString
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush
 * UASituationWebViewInvocation, UASituationForegroundInteractiveButton,
 * UASituationManualInvocation, and UASituationAutomation
 *
 * Result value: An NSString representation of the input
 *
 * Error: `UAOpenExternalURLActionErrorCodeURLFailedToOpen` if the URL could not be opened
 *
 * Fetch result: UAActionFetchResultNoData
 */
@interface UAOpenExternalURLAction : UAAction

/**
 * Parses the NSURL from the action arguments.
 * @param arguments The action arguments.
 * @return The parsed NSURL or null.
 */
+ (nullable NSURL *)parseURLFromArguments:(UAActionArguments *)arguments;
@end

NS_ASSUME_NONNULL_END
