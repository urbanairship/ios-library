/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageView.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageView ()

/**
 * Block invoked whenever the [UIView layoutSubviews] method is called.
 */
@property(nonatomic, copy) void (^onLayoutSubviews)(void);

@end

NS_ASSUME_NONNULL_END
