/* Copyright Airship and Contributors */

#import <CoreData/CoreData.h>
#import "UAFrequencyConstraintData+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the occurrence of an frequency-constrained event
 */
@interface UAOccurrenceData : NSManagedObject

/**
 * The parent constraint.
 */
@property(nonatomic, strong) UAFrequencyConstraintData *constraint;

/**
 * The timestamp
 */
@property(nonatomic, strong) NSDate *timestamp;

@end

NS_ASSUME_NONNULL_END
