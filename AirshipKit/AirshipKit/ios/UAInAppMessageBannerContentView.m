/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAirship.h"
#import "UAInAppMessageBannerContentView+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAViewUtils+Internal.h"


NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppMessageBannerContentViewNibName = @"UAInAppMessageBannerContentView";

@interface UAInAppMessageBannerContentView ()

// Subviews
@property(nonatomic, strong) IBOutlet UIView *mediaContainerView;
@property (strong, nonatomic) IBOutlet UIStackView *textStackView;
@property (nonatomic, strong) IBOutlet UIView *containerView;

@property (nonatomic, strong) UILabel *headerView;
@property (nonatomic, strong) UILabel *bodyView;

@end

@implementation UAInAppMessageBannerContentView

+ (nullable instancetype)contentViewWithLayout:(UAInAppMessageBannerContentLayoutType)contentLayout
                                    headerView:(nullable UAInAppMessageTextView *)headerView
                                      bodyView:(nullable UAInAppMessageTextView *)bodyView
                                     mediaView:(nullable UAInAppMessageMediaView *)mediaView {

    NSString *nibName = UAInAppMessageBannerContentViewNibName;
    NSBundle *bundle = [UAirship resources];

    UAInAppMessageBannerContentView *view;
    // Left and right IAM views are firstObject and lastObject, respectively.
    switch (contentLayout) {
        case UAInAppMessageBannerContentLayoutTypeMediaLeft:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];
            break;
        case UAInAppMessageBannerContentLayoutTypeMediaRight:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] lastObject];
            break;
    }

    [view configureContentViewWithLayout:contentLayout headerView:headerView bodyView:bodyView mediaView:mediaView];

    return view;
}

- (void)configureContentViewWithLayout:(UAInAppMessageBannerContentLayoutType)contentLayout headerView:(UAInAppMessageTextView *)headerView bodyView:(UAInAppMessageTextView *)bodyView mediaView:(nullable UAInAppMessageMediaView *)mediaView {

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];

    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerView.backgroundColor = [UIColor clearColor];

    if (mediaView) {
        [self.mediaContainerView addSubview:mediaView];
        [UAViewUtils applyContainerConstraintsToContainer:self.mediaContainerView containedView:mediaView];
    } else {
        [self.mediaContainerView removeFromSuperview];
    }

    if (headerView) {
        self.headerView = headerView.textLabel;
        [self.textStackView addArrangedSubview:headerView];
        [self.headerView sizeToFit];

    }

    if (bodyView) {
        self.bodyView = bodyView.textLabel;
        [self.textStackView addArrangedSubview:bodyView];
        [self.bodyView sizeToFit];
    }

    [self layoutIfNeeded];
}

-(void)layoutSubviews {
    [self.headerView sizeToFit];
    [self.bodyView sizeToFit];
    [self.textStackView layoutIfNeeded];
    [self.mediaContainerView layoutIfNeeded];
}

@end

NS_ASSUME_NONNULL_END

