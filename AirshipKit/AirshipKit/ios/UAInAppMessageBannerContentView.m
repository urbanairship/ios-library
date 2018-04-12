/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAirship.h"
#import "UAInAppMessageBannerContentView+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppMessageBannerContentViewNibName = @"UAInAppMessageBannerContentView";

@interface UAInAppMessageBannerContentView ()

// Subviews
@property(nonatomic, strong) IBOutlet UIView *mediaContainerView;
@property(nonatomic, strong) IBOutlet UIView *textContainerView;
@property (nonatomic, strong) IBOutlet UIView *containerView;

@end

@implementation UAInAppMessageBannerContentView

+ (instancetype)contentViewWithLayout:(UAInAppMessageBannerContentLayoutType)contentLayout textView:(UAInAppMessageTextView *)textView mediaView:(UAInAppMessageMediaView * _Nullable)mediaView owner:(id)owner {
    NSString *nibName = UAInAppMessageBannerContentViewNibName;
    NSBundle *bundle = [UAirship resources];
    UAInAppMessageBannerContentView *view;
    
    // Left and right IAM views are firstObject and lastObject, respectively.
    switch (contentLayout) {
        case UAInAppMessageBannerContentLayoutTypeMediaLeft:
            view = [[bundle loadNibNamed:nibName owner:owner options:nil] firstObject];
            break;
        case UAInAppMessageBannerContentLayoutTypeMediaRight:
            view = [[bundle loadNibNamed:nibName owner:owner options:nil] lastObject];
            break;
    }
    
    if (view) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        view.userInteractionEnabled = NO;
        
        view.backgroundColor = [UIColor clearColor];
        
        view.containerView.translatesAutoresizingMaskIntoConstraints = NO;
        view.containerView.backgroundColor = [UIColor clearColor];

        if (mediaView) {
            [view.mediaContainerView addSubview:mediaView];
            [UAInAppMessageUtils applyContainerConstraintsToContainer:view.mediaContainerView containedView:mediaView];
        } else {
            [view.mediaContainerView removeFromSuperview];
        }

        [view addTextView:textView];

        [view.textContainerView layoutIfNeeded];
        [view.mediaContainerView layoutIfNeeded];
        [view layoutIfNeeded];
    }
    
    return view;
}

- (void)addTextView:(UAInAppMessageTextView *)textView {
    [self.textContainerView addSubview:textView];
    [UAInAppMessageUtils applyContainerConstraintsToContainer:self.textContainerView containedView:textView];
}

@end

NS_ASSUME_NONNULL_END

