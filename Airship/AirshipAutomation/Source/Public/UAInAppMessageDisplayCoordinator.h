/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"

/**
 * Key name for the isReady property. Use this for emitting change notifications.
 */
extern NSString *const UAInAppMessageDisplayCoordinatorIsReadyKey;

/**
 * Protocol for coordinating the display of in-app messages with the in-app message manager. Useful for
 * putting time or count-based back pressure on message display, or for overriding the default coordination behavior for
 * particular message types.
 */
NS_SWIFT_NAME(InAppMessageDisplayCoordinator)
@protocol UAInAppMessageDisplayCoordinator <NSObject>

/**
 * Indicates whether message display is ready.
 *
 * @note This property must be KVO compliant.
 */
@property (nonatomic, readonly) BOOL isReady;

@optional

/**
 * Notifies the coordinator that message display has begun.
 *
 * @param message The message.
 */
- (void)didBeginDisplayingMessage:(UAInAppMessage *)message;

/**
 * Notifies the coordinator that message display has finished.
 *
 * @param message The message.
 */
- (void)didFinishDisplayingMessage:(UAInAppMessage *)message;

@end
