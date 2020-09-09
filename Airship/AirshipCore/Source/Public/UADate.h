/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The UADate class provides date utilities.
 * @note For internal use only. :nodoc:
 */
@interface UADate : NSObject

/**
 * The current date and time.
 */
@property (nonatomic, readonly) NSDate *now;

@end

NS_ASSUME_NONNULL_END
