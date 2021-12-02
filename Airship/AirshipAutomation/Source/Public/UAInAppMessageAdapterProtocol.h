/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageAssets.h"

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
    UAInAppMessagePrepareResultCancel = 2,
    
    /**
     * Message preparation failed and the entire schedule
     * preparation step should be retried.
     */
    UAInAppMessagePrepareResultInvalidate = 3
} NS_SWIFT_NAME(InAppMessagePrepareResult);


/**
 * In-app message adapter protocol. An adapter is responsible for displaying a particular type of in-app message.
 */
NS_SWIFT_NAME(InAppMessageAdapterProtocol)
@protocol UAInAppMessageAdapterProtocol <NSObject>

@optional

/**
 * Displays the in-app message.
 *
 * @param completionHandler the completion handler to be called when adapter has finished
 * displaying the in-app message.
 */
- (void)display:(void (^)(UAInAppMessageResolution *))completionHandler;


@required

/**
 * Factory method to create an in-app message adapter.
 *
 * @param message The in-app message.
 */
+ (instancetype)adapterForMessage:(UAInAppMessage *)message;


/**
 * Prepares in-app message to display.
 *
 * @param assets the assets for this in-app message
 * @param completionHandler the completion handler to be called when adapter has finished
 * preparing the in-app message.
 */
- (void)prepareWithAssets:(UAInAppMessageAssets *)assets
        completionHandler:(void (^)(UAInAppMessagePrepareResult result))completionHandler;

/**
 * Informs the adapter of the ready state of the in-app message immediately before display.
 *
 * @return `YES` if the in-app message is ready, `NO` otherwise.
 */
- (BOOL)isReadyToDisplay;


@end

NS_ASSUME_NONNULL_END
