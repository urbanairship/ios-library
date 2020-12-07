/* Copyright Airship and Contributors */

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a constraint on occurrences within a given time period.
 */
@interface UAFrequencyConstraintData : NSManagedObject

/**
 * The constraint identifier.
 */
@property(nonatomic, copy) NSString *identifier;

/**
 * The time range.
 */
@property(nonatomic, assign) NSTimeInterval range;

/**
 * The number of allowed occurences.
 */
@property(nonatomic, assign) NSUInteger count;

@end

NS_ASSUME_NONNULL_END
