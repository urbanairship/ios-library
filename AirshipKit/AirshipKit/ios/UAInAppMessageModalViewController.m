/* Copyright 2017 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAUtils.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageModalViewController+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageCloseButton+Internal.h"


NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageTextView;
@class UAInAppMessageButtonView;
@class UAInAppMessageMediaView;
@class UAInAppMessageModalDisplayContent;

double const DefaultModalAnimationDuration = 0.2;

/**
 * Custom UIScrollView class to handle shrinking UIScrollView when content is smaller.
 */
@interface UAInAppMessageModalScrollView : UIScrollView

/**
 * The modal message view.
 */
@property (nonatomic,strong) UIView *modalView;

/**
 * Content view to hold header, media and body views. Used for UIScrollView sizing.
 */
@property (nonatomic,strong) UIView *contentView;

/**
 * The maximum height constraint on the modal view. Active at init.
 * Used for shrinking scroll view to fit content.
 */
@property (weak, nonatomic) NSLayoutConstraint *modalViewMaxHeightConstraint;

/**
 * The actual height constraint on the modal view. Inactive at init.
 * Used for shrinking scroll view to fit content.
 */
@property (weak, nonatomic) NSLayoutConstraint *modalViewActualHeightConstraint;

@end


@implementation UAInAppMessageModalScrollView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // do we need to shrink the scroll view to fit a smaller content size?
    if (self.frame.size.height > self.contentView.frame.size.height) {
        CGFloat shrinkScrollView = self.frame.size.height - self.contentView.frame.size.height;

        // change constraints on modal view for the shrunken scroll view
        self.modalViewMaxHeightConstraint.active = NO;
        self.modalViewActualHeightConstraint.constant = self.modalView.frame.size.height - shrinkScrollView;
        self.modalViewActualHeightConstraint.active = YES;
        
        [self setNeedsLayout];
    }
}

@end

/**
 * Custom UIView class to handle rounding the border of the modal view.
 */
@interface UAInAppMessageModalView : UIView

/**
 * The modal message's border radius.
 */
@property (nonatomic,assign) CGFloat borderRadius;

@end

@implementation UAInAppMessageModalView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self applyBorderRounding];
}

- (void)applyBorderRounding {
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                           byRoundingCorners:UIRectCornerAllCorners
                                                 cornerRadii:(CGSize){self.borderRadius, self.borderRadius}].CGPath;
    
    self.layer.mask = maskLayer;
}

@end

@interface UAInAppMessageModalViewController ()

/**
 * The new window created in front of the app's existing window.
 */
@property (strong, nonatomic, nullable) UIWindow *modalWindow;

/**
 * The main view of this view controller. The modal view is built on it.
 */
@property (strong, nonatomic) IBOutlet UIView *view;

/**
 * The modal message view.
 */
@property (weak, nonatomic) IBOutlet UAInAppMessageModalView *modalView;

/**
 * The maximum height constraint on the modal view. Active at init.
 * Used for shrinking scroll view to fit content.
 */
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *modalViewMaxHeightConstraint;

/**
 * The actual height constraint on the modal view. Inactive at init.
 * Used for shrinking scroll view to fit content.
 */
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *modalViewActualHeightConstraint;

/**
 * View to hold close (dismiss) button at top of modal message
 */
@property (weak, nonatomic) IBOutlet UIView *closeButtonContainerView;

/**
 * Dismiss button
 */
@property (weak, nonatomic) IBOutlet UAInAppMessageCloseButton *closeButton;

/**
 * Scroll view to hold header, media and body views
 */
@property (weak, nonatomic) IBOutlet UAInAppMessageModalScrollView *scrollView;

/**
 * Content view to hold header, media and body views. Needed for UIScrollView sizing.
 */
@property (weak, nonatomic) IBOutlet UIView *contentView;

/**
 * Views to hold header, media and body views.
 */
@property (weak, nonatomic) IBOutlet UIView *scrollTopView;
@property (weak, nonatomic) IBOutlet UIView *scrollMiddleView;
@property (weak, nonatomic) IBOutlet UIView *scrollBottomView;

/**
 * View to hold buttons
 */
