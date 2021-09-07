/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAOccurrence+Internal.h"
#import "UAFrequencyConstraint+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

@class UARuntimeConfig;

/**
 * Datastore for frequency constraints and occurrences.
 * All data access methods are blocking.
 */
@interface UAFrequencyLimitStore : NSObject

/**
 * UAFrequencyLimitStore factory method.
 *
 * @param config The runtime config.
 */
+ (instancetype)storeWithConfig:(UARuntimeConfig *)config;

/**
 * UAFrequencyLimitStore factory method for testing purposes.
 *
 * @param name The store name.
 * @param inMemory Whether to store data in memory.
 */
+ (instancetype)storeWithName:(NSString *)name inMemory:(BOOL)inMemory;

/**
 * Gets all constraints.
 *
 * @return The constraints.
 */
- (NSArray<UAFrequencyConstraint *> *)getConstraints;

/**
 * Gets all constraints corresponding to the provided identifiers.
 *
 * @param constraintIDs The constraint identifiers.
 * @return The constraints.
 */
- (NSArray<UAFrequencyConstraint *> *)getConstraints:(NSArray<NSString *> *)constraintIDs;

/**
 * Saves a constraint.
 *
 * @param constraint The constraint.
 * @return Whether the operation was successful.
 */
- (BOOL)saveConstraint:(UAFrequencyConstraint *)constraint;

/**
 * Deletes a constraint.
 *
 * @param constraint The constraint.
 * @return Whether the operation was successful.
 */
- (BOOL)deleteConstraint:(UAFrequencyConstraint *)constraint;

/**
 * Deletes constraints by identifier
 *
 * @param constraintIDs The constraint identifiers.
 * @return Whether the operation was successful.
 */
- (BOOL)deleteConstraints:(NSArray<NSString *> *)constraintIDs;

/**
 * Gets occurrences by parent constraint ID, in ascending temporal order.
 *
 * @param constraintID The parent constraint identifier
 * @return The occurrences.
 */
- (NSArray<UAOccurrence *> *)getOccurrences:(NSString *)constraintID;

/**
 * Saves occurrences.
 *
 * @param occurrences The occurrences.
 * @return Whether the operation was successful.
 */
- (BOOL)saveOccurrences:(NSArray<UAOccurrence *> *)occurrences;

/**
 * Shuts down the store and prevents any subsequent interaction with the managed context. Used by Unit Tests.
 */
- (void)shutDown;

@end

NS_ASSUME_NONNULL_END
