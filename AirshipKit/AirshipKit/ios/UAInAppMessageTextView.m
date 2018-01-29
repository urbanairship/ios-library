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
    return [[UAInAppMessageTextView alloc] initWithHeading:heading body:body];
}

- (nullable instancetype)initWithHeading:(UAInAppMessageTextInfo * _Nullable)heading body:(UAInAppMessageTextInfo * _Nullable)body {
    self = [super init];

    NSString *nibName = UAInAppMessageTextViewNibName;
    NSBundle *bundle = [UAirship resources];

    self = [[bundle loadNibNamed:nibName owner:self options:nil] firstObject];

    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        if (heading) {
            UILabel *headingLabel = [[UILabel alloc] init];
            headingLabel.translatesAutoresizingMaskIntoConstraints = NO;

            self.headingLabel = headingLabel;
            [self.headingLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

            [UAInAppMessageUtils applyTextInfo:heading label:headingLabel];

            [self.textContainer addArrangedSubview:headingLabel];
        }

        if (body) {
            UILabel *bodyLabel = [[UILabel alloc] init];
            bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
            self.bodyLabel = bodyLabel;
            [self.bodyLabel setContentHuggingPriority:UILayoutPriorityRequired
                                              forAxis:UILayoutConstraintAxisVertical];

            [UAInAppMessageUtils applyTextInfo:body label:bodyLabel];

            [self.textContainer addArrangedSubview:bodyLabel];
        }

        [UIView performWithoutAnimation:^{
            [self.textContainer layoutIfNeeded];
        }];
    }

    if (!heading && !body) {
        return nil;
    }

    return self;
}

@end

NS_ASSUME_NONNULL_END
