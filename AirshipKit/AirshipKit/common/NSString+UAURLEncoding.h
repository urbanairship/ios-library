/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Category extensions for URL encoding and decoding of strings.
 */
@interface NSString(UAURLEncoding)

///---------------------------------------------------------------------------------------
/// @name NSString URL Encoding Additions Core Methods
///---------------------------------------------------------------------------------------

/**
 * URL decodes the receiver.
 *
 * @return A URL dencoded NSString, or `nil` if decoding failed.
 *
 */
- (nullable NSString *)urlDecodedString;

/**
 * URL encodes the receiver.
 *
 * @return A URL encoded NSString, or `nil` if encoding failed.
 *
 */
- (nullable NSString *)urlEncodedString;


@end

NS_ASSUME_NONNULL_END
