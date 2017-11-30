/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageButtonInfo.h"

@interface UAInAppMessageButtonView : UIView

/**
 * Buttons populating this button view.
 */
@property(nonatomic, strong, readonly) NSArray<UAInAppMessageButtonInfo *> *buttons;

/**
 * Button view's button layout.
 */
@property(nonatomic, strong, readonly) NSString *buttonLayout;

/**
 * Button layout factory method.
 */
+ (instancetype)buttonViewWithButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons layout:(NSString *)layout;

@end
