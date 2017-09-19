/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UARichContentWindow.h"

/**
 * UIWebViewDelegate protocol extension to handle "uairship://close" URL and UAirship.close()
 */
@protocol UAUIWebViewDelegate <UIWebViewDelegate>

@optional

///---------------------------------------------------------------------------------------
/// @name UAUIWebViewDelegate Optional Methods
///---------------------------------------------------------------------------------------

/**
 * Closes the window.
 *
 * @param animated Indicates whether to animate the transition.
 */
- (void)closeWindowAnimated:(BOOL)animated;

@end