@property (weak, nonatomic) IBOutlet UIView *buttonContainerView;

/**
 * View to hold footer
 */
@property (weak, nonatomic) IBOutlet UIView *footerContainerView;

/**
 * The identifier of the modal message.
 */
@property (nonatomic, strong) NSString *messageID;

/**
 * The flag indicating the state of the modal message.
 */
@property (nonatomic, assign) BOOL isShowing;

/**
 * The modal message's media.
 */
@property (nonatomic, strong) UIImage *image;

/**
 * The modal display content.
 */
@property (nonatomic, strong) UAInAppMessageModalDisplayContent *displayContent;

/**
 * The completion handler passed in when the message is shown.
 */
@property (nonatomic, copy, nullable) void (^showCompletionHandler)(void);

@end

@implementation UAInAppMessageModalViewController

@dynamic view;

+ (instancetype)modalControllerWithModalMessageID:(NSString *)messageID
                                             displayContent:(UAInAppMessageModalDisplayContent *)displayContent
                                                      image:(UIImage *_Nullable)image {
    
    return [[self alloc] initWithModalMessageID:messageID
                                      displayContent:displayContent
                                               image:image];
}

- (instancetype)initWithModalMessageID:(NSString *)messageID
                             displayContent:(UAInAppMessageModalDisplayContent *)displayContent
                                      image:(UIImage *_Nullable)image {
    self = [self initWithNibName:@"UAInAppMessageModalViewController" bundle:[UAirship resources]];

    if (self) {
        self.messageID = messageID;
        self.displayContent = displayContent;
        self.image = image;
    }
    
    return self;
}

#pragma mark -
#pragma mark Core Functionality

