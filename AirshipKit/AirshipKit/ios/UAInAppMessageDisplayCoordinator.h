/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"

/**
 * Protocol for coordinating the display of in-app messages with the in-app message manager. Useful for
 * putting time or count-based back pressure on message display, or for overriding the default coordination behavior for
 * particular message types.
 */
@protocol UAInAppMessageDisplayCoordinator

/**
 * Indicates whether message display is ready.
 *
 * @note This property must be KVO compliant.
 */
@property (nonatomic, readonly) BOOL isReady;

/**
 * Indicates whether a message should be displayed.
 *
 * @param message The message.
 * @return `YES` if the message should be displayed, `NO` otherwise.
 */
- (BOOL)shouldDisplayMessage:(UAInAppMessage *)message;

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
