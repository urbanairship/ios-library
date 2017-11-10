/* Copyright 2017 Urban Airship and Contributors */

#import "UALegacyInAppMessageView.h"

NS_ASSUME_NONNULL_BEGIN

@interface UALegacyInAppMessageView ()

///---------------------------------------------------------------------------------------
/// @name In App Message View Internal Properties
///---------------------------------------------------------------------------------------

/**
 * Block invoked whenever the [UIView layoutSubviews] method is called.
 */
@property(nonatomic, copy) void (^onLayoutSubviews)(void);

@end

NS_ASSUME_NONNULL_END