- (void)show:(void (^)(void))completionHandler  {
    if (self.isShowing) {
        UA_LWARN(@"In-app message modal has already been displayed");
        completionHandler();
    }
    
    self.showCompletionHandler = completionHandler;
    
    // create a new window that covers the entire display
    self.modalWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    
    // make sure window appears above any alerts already showing
    self.modalWindow.windowLevel = UIWindowLevelAlert;

    // add this view controller to the window
    self.modalWindow.rootViewController = self;

    // show the window
    [self.modalWindow makeKeyAndVisible];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // set up scrollView so it can shrink when content is smaller than view
    self.scrollView.modalView = self.modalView;
    self.scrollView.contentView = self.contentView;
    self.scrollView.modalViewMaxHeightConstraint = self.modalViewMaxHeightConstraint;
    self.scrollView.modalViewActualHeightConstraint = self.modalViewActualHeightConstraint;
    
    self.modalView.borderRadius = self.displayContent.borderRadius;
    self.modalView.backgroundColor = self.displayContent.backgroundColor;
    
    self.closeButton.dismissButtonColor = self.displayContent.dismissButtonColor;

    // figure out which views go where based on contentLayout
    UIView *containerForHeaderView;
    UIView *containerForMediaView;
    UIView *containerForBodyView;
    switch (self.displayContent.contentLayout) {
        case UAInAppMessageModalContentLayoutHeaderMediaBody:
            containerForHeaderView = self.scrollTopView;
            containerForMediaView = self.scrollMiddleView;
            containerForBodyView = self.scrollBottomView;
            break;
        case UAInAppMessageModalContentLayoutHeaderBodyMedia:
            containerForHeaderView = self.scrollTopView;
            containerForBodyView = self.scrollMiddleView;
            containerForMediaView = self.scrollBottomView;
            break;
        case UAInAppMessageModalContentLayoutMediaHeaderBody:
            containerForMediaView = self.scrollTopView;
            containerForHeaderView = self.scrollMiddleView;
            containerForBodyView = self.scrollBottomView;
            break;
    }
    
    // Only create header view if header is present
    UIView *headerView;
    if (self.displayContent.heading) {
        headerView = [UAInAppMessageTextView textViewWithHeading:self.displayContent.heading body:nil];
        
        [containerForHeaderView addSubview:headerView];
        [UAInAppMessageUtils applyContainerConstraintsToContainer:containerForHeaderView containedView:headerView];
    }
    
    // Only create image view if image is present
    UIImageView *imageView;
    if (self.image) {
        imageView = [[UIImageView alloc] initWithImage:self.image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        [containerForMediaView addSubview:imageView];
        [UAInAppMessageUtils applyContainerConstraintsToContainer:containerForMediaView containedView:imageView];
    }
 
    // Only create body view if body is present
    UIView *bodyView;
    if (self.displayContent.body) {
        bodyView = [UAInAppMessageTextView textViewWithHeading:nil body:self.displayContent.body];
        
        [containerForBodyView addSubview:bodyView];
        [UAInAppMessageUtils applyContainerConstraintsToContainer:containerForBodyView containedView:bodyView];
    }
    
    // Only create button view if there are buttons
    if (self.displayContent.buttons.count) {
        UAInAppMessageButtonView *buttonView = [UAInAppMessageButtonView buttonViewWithButtons:self.displayContent.buttons
                                                                                        layout:self.displayContent.buttonLayout
                                                                                        target:self
                                                                                      selector:@selector(buttonTapped:)];

        if (buttonView) {
            [self.buttonContainerView addSubview:buttonView];
            [UAInAppMessageUtils applyContainerConstraintsToContainer:self.buttonContainerView containedView:buttonView];
        } else {
            self.buttonContainerView = nil;
        }
    }
    
    // footer view
    UAInAppMessageButton *footerButton = [self createFooterButtonWithButtonInfo:self.displayContent.footer];
    if (footerButton) {
        // footer
        if (footerButton) {
            [self.footerContainerView addSubview:footerButton];
            [UAInAppMessageUtils applyContainerConstraintsToContainer:self.footerContainerView containedView:footerButton];
        } else {
            self.footerContainerView = nil;
        }
    }
    
    // will make opaque as part of animation when view appears
    self.view.alpha = 0;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    // before the view changes size (rotates), restore the old constraints. Once view has changed sized,
    // the new constraints will be recalculated in [UAInAppMessageModalScrollView layoutSubviews].
    self.modalViewActualHeightConstraint.active = NO;
    self.modalViewMaxHeightConstraint.active = YES;

    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // fade in modal message view
    if (self.view.alpha == 0) {
        UA_WEAKIFY(self);
        [UIView animateWithDuration:DefaultModalAnimationDuration animations:^{
            self.view.alpha = 1;
 
            // TBD - iOS modal animation seems to start with the modal a bit bigger than the final size and shrinks it as it fades in

            [self.view setNeedsLayout];
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            UA_STRONGIFY(self);
            self.isShowing = YES;
        }];
    }
}

- (UAInAppMessageButton * _Nullable)createFooterButtonWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
    if (!buttonInfo) {
        return nil;
    }
    
    UAInAppMessageButton *footerButton = [UAInAppMessageButton footerButtonWithButtonInfo:buttonInfo];
    
    [footerButton addTarget:self
                     action:@selector(buttonTapped:)
           forControlEvents:UIControlEventTouchUpInside];
    
    return footerButton;
}

- (void)dismiss  {
    if (self.showCompletionHandler) {
        self.showCompletionHandler();
        self.showCompletionHandler = nil;
    }
    
    // fade out modal message view
    UA_WEAKIFY(self);
    [UIView animateWithDuration:DefaultModalAnimationDuration animations:^{
        self.view.alpha = 0;
        
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        UA_STRONGIFY(self);
        // teardown
        self.isShowing = NO;
        [self.view removeFromSuperview];
        self.modalWindow = nil;
    }];
}

- (IBAction)buttonTapped:(id)sender {
    // Check for close button
    if ([sender isKindOfClass:[UAInAppMessageCloseButton class]]) {
        [self dismiss];
        return;
    }
    
    UAInAppMessageButton *button = (UAInAppMessageButton *)sender;
    
    // Check button behavior
    if (button.buttonInfo.behavior == UAInAppMessageButtonInfoBehaviorCancel) {
        // TODO: Cancel based on schedule ID not Message ID.
        [[UAirship inAppMessageManager] cancelMessagesWithID:self.messageID];
    }
    
    [self dismiss];
}

@end

NS_ASSUME_NONNULL_END
