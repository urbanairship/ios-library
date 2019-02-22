/* Copyright Urban Airship and Contributors */

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
 * Factory method for remote data store
 *
 * @param storeName The store name.
 * @param inMemory Whether to use an in-memory database. If `NO` the store will default to SQLite.
 *
 * @return Remote Data store.
 */
+ (instancetype)storeWithName:(NSString *)storeName inMemory:(BOOL)inMemory;

/**
 * Factory method for remote data store.
 *
 * @param storeName The store name.
 *
 * @return Remote Data store.
 */
+ (instancetype)storeWithName:(NSString *)storeName;

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

/**
 * Waits for the store to become idle and then returns. Used by Unit Tests.
 */
- (void)waitForIdle;

/**
 * Shuts down the store and prevents any subsequent interaction with the managed context. Used by Unit Tests.
 */
- (void)shutDown;

@end

NS_ASSUME_NONNULL_END
