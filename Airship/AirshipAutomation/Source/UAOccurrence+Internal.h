/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the occurrence of an frequency-constrained event
 */
@interface UAOccurrence : NSObject

/**
 * The parent constraint ID.
 */
@property(nonatomic, readonly) NSString *parentConstraintID;

/**
 * The timestamp
 */
@property(nonatomic, readonly) NSDate *timestamp;

+ (instancetype)occurrenceWithParentConstraintID:(NSString *)parentConstrantID
                                       timestamp:(NSDate *)timestamp;

@end

NS_ASSUME_NONNULL_END
