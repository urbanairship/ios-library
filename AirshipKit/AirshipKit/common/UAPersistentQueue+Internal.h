/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPreferenceDataStore+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A queue which serializes to a preference data store objects that conform to the
 * NSCoding protocol. Useful for sequentially feeding data to API clients, or other
 * queue-like operations that also require persistence.
 */
@interface UAPersistentQueue : NSObject

/**
 * UAPersistentQueue class factory method.
 *
 * @param dataStore A preference dataStore.
 * @param key A key string used to differentiate the queue in the data store.
 */
+ (instancetype)persistentQueueWithDataStore:(UAPreferenceDataStore *)dataStore key:(NSString *)key;

/**
 * Adds an object to the queue.
 *
 * @param object The object.
 */
- (void)addObject:(id<NSCoding>)object;

/**
 * Adds multiple objects to the queue.
 *
 * @param objects The objects.
 */
- (void)addObjects:(NSArray<id<NSCoding>> *)objects;

/**
 * Peeks the top-most object.
 *
 * @return The top-most object if present, or nil if the queue is empty.
 */
- (nullable id<NSCoding>)peekObject;

/**
 * Pops the top-most object.
 *
 * @return The top-most object if present, or nil if the queue is empty.
 */
- (nullable id<NSCoding>)popObject;

/**
 * Returns all objects from the queue.
 *
 * @return All objects from the queue, or an empty array if the queue is empty.
 */
- (NSArray<id<NSCoding>> *)objects;

/**
 * Replaces the queue with the provided objects
 *
 * @param objects The objects.
 */
- (void)setObjects:(NSArray<id<NSCoding>> *)objects;

/**
 * Clears the queue.
 */
- (void)clear;

@end

NS_ASSUME_NONNULL_END
