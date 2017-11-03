/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@class UARemoteDataStorePayload;
@class UARemoteDataPayload;
@class UAConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * Manager class for the Remote Data CoreData store. Use this class
 * to add, delete, fetch and update remote data in the database.
 */
@interface UARemoteDataStore : NSObject

///---------------------------------------------------------------------------------------
/// @name Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Initializes the remote data db manager with the given config.
 *
 * @param config The Urban Airship config.
 * @return Initialized configuration
 */
- (instancetype)initWithConfig:(UAConfig *)config;

/**
 * Updates the remote data store with the array of remote data.
 *
 * @param remoteDataPayloads An array of remote data as JSON
 * @param completionHandler The completion handler with the sync result.
 *
 */
- (void)overwriteCachedRemoteDataWithResponse:(NSArray<UARemoteDataPayload *> *)remoteDataPayloads
                 completionHandler:(void(^)(BOOL))completionHandler;

/**
 * Fetches remote data with a specified predicate on the background context.
 *
 * @param predicate An NSPredicate querying a subset of remote data.
 * @param completionHandler An optional completion handler called when the fetch is complete.
 */
- (void)fetchRemoteDataFromCacheWithPredicate:(nullable NSPredicate *)predicate
                   completionHandler:(void(^)(NSArray<UARemoteDataStorePayload *>*remoteDataPayloads))completionHandler;

@end

NS_ASSUME_NONNULL_END
