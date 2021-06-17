/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @note For internal use only. :nodoc:
 */
@interface UACompression : NSObject

/**
 * Gzips data.
 * @param data To gzip.
 * @returns The gzippe data or `nil` if it failed to gzip.
 */
+ (nullable NSData *)gzipData:(nullable NSData *)data;

@end

NS_ASSUME_NONNULL_END
