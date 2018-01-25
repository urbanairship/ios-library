/* Copyright 2017 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageFullScreenView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageCloseButton+Internal.h"
#import "UAUtils.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppMessageFullScreenViewNibName = @"UAInAppMessageFullScreenView";

@interface UAInAppMessageFullScreenView ()

@property (nonatomic, strong) IBOutlet UIStackView *containerStackView;
@property (strong, nonatomic) IBOutlet UAInAppMessageCloseButton *closeButtonContainer;
@property (strong, nonatomic) IBOutlet UIView *footerButtonContainer;
@property (strong, nonatomic) IBOutlet UIView *messageTop;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

@property (nonatomic, strong) UAInAppMessageFullScreenDisplayContent *displayContent;

@property (nonatomic, strong) UAInAppMessageTextView *topTextView;
@property (nonatomic, strong) UAInAppMessageTextView *bottomTextView;
@property (nonatomic, strong) UAInAppMessageMediaView *mediaView;
@property (nonatomic, strong) UAInAppMessageButtonView *buttonView;

@end

@implementation UAInAppMessageFullScreenView

+ (instancetype)fullScreenMessageViewWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                            closeButton:(UAInAppMessageCloseButton *)closeButton
                                             buttonView:(UAInAppMessageButtonView * _Nullable)buttonView
                                           footerButton:(UIButton * _Nullable)footerButton
                                              mediaView:(UAInAppMessageMediaView * _Nullable)mediaView {

    return [[UAInAppMessageFullScreenView alloc] initFullScreenViewWithDisplayContent:displayContent
                                                                          closeButton:closeButton
                                                                           buttonView:buttonView
                                                                         footerButton:footerButton
                                                                            mediaView:mediaView];
}

- (instancetype)initFullScreenViewWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                         closeButton:(UAInAppMessageCloseButton *)closeButton
                                          buttonView:(UAInAppMessageButtonView * _Nullable)buttonView
                                        footerButton:(UIButton * _Nullable)footerButton
                                           mediaView:(UAInAppMessageMediaView * _Nullable)mediaView {

    NSString *nibName = UAInAppMessageFullScreenViewNibName;
    NSBundle *bundle = [UAirship resources];

    self = [[bundle loadNibNamed:nibName owner:self options:nil] firstObject];

    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.mediaView = mediaView;
        self.buttonView = buttonView;

        // Always add the close button
        [self.closeButtonContainer addSubview:closeButton];
        [UAInAppMessageUtils applyContainerConstraintsToContainer:self.closeButtonContainer containedView:closeButton];

        // Add views that belong in the stack - adding views that are nil will result in no-op
        if (displayContent.contentLayout == UAInAppMessageFullScreenContentLayoutHeaderMediaBody) {
            self.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:nil];
            self.bottomTextView = [UAInAppMessageTextView textViewWithHeading:nil body:displayContent.body];

            [self.containerStackView addArrangedSubview:self.topTextView];
            [self.containerStackView addArrangedSubview:mediaView];
            [self.containerStackView addArrangedSubview:self.bottomTextView];
        } else if (displayContent.contentLayout == UAInAppMessageFullScreenContentLayoutHeaderBodyMedia) {
            
            self.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:displayContent.body];

            [self.containerStackView addArrangedSubview:self.topTextView];
            [self.containerStackView addArrangedSubview:mediaView];
        } else if (displayContent.contentLayout == UAInAppMessageFullScreenContentLayoutMediaHeaderBody) {
            self.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:displayContent.body];

            [self.containerStackView addArrangedSubview:mediaView];
            [self.containerStackView addArrangedSubview:self.topTextView];
        }
        // Button container is always the last thing in the stack
        [self.containerStackView addArrangedSubview:self.buttonView];

        // Add invisible spacer to guarantee it expands instead of other views
        UIView *spacer = [[UIView alloc] initWithFrame:CGRectZero];
        spacer.backgroundColor = [UIColor clearColor];
        [spacer setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
        [self.containerStackView addArrangedSubview:spacer];

        // Explicitly remove footer view from the superview if footer is nil
        if (footerButton) {
            [self.footerButtonContainer addSubview:footerButton];
            [UAInAppMessageUtils applyContainerConstraintsToContainer:self.footerButtonContainer containedView:footerButton];
        } else {
            [self.footerButtonContainer removeFromSuperview];
        }

        self.displayContent = displayContent;
        self.backgroundColor = displayContent.backgroundColor;
        self.scrollView.backgroundColor = displayContent.backgroundColor;
        self.messageTop.backgroundColor = displayContent.backgroundColor;

        self.translatesAutoresizingMaskIntoConstraints = NO;
    }

    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];

    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UAUtils mainWindow];

        // Black out the inset when iPhone X is horizontal
        if (window.safeAreaInsets.top == 0 && window.safeAreaInsets.left > 0) {
            self.backgroundColor = [UIColor blackColor];
        } else {
            self.backgroundColor = self.displayContent.backgroundColor;
        }
    }

    [self.containerStackView layoutIfNeeded];
}

@end

NS_ASSUME_NONNULL_END
