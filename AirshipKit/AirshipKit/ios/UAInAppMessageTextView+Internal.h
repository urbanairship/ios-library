/* Copyright 2018 Urban Airship and Contributors */

#import "UAInAppMessageTextInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The in-app message text view that consists of a stack view that can
 * be populated with a header and/or a body
 */
@interface UAInAppMessageTextView : UIView

/**
 * Text view factory method.

 * @param heading The heading text info.
 * @param body The body text info.
 * @param owner The "File Owner" of the view
 *
 * @return a configured UAInAppMessageTextView instance, or nil if neither heading or body are provided.
 */
+ (nullable instancetype)textViewWithHeading:(UAInAppMessageTextInfo * _Nullable)heading
                                        body:(UAInAppMessageTextInfo * _Nullable)body
                                       owner:(id)owner;

@end

NS_ASSUME_NONNULL_END
