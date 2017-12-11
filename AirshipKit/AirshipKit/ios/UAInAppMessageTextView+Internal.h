/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageTextInfo.h"

/**
 * The in-app message text view that consists of a stack view that can
 * be populated with a header and/or a body
 */
@interface UAInAppMessageTextView : UIView

/**
 * Text view factory method.

 * @param heading The heading text info.
 * @param body The body text info.
 *
 * @return a configured UAInAppMessageTextView instance.
 */
+ (instancetype)textViewWithHeading:(UAInAppMessageTextInfo *)heading body:(UAInAppMessageTextInfo *)body;

@end
