/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@class UAInAppMessageHTMLDisplayContent;
@class UAWebView;
@class UABeveledLoadingIndicator;

NS_ASSUME_NONNULL_BEGIN

/**
 * The HTML view
 */
@interface UAInAppMessageHTMLView : UIView

/**
 * The underlying web view.
 */
@property (nonatomic, readonly) UAWebView *webView;

/**
 * The loading indicator.
 */
@property (nonatomic, readonly) UABeveledLoadingIndicator *loadingIndicator;

/**
 * Factory method for the HTML view.
 *
 * @param displayContent The display content.
 * @param closeButton The button that closes the full screen view.
 * @param owner The "File Owner" of the view
 *
 * @return a configured UAInAppMessageHTMLView instance.
 */
+ (instancetype)htmlViewWithDisplayContent:(UAInAppMessageHTMLDisplayContent *)displayContent
                               closeButton:(UIButton *)closeButton
                                     owner:(id)owner;

@end

NS_ASSUME_NONNULL_END
