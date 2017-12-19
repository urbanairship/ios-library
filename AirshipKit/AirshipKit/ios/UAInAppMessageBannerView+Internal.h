/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>

@class UAInAppMessageTextView;
@class UAInAppMessageButtonView;
@class UAInAppMessageBannerContentView;
@class UAInAppMessageBannerDisplayContent;

NS_ASSUME_NONNULL_BEGIN

/**
 * The banner view.
 */
@interface UAInAppMessageBannerView : UIView

/**
 * Toggles the tapped banner look.
 */
@property (nonatomic, assign) BOOL isBeingTapped;

/**
 * Factory method for the banner view.
 *
 * @param displayContent The banner display content.
 * @param contentView The subview that holds the text and optional image.
 * @param buttonView The subview that holds the buttons.
 *
 * @return a configured UAInAppMessageBannerView instance.
 */
+ (instancetype)bannerMessageViewWithDisplayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                                  bannerContentView:(UAInAppMessageBannerContentView *)contentView
                                         buttonView:(UAInAppMessageButtonView * _Nullable)buttonView;

@end

NS_ASSUME_NONNULL_END
