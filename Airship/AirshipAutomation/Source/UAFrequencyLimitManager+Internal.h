/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAAirshipAutomationCoreImport.h"
#import "UAFrequencyLimitStore+Internal.h"
#import "UAFrequencyChecker+Internal.h"

@class UADispatcher;
@class UADate;

NS_ASSUME_NONNULL_BEGIN

/**
 * Manager for keeping track of frequency limits and occurence counts.
 */
@interface UAFrequencyLimitManager : NSObject

/**
 * UAFrequencyLImitManager constructor.
 */
+ (instancetype)managerWithConfig:(UARuntimeConfig *)config;

/**
 * UAFrequencyLImitManager constructor for testing purposes.
 *
 * @param dataStore The frequency limit store.
 * @param date The date.
 * @param dispatcher A private serial dispatcher
 */
+ (instancetype)managerWithDataStore:(UAFrequencyLimitStore *)dataStore date:(UADate *)date dispatcher:(UADispatcher *)dispatcher;

/**
 * Gets a frequency checker tied to the current snapshot of the passed constraints by ID.
 *
 * @param completionHandler A completion handler called with the result.
 */
- (void)getFrequencyChecker:(NSArray<NSString *> *)constraintIDs completionHandler:(void (^)(UAFrequencyChecker *))completionHandler;

/**
 * Updates the frequency constraints.
 *
 * @param constraints The constraints.
 */
- (void)updateConstraints:(NSArray<UAFrequencyConstraint *> *)constraints;

@end

NS_ASSUME_NONNULL_END
