/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAInAppMessageButtonInfo.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageTextView+Internal.h"

@interface UAInAppMessageUtils : NSObject

/**
 * Applies button info to a button.
 *
 * @param button The button view.
 * @param buttonInfo The button info.
 * @param borderRadius The border radius.
 */
+ (void)applyButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo buttonView:(UAInAppMessageButtonView *)buttonView;

/**
 * Applies text info to a text view.
 *
 * @param textView The text view.
 * @param textInfo The text info.
 */
+ (void)applyTextInfo:(UAInAppMessageTextInfo *)textInfo textView:(UAInAppMessageTextView *)textView;

@end
