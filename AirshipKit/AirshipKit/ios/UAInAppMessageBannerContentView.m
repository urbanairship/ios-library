/* Copyright 2017 Urban Airship and Contributors */

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
@property(nonatomic, strong) IBOutlet UIView *imageContainerView;
@property(nonatomic, strong) IBOutlet UIView *textContainerView;
@property (nonatomic, strong) IBOutlet UIView *containerView;

@end

@implementation UAInAppMessageBannerContentView

+ (instancetype)contentViewWithLayout:(UAInAppMessageBannerContentLayoutType)contentLayout textView:(UAInAppMessageTextView *)textView image:(UIImage * _Nullable)image {
    return [[self alloc] initContentViewWithLayout:contentLayout textView:textView image:image];
}

- (instancetype)initContentViewWithLayout:(UAInAppMessageBannerContentLayoutType)contentLayout textView:(UAInAppMessageTextView *)textView image:(UIImage * _Nullable)image {

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

        if (image) {
            [self addImage:image];
        } else {
            [self.imageContainerView removeFromSuperview];
        }

        [self addTextView:textView];

        [self.textContainerView layoutIfNeeded];
        [self.imageContainerView layoutIfNeeded];
        [self layoutIfNeeded];
    }
    
    return self;
}

- (void)addTextView:(UAInAppMessageTextView *)textView {
    [self.textContainerView addSubview:textView];
    [UAInAppMessageUtils applyContainerConstraintsToContainer:self.textContainerView containedView:textView];
}

- (void)addImage:(UIImage *)image {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];


    CGFloat imageAspect = image.size.width/image.size.height;
    [self.imageContainerView addSubview:imageView];

   if (imageAspect > 1) { // wide sizing should letterbox
        [self.imageContainerView setBackgroundColor:[UIColor clearColor]];
        [NSLayoutConstraint constraintWithItem:imageView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.imageContainerView
                                     attribute:NSLayoutAttributeWidth
                                    multiplier:1
                                      constant:0].active = YES;

        // Himage = (Wcontainter) * Himage/Wimage + 0
        [NSLayoutConstraint constraintWithItem:imageView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.imageContainerView
                                     attribute:NSLayoutAttributeWidth
                                    multiplier:(1/imageAspect)
                                      constant:0].active = YES;

        //center image
        [UAInAppMessageUtils applyCenterConstraintsToContainer:imageView containedView:self.imageContainerView];

    } else if (imageAspect < 1) { // tall images should letterbox
        [self.imageContainerView setBackgroundColor:[UIColor clearColor]];
        [NSLayoutConstraint constraintWithItem:imageView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.imageContainerView
                                     attribute:NSLayoutAttributeHeight
                                    multiplier:1
                                      constant:0].active = YES;

        // Wimage = (Hcontainter) * Wimage/Himage + 0
        [NSLayoutConstraint constraintWithItem:imageView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.imageContainerView
                                     attribute:NSLayoutAttributeHeight
                                    multiplier:imageAspect
                                      constant:0].active = YES;
        //center image
        [UAInAppMessageUtils applyCenterConstraintsToContainer:imageView containedView:self.imageContainerView];

    } else { // ideal images should keep default aspect fit with no clipping
        [UAInAppMessageUtils applyContainerConstraintsToContainer:self.imageContainerView containedView:imageView];
    }
}

@end

NS_ASSUME_NONNULL_END

