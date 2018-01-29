/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAPIClient+Internal.h"

@class UAPreferenceDataStore;
@class UARemoteDataPayload;

NS_ASSUME_NONNULL_BEGIN

///---------------------------------------------------------------------------------------
/// @name Typedefs
///---------------------------------------------------------------------------------------

/**
 * A block called when the refresh of the remote data succeeded.
 *
 * @param statusCode The request status code.
 * @param remoteData The refreshed remote data.
 */
typedef void (^UARemoteDataRefreshSuccessBlock)(NSUInteger statusCode, NSArray<NSDictionary *> * __nullable remoteData);

/**
 * A block called when the refresh of the remote data failed.
 */
typedef void (^UARemoteDataRefreshFailureBlock)(void);

@interface UARemoteDataAPIClient : UAAPIClient

///---------------------------------------------------------------------------------------
/// @name Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Create the remote data API client.
 *
 * @param config The Urban Airship config.
 * @param dataStore A UAPreferenceDataStore to store persistent preferences
 * @return The remote data API client instance.
 */
+ (UARemoteDataAPIClient *)clientWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Refresh the remote data by calling the remote data cloud API.
 *
 * @param successBlock The block called when the refresh of the remote data succeeds.
 * @param failureBlock The block called when the refresh of the remote data fails.
 * @return A UADisposable token which can be used to cancel callback execution.
 *
 * Note: one block and only one block will be called.
 */
- (UADisposable *)fetchRemoteData:(UARemoteDataRefreshSuccessBlock)successBlock onFailure:(UARemoteDataRefreshFailureBlock)failureBlock;

/**
 * Clears the last modified time for message list requests.
 */
- (void)clearLastModifiedTime;

@end

NS_ASSUME_NONNULL_END
