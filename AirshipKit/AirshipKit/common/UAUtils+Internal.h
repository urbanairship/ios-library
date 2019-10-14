/* Copyright Airship and Contributors */

#import "UAUtils.h"
#import "UADispatcher+Internal.h"
#import "UAUserData.h"

NS_ASSUME_NONNULL_BEGIN

@class UARequest;

#define kUAConnectionTypeNone @"none"
#define kUAConnectionTypeCell @"cell"
#define kUAConnectionTypeWifi @"wifi"

/**
 * The UAUtils object provides an interface for utility methods.
 */
@interface UAUtils ()

///---------------------------------------------------------------------------------------
/// @name UAHTTP Authenticated Request Helpers
///---------------------------------------------------------------------------------------

+ (void)logFailedRequest:(UARequest *)request
             withMessage:(NSString *)message
               withError:(nullable NSError *)error
            withResponse:(nullable NSHTTPURLResponse *)response;

///---------------------------------------------------------------------------------------
/// @name Math Utilities
///---------------------------------------------------------------------------------------

/**
 * A utility method that compares two floating points and returns `YES` if the
 * difference between them is less than or equal to the absolute value
 * of the specified accuracy.
 */
+ (BOOL)float:(CGFloat)float1 isEqualToFloat:(CGFloat)float2 withAccuracy:(CGFloat)accuracy;

///---------------------------------------------------------------------------------------
/// @name String Utilities
///---------------------------------------------------------------------------------------

/**
 * Returns nil if string is empty or nil, otherwise returns string.
 *
 * @param str The string to check.
 * @return The input NSString, or nil if the input string is empty.
 */
+ (nullable NSString *)nilIfEmpty:(nullable NSString *)str;

///---------------------------------------------------------------------------------------
/// @name Device ID
///---------------------------------------------------------------------------------------

/**
 * Gets the device ID from the Keychain.
 *
 * @param completionHandler A completion handler which will be passed the device ID.
 * @param dispatcher The dispatcher to use when invoking the completion handler. If `nil`, a background dispatcher will be used.
 */
+ (void)getDeviceID:(void (^)(NSString *))completionHandler dispatcher:(nullable UADispatcher *)dispatcher;

///---------------------------------------------------------------------------------------
/// @name SHA-256
///---------------------------------------------------------------------------------------

/**
 * Generate SHA256 digest for input string
 *
 * @param input string for which to calculate SHA
 * @return SHA256 digest as NSData
 */
+ (NSData*)sha256DigestWithString:(NSString*)input;

/**
 * Generate SHA256 digest for input string
 *
 * @param input string for which to calculate SHA
 * @return SHA256 digest as a hex string
 */
+ (NSString *)sha256HashWithString:(NSString*)input;

@end

NS_ASSUME_NONNULL_END
