/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPadding.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The in-app message style protocol.
 */
@protocol UAInAppMessageStyleProtocol <NSObject>

@required

/**
 * Factory method to create a style.
 */
+ (instancetype)style;

/**
 * Factory method to create a style from a provided plist.
 */
+ (nullable instancetype)styleWithContentsOfFile:(nullable NSString *)path;

@end

NS_ASSUME_NONNULL_END

