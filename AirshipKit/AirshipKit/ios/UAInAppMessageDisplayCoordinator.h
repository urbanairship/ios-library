/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"

/**
 * A continuation block used to coordinate the display of in-app messages with the in-app message manager.
 */
typedef void (^UAInAppMessageDisplayCoordinatorBlock)(void);

/**
 * Protocol for coordinating the display of in-app messages with the in-app message manager. Useful for
 * putting time or count-based back pressure on message display, or for overriding the default coordination behavior for
 * particular message types.
 */
@protocol UAInAppMessageDisplayCoordinator

/**
 * Indicates whether a message should be displayed.
 *
 * @param message The message.
 * @return `YES` if the message should be displayed, `NO` otherwise.
 */
- (BOOL)shouldDisplayMessage:(UAInAppMessage *)message;

/**
 * Requests that the coordinator notify as soon as display is available.
 *
 * @param block A UAInAppMessageDisplayCoordinatorBlock which should be called upon availability.
 */
- (void)whenNextAvailable:(UAInAppMessageDisplayCoordinatorBlock)block;

/**
 * Notifies the coordinator that message display has begun.
 *
 * @param message The message.
 * @return A UAInAppMessageDisplayCoordinatorBlock to be called when message display has finished.
 */
- (UAInAppMessageDisplayCoordinatorBlock)didBeginDisplayingMessage:(UAInAppMessage *)message;

@end
