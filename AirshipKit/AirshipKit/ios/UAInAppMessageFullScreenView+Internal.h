/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageTextView;
@class UAInAppMessageButtonView;
@class UAInAppMessageFullScreenContentView;
@class UAInAppMessageFullScreenDisplayContent;

/**
 * The full screen view.
 */
@interface UAInAppMessageFullScreenView : UIView

/**
 * Factory method for the full screen view.
 *
 * @param displayContent The full screen display content.
 * @param closeButton The button that closes the full screen view.
 * @param buttonView The subview that holds the buttons.
 * @param footerButton The button that displays footer link text and opens the footer link.
 * @param imageView The image view.
 *
 * @return a configured UAInAppMessageFullScreenView instance.
 */
+ (instancetype)fullScreenMessageViewWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                            closeButton:(UIButton *)closeButton
                                             buttonView:( UAInAppMessageButtonView * _Nullable)buttonView
                                           footerButton:(UIButton * _Nullable )footerButton
                                              imageView:(UIImageView * _Nullable)imageView;

@end

NS_ASSUME_NONNULL_END
