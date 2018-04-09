/* Copyright 2018 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppMessageTextViewNibName = @"UAInAppMessageTextView";

@interface UAInAppMessageTextView ()

@property (strong, nonatomic) UILabel *headingLabel;
@property (strong, nonatomic) UILabel *bodyLabel;

@property (strong, nonatomic) IBOutlet UIStackView *textContainer;

@end

@implementation UAInAppMessageTextView

+ (nullable instancetype)textViewWithHeading:(UAInAppMessageTextInfo * _Nullable)heading
                               body:(UAInAppMessageTextInfo * _Nullable)body {
    
    NSString *nibName = UAInAppMessageTextViewNibName;
    NSBundle *bundle = [UAirship resources];

    UAInAppMessageTextView *view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];

    if (view) {
        view.translatesAutoresizingMaskIntoConstraints = NO;

        if (heading) {
            UILabel *headingLabel = [[UILabel alloc] init];
            headingLabel.translatesAutoresizingMaskIntoConstraints = NO;

            view.headingLabel = headingLabel;
            [view.headingLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

            [UAInAppMessageUtils applyTextInfo:heading label:headingLabel];

            [view.textContainer addArrangedSubview:headingLabel];
        }

        if (body) {
            UILabel *bodyLabel = [[UILabel alloc] init];
            bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
            view.bodyLabel = bodyLabel;
            [view.bodyLabel setContentHuggingPriority:UILayoutPriorityRequired
                                              forAxis:UILayoutConstraintAxisVertical];

            [UAInAppMessageUtils applyTextInfo:body label:bodyLabel];

            [view.textContainer addArrangedSubview:bodyLabel];
        }

        [UIView performWithoutAnimation:^{
            [view.textContainer layoutIfNeeded];
        }];
    }

    if (!heading && !body) {
        return nil;
    }

    return view;
}

@end

NS_ASSUME_NONNULL_END
