/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a constraint on occurrences within a given time period.
 */
@interface UAFrequencyConstraint : NSObject <NSCopying>

/**
 * The constraint identifier.
 */
@property(nonatomic, readonly) NSString *identifier;

/**
 * The time range.
 */
@property(nonatomic, readonly) NSTimeInterval range;

/**
 * The number of allowed occurences.
 */
@property(nonatomic, readonly) NSUInteger count;

/**
 * UAFrequencyConstraint factory method.
 *
 * @param identifier The identifier.
 * @param range The range.
 * @param count The count.
 */
+ (instancetype)frequencyConstraintWithIdentifier:(NSString *)identifier
                                            range:(NSTimeInterval)range
                                            count:(NSUInteger)count;

@end

NS_ASSUME_NONNULL_END
