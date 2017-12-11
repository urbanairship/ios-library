/* Copyright 2017 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageUtils+Internal.h"

NSString *const UAInAppMessageTextViewNibName = @"UAInAppMessageTextView";

@interface UAInAppMessageTextView ()

@property (strong, nonatomic) UILabel *headingLabel;
@property (strong, nonatomic) IBOutlet UIStackView *textContainer;

@end

@implementation UAInAppMessageTextView

+ (instancetype)textViewWithHeading:(UAInAppMessageTextInfo *)heading
                               body:(UAInAppMessageTextInfo *)body {
    return [[UAInAppMessageTextView alloc] initWithHeading:heading body:body];
}

- (instancetype)initWithHeading:(UAInAppMessageTextInfo *)heading body:(UAInAppMessageTextInfo *)body {
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

            [UAInAppMessageUtils applyTextInfo:heading label:headingLabel];

            // Mutli-line labels might break in earlier versions
            //Nest label inside view because UIStack views are broken for labels

            [self.textContainer addArrangedSubview:headingLabel];
        }
        if (body) {

            UILabel *bodyLabel = [[UILabel alloc] init];
            bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;

            [UAInAppMessageUtils applyTextInfo:body label:bodyLabel];
            [self.textContainer addArrangedSubview:bodyLabel];
        }

        [UIView performWithoutAnimation:^{
            [self.textContainer layoutIfNeeded];
        }];
    }

    return self;
}

@end
