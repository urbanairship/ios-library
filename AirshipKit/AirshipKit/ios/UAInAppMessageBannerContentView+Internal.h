/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageBannerContentView : UIView

/**
 * Factory method for the banner content view. The banner content view holds banner text
 * and an optional image.
 *
 * @param contentLayout The banner content layout.
 * @param headerView The subview that holds the header.
 * @param bodyView The subview that holds the body.
 * @param mediaView The media view.
 *
 * @return a configured UAInAppMessageBannerContentView instance.
 */
+ (nullable instancetype)contentViewWithLayout:(UAInAppMessageBannerContentLayoutType)contentLayout
                                    headerView:(nullable UAInAppMessageTextView *)headerView
                                      bodyView:(nullable UAInAppMessageTextView *)bodyView
                                     mediaView:(nullable UAInAppMessageMediaView *)mediaView;

@end

NS_ASSUME_NONNULL_END

