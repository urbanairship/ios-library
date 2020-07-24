/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

/**
 *  Extensions for UIImage.
 */
@interface UIImage (UAAdditions)

NS_ASSUME_NONNULL_BEGIN

/**
 * Image factory method that supports animated data.
 * @param data The data.
 * @return The animated image if it is a gif, otherwise the still frame will be loaded.
 */
+ (UIImage *)fancyImageWithData:(NSData *)data;

NS_ASSUME_NONNULL_END
@end
