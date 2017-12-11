/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageTextInfo.h"

/**
 * The in-app message text view that consists of a stack view that can
 * be populated with a header and/or a body
 */
@interface UAInAppMessageTextView : UIView

/**
 * Text view factory method.

 * @param buttons The button infos to add to the view.
 * @param layout The button layout.
 * @param target The object that will handle the button events.
 * @param selector The selector to call on the target when button event occurs.
 *
 * @return a configured UAInAppMessageButtonView instance.
 */
+ (instancetype)textViewWithHeading:(UAInAppMessageTextInfo *)heading body:(UAInAppMessageTextInfo *)body;

@end
