/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "UAMessageCenterListViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Default implementation of UISplitViewControllerDelegate for use with UAMessageCenterSplitViewController.
 */
@interface UADefaultMessageCenterSplitViewDelegate : NSObject <UISplitViewControllerDelegate>

- (instancetype)initWithListViewController:(UAMessageCenterListViewController *)listViewController;

@end

NS_ASSUME_NONNULL_END
