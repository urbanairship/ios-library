/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

@class UADisposable;

NS_ASSUME_NONNULL_BEGIN

/**
 * Network monitor.
 * @note For internal use only. :nodoc:
 */
@interface UANetworkMonitor : NSObject

/**
 * `YES` if the device has network connectivity, otherwise `NO`.
 */
@property(nonatomic, readonly) BOOL isConnected;

/**
 * Subscribes to network connection updates.
 *
 * @param callBack The callback.
 * @return A disposable to unsubscribe to updates.
 */
- (UADisposable *)connectionUpdates:(void (^)(BOOL))callBack API_AVAILABLE(ios(12), tvos(12));

@end

NS_ASSUME_NONNULL_END
