/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

/**
 * WKNavigationDelegate protocol extension to handle "uairship://close" URL and UAirship.close()
 */
@protocol UAWKWebViewDelegate <WKNavigationDelegate>

@optional

///---------------------------------------------------------------------------------------
/// @name WKNavigationDelegate Optional Methods
///---------------------------------------------------------------------------------------

/**
 * Closes the window.
 *
 * @param animated Indicates whether to animate the transition.
 */
- (void)closeWindowAnimated:(BOOL)animated;

@end
