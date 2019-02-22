/* Copyright Urban Airship and Contributors */

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
/// @name Device ID
///---------------------------------------------------------------------------------------

/**
 * Gets the device ID from the Keychain. The completion handler will be invoked
 * on a background queue.
 *
 * @param completionHandler A completion handler which will be passed the device ID.
 */
+ (void)getDeviceID:(void (^)(NSString *))completionHandler;

/**
 * Gets the device ID from the Keychain.
 *
 * @param completionHandler A completion handler which will be passed the device ID.
 * @param dispatcher The dispatcher to use when invoking the completion handler. If `nil`, a background dispatcher will be used.
 */
+ (void)getDeviceID:(void (^)(NSString *))completionHandler dispatcher:(nullable UADispatcher *)dispatcher;

#if !TARGET_OS_TV   // Inbox not supported on tvOS
/**
 * Gets the user auth header string for the provided user data.
 *
 * @param userData The user data.
 */
+ (NSString *)userAuthHeaderString:(UAUserData *)userData;
#endif

@end

NS_ASSUME_NONNULL_END
