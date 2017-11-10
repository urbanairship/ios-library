/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message adapter protocol. An adapter is responsible for displaying a particular type of in-app message.
 */
@protocol UAInAppMessageAdapter

/**
 * Factory method to create an in-app message adapter.
 *
 * @param message The in-app message.
 */
+ (instancetype)adapterForMessage:(UAInAppMessage *)message;

/**
 * Prepares in-app message to display.
 *
 * @param completionHandler the completion handler to be called when adapter has finished
 * preparing the in-app message.
 */
- (void)prepare:(void (^)(void))completionHandler;

/**
 * Displays the in-app message.
 *
 * @param completionHandler the completion handler to be called when adapter has finished
 * displaying the in-app message.
 */
- (void)display:(void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END
