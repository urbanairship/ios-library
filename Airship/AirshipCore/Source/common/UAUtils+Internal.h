/* Copyright Airship and Contributors */

#import "UAUtils.h"
#import "UADispatcher.h"

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
/// @name Device ID
///---------------------------------------------------------------------------------------

/**
 * Gets the device ID from the Keychain.
 *
 * @param completionHandler A completion handler which will be passed the device ID.
 * @param dispatcher The dispatcher to use when invoking the completion handler. If `nil`, a background dispatcher will be used.
 */
+ (void)getDeviceID:(void (^)(NSString *))completionHandler dispatcher:(nullable UADispatcher *)dispatcher;

@end

NS_ASSUME_NONNULL_END
