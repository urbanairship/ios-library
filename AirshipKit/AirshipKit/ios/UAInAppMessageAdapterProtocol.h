/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"
#import "UAInAppMessageResolution.h"

NS_ASSUME_NONNULL_BEGIN


/**
 * Message preparation result.
 */
typedef NS_ENUM(NSUInteger, UAInAppMessagePrepareResult) {
    /**
     * Message preparation was successful.
     */
    UAInAppMessagePrepareResultSuccess = 0,

    /**
     * Message preparation failed and should be retried.
     */
    UAInAppMessagePrepareResultRetry = 1,

    /**
     * Message preparation failed and should be canceled.
     */
    UAInAppMessagePrepareResultCancel= 2
};


/**
 * In-app message adapter protocol. An adapter is responsible for displaying a particular type of in-app message.
 */
@protocol UAInAppMessageAdapterProtocol

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
- (void)prepare:(void (^)(UAInAppMessagePrepareResult result))completionHandler;

/**
 * Informs the adapter of the ready state of the in-app message immediately before display.
 *
 * @return `YES` if the in-app message is ready, `NO` otherwise.
 */
- (BOOL)isReadyToDisplay;

/**
 * Displays the in-app message.
 *
 * @param completionHandler the completion handler to be called when adapter has finished
 * displaying the in-app message.
 */
- (void)display:(void (^)(UAInAppMessageResolution *))completionHandler;

@end

NS_ASSUME_NONNULL_END
