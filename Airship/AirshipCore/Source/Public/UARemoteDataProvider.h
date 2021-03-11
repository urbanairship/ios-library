/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

@class UARemoteDataPayload;
@class UADisposable;

NS_ASSUME_NONNULL_BEGIN

/**
* Block called with remote data..
* @note For internal use only. :nodoc:
*/
typedef void (^UARemoteDataPublishBlock)(NSArray<UARemoteDataPayload *> *remoteDataArray);

/**
 * Protocol used to provide remote data to external modules.
 * @note For internal use only. :nodoc:
 */
@protocol UARemoteDataProvider <NSObject>

@required

/**
 * Subscribe to the remote data manager
 *
 * @param payloadTypes You will be notified when there is new remote data for these payload types
 * @param publishBlock The block on which you will be notified when new remote data arrives for your payload types. The payload order will be
 * sorted by in the order specified by `payloadTypes`. Note: this block will be called ASAP if there is cached remote data for your payload types.
 * @return UADisposable object - call "dispose" on the object to unsubscribe from the remote data manager
 */
- (UADisposable *)subscribeWithTypes:(NSArray<NSString *> *)payloadTypes block:(UARemoteDataPublishBlock)publishBlock;

/**
 * Checks if provided metadata matches a metadata created with the current locale and app version.
 *
 * @return `YES` if the metadata is current, otherwise `NO`.
 */
- (BOOL)isMetadataCurrent:(NSDictionary *)metadata;

@end

NS_ASSUME_NONNULL_END

