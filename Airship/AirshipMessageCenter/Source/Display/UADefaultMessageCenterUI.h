/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAMessageCenter.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Default message center UI.
 */
@interface UADefaultMessageCenterUI : NSObject<UAMessageCenterDisplayDelegate>

///---------------------------------------------------------------------------------------
/// @name Default Message Center Properties
///---------------------------------------------------------------------------------------

/**
 * The title of the message center.
 */
@property (nonatomic, copy) NSString *title;

/**
 * The style to apply to the default message center.
 */
@property (nonatomic, strong) UAMessageCenterStyle *style;

/**
 * An optional predicate for filtering messages.
 */
@property (nonatomic, strong) NSPredicate *filter;

/**
 * Disables 3D touching and long pressing on links in messages.
 */
@property (nonatomic) BOOL disableMessageLinkPreviewAndCallouts;

@end

NS_ASSUME_NONNULL_END
