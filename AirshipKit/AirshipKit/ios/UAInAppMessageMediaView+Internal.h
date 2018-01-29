/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageMediaInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The in-app message text view that can be populated with an image, video or YouTube clip
 */
@interface UAInAppMessageMediaView : UIView

/**
 * Factory method for creating an in-app message media view.
 *
 * @param mediaInfo The media info.
 */
+ (instancetype)mediaViewWithMediaInfo:(UAInAppMessageMediaInfo *)mediaInfo;

/**
 * Factory method for creating an in-app message media view with an image.
 *
 * @param image The image.
 */
+ (instancetype)mediaViewWithImage:(UIImage *)image;


@end

NS_ASSUME_NONNULL_END
