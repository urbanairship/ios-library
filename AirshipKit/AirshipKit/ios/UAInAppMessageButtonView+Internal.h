/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageButtonInfo.h"
#import "UAInAppMessageButton+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The in-app message button view that consists of a stack view that can
 * be populated with n buttons as defined by a button layout string.
 */
@interface UAInAppMessageButtonView : UIView

/**
 * Button view factory method.

 * @param buttons The button infos to add to the view.
 * @param layout The button layout.
 * @param target The object that will handle the button events. Also, the "File Owner" of the view.
 * @param selector The selector to call on the target when a button event occurs.
 *
 * @return a configured UAInAppMessageButtonView instance.
 */
+ (instancetype)buttonViewWithButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons
                               layout:(UAInAppMessageButtonLayoutType)layout
                               target:(id)target
                             selector:(SEL)selector;

@end

NS_ASSUME_NONNULL_END
