/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Prrovides checks against a given collection of frequency constraints.
 */
@interface UAFrequencyChecker : NSObject

/**
 * UAFrequencyChecker factory method.
 *
 * @param isOverLimitBlock The over limit block.
 * @param checkAndIncrementBlock The check and increment block.
 */
+ (instancetype)frequencyCheckerWithIsOverLimit:(BOOL (^)(void))isOverLimitBlock
                              checkAndIncrement:(BOOL (^)(void))checkAndIncrementBlock;
/**
 * Checks if the frequency constraints are over the limit.
 *
 * @return `YES` if the frequency constraints are over the limit, `NO` otherwise.
 */
- (BOOL)isOverLimit;

/**
 * Checks if the frequency constraints are over the limit before incrementing the count towards the constraints.
 *
 * @return `YES` if the constraints are not over the limit and the count was incremented, `NO` otherwise.
 */
- (BOOL)checkAndIncrement;

@end

NS_ASSUME_NONNULL_END
