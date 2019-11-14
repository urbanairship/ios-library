/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Airship Version.
 */
@interface UAirshipVersion : NSObject

///---------------------------------------------------------------------------------------
/// @name Airship Version Core Methods
///---------------------------------------------------------------------------------------

/**
 * Returns the Airship version.
 */
+ (nonnull NSString *)get;

@end
