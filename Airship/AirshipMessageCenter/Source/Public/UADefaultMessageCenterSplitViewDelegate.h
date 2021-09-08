/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "UADefaultMessageCenterListViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Default implementation of UISplitViewControllerDelegate for use with UAMessageCenterSplitViewController.
 */
NS_SWIFT_NAME(DefaultMessageCenterSplitViewDelegate)
@interface UADefaultMessageCenterSplitViewDelegate : NSObject <UISplitViewControllerDelegate>

- (instancetype)initWithListViewController:(UADefaultMessageCenterListViewController *)listViewController;

@end

NS_ASSUME_NONNULL_END
