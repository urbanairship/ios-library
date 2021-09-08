/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAMessageCenterListViewDelegate.h"

@class UAInboxMessage;
@class UAMessageCenterStyle;

NS_ASSUME_NONNULL_BEGIN

/**
 * Default implementation of a list-style Message Center UI.
 */
NS_SWIFT_NAME(DefaultMessageCenterListViewController)
@interface UADefaultMessageCenterListViewController : UIViewController <UITableViewDelegate, UITableViewDataSource,
    UIScrollViewDelegate>

///---------------------------------------------------------------------------------------
/// @name Default Message Center List View Controller Properties
///---------------------------------------------------------------------------------------

/**
 * The style to apply to the list.
 */
@property (nonatomic, strong) UAMessageCenterStyle *messageCenterStyle;

/**
 * The style to apply to the list.
 *
 * Note: This property is unavailable in iOS 14. Instead use `messageCenterStyle`.
 */
#if !defined(__IPHONE_14_0)
@property(nonatomic, strong) UAMessageCenterStyle *style;
#endif

/**
 * An optional predicate for filtering messages.
 */
@property (nonatomic, strong) NSPredicate *filter;

/**
 * The list view delegate.
 */
@property (nonatomic, weak) id<UAMessageCenterListViewDelegate> delegate;

/**
 * The currently selected index path.
 */
@property (nonatomic, strong, nullable) NSIndexPath *selectedIndexPath;

/**
 * The currently selected message.
 */
@property (nonatomic, copy, nullable) NSString *selectedMessageID;

@end

NS_ASSUME_NONNULL_END
