/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Common Airship Errors
 * @note For internal use only. :nodoc:
 */
@interface NSError(UAAdditions)

+ (NSError *)airshipParseErrorWithMessage:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
