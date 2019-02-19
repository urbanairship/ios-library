/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UAUtils.h"

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

@end

NS_ASSUME_NONNULL_END
