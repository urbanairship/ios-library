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
    return [[self alloc] initContentViewWithLayout:contentLayout textView:textView mediaView:mediaView];
}

- (instancetype)initContentViewWithLayout:(UAInAppMessageBannerContentLayoutType)contentLayout textView:(UAInAppMessageTextView *)textView mediaView:(UAInAppMessageMediaView * _Nullable)mediaView {

    NSString *nibName = UAInAppMessageBannerContentViewNibName;
    NSBundle *bundle = [UAirship resources];
    
    // Left and right IAM views are firstObject and lastObject, respectively.
    switch (contentLayout) {
        case UAInAppMessageBannerContentLayoutTypeMediaLeft:
            self = [[bundle loadNibNamed:nibName owner:self options:nil] firstObject];
            break;
        case UAInAppMessageBannerContentLayoutTypeMediaRight:
            self = [[bundle loadNibNamed:nibName owner:self options:nil] lastObject];
            break;
    }
    
    if (self) {
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
    
    return self;
}

- (void)addTextView:(UAInAppMessageTextView *)textView {
    [self.textContainerView addSubview:textView];
    [UAInAppMessageUtils applyContainerConstraintsToContainer:self.textContainerView containedView:textView];
}

@end

NS_ASSUME_NONNULL_END

