/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Category extensions for URL encoding and decoding of strings.
 */
@interface NSString(UAURLEncoding)

/**
 * URL decodes the receiver.
 * @param encoding The desired NSStringEncoding for the result.
 * @return A URL decoded NSString, or `nil` if decoding failed.
 */
- (nullable NSString *)urlDecodedStringWithEncoding:(NSStringEncoding)encoding;

/**
 * URL encodes the receiver.
 * @param encoding The desired NSStringEncoding for the result.
 * @return A URL decoded NSString, or `nil` if decoding failed.
 */
- (nullable NSString *)urlEncodedStringWithEncoding:(NSStringEncoding)encoding;

@end

NS_ASSUME_NONNULL_END
