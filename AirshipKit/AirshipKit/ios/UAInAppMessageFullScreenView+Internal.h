/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageTextView;
@class UAInAppMessageButtonView;
@class UAInAppMessageFullScreenContentView;
@class UAInAppMessageFullScreenDisplayContent;
@class UAInAppMessageMediaView;
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
 * @param mediaView The media view.
 * @param owner The "File Owner" of the view
 *
 * @return a configured UAInAppMessageFullScreenView instance.
 */
+ (nullable instancetype)fullScreenMessageViewWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                                     closeButton:(UIButton *)closeButton
                                                      buttonView:( UAInAppMessageButtonView * _Nullable)buttonView
                                                    footerButton:(UIButton * _Nullable )footerButton
                                                       mediaView:(UAInAppMessageMediaView * _Nullable)mediaView
                                                           owner:(id)owner;

@end

NS_ASSUME_NONNULL_END
