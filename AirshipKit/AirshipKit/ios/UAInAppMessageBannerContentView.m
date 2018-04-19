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

+ (instancetype)contentViewWithLayout:(UAInAppMessageBannerContentLayoutType)contentLayout textView:(UAInAppMessageTextView *)textView mediaView:(UAInAppMessageMediaView * _Nullable)mediaView {
    NSString *nibName = UAInAppMessageBannerContentViewNibName;
    NSBundle *bundle = [UAirship resources];
    
    // Left and right IAM views are firstObject and lastObject, respectively.
    UAInAppMessageBannerContentView *view;
    switch (contentLayout) {
        case UAInAppMessageBannerContentLayoutTypeMediaLeft:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];
            break;
        case UAInAppMessageBannerContentLayoutTypeMediaRight:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] lastObject];
            break;
    }
    
    [view configureContentViewWithLayout:contentLayout textView:textView mediaView:mediaView];
    
    return view;
}

- (void)configureContentViewWithLayout:(UAInAppMessageBannerContentLayoutType)contentLayout textView:(UAInAppMessageTextView *)textView mediaView:(UAInAppMessageMediaView * _Nullable)mediaView {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = NO;
    
    self.backgroundColor = [UIColor clearColor];
    
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerView.backgroundColor = [UIColor clearColor];
    
    if (mediaView) {
        [self.mediaContainerView addSubview:mediaView];
        [UAInAppMessageUtils applyContainerConstraintsToContainer:self.mediaContainerView containedView:mediaView];
    } else {
        [self.mediaContainerView removeFromSuperview];
    }
    
    [self addTextView:textView];
    
    [self.textContainerView layoutIfNeeded];
    [self.mediaContainerView layoutIfNeeded];
    [self layoutIfNeeded];
}

- (void)addTextView:(UAInAppMessageTextView *)textView {
    [self.textContainerView addSubview:textView];
    [UAInAppMessageUtils applyContainerConstraintsToContainer:self.textContainerView containedView:textView];
}

@end

NS_ASSUME_NONNULL_END

