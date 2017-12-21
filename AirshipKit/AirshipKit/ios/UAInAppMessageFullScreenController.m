/* Copyright 2017 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAUtils.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageFullScreenController+Internal.h"
#import "UAInAppMessageFullScreenView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageCloseButton+Internal.h"


NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageTextView;
@class UAInAppMessageButtonView;
@class UAInAppMessageMediaView;
@class UAInAppMessageFullScreenDisplayContent;

double const DefaultFullScreenAnimationDuration = 0.2;

@interface UAInAppMessageFullScreenController ()

/**
 * The identifier of the full screen message.
 */
@property (nonatomic, strong) NSString *messageID;

/**
 * The flag indicating the state of the full screen message.
 */
@property (nonatomic, assign) BOOL isShowing;

/**
 * The the full screen's media.
 */
@property (nonatomic, strong) UIImage *image;

/**
 * The full screen display content consisting of the text and image.
 */
@property (nonatomic, strong) UAInAppMessageFullScreenDisplayContent *displayContent;

/**
 * The full screen view. Contains text views, a button view and a footer.
 */
@property (nonatomic, strong) UAInAppMessageFullScreenView *fullScreenView;

/**
 * Vertical constraint is used to vertically position the message.
 */
@property (nonatomic, strong) NSLayoutConstraint *verticalConstraint;

/**
 * The completion handler passed in when the message is shown.
 */
@property (nonatomic, copy, nullable) void (^showCompletionHandler)(void);

@end

@implementation UAInAppMessageFullScreenController

+ (instancetype)fullScreenControllerWithFullScreenMessageID:(NSString *)messageID
                                             displayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                                      image:(UIImage *_Nullable)image {

    return [[self alloc] initWithFullScreenMessageID:messageID
                                      displayContent:displayContent
                                               image:image];
}

- (instancetype)initWithFullScreenMessageID:(NSString *)messageID
                             displayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                      image:(UIImage *_Nullable)image {
    self = [super init];

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
        UA_LDEBUG(@"In-app message full screen has already been displayed");

        completionHandler();
    }

    UIView *parentView = [UAUtils mainWindow];

    if (!parentView) {
        UA_LDEBUG(@"Unable to find parent view, canceling in-app message full screen display");
        completionHandler();
    }

    self.showCompletionHandler = completionHandler;
    
    UAInAppMessageButtonView *buttonView = [UAInAppMessageButtonView buttonViewWithButtons:self.displayContent.buttons
                                                                                    layout:self.displayContent.buttonLayout
                                                                                    target:self
                                                                                  selector:@selector(buttonTapped:)
                                                                        dismissButtonColor:self.displayContent.dismissButtonColor];

    UAInAppMessageCloseButton *closeButton = [self addCloseButton];
    UAInAppMessageButton *footerButton = [self addFooterButtonWithButtonInfo:self.displayContent.footer];

    UIImageView *imageView = [[UIImageView alloc] initWithImage:self.image];

    self.fullScreenView = [UAInAppMessageFullScreenView fullScreenMessageViewWithDisplayContent:self.displayContent
                                                                                    closeButton:closeButton
                                                                                     buttonView:buttonView
                                                                                   footerButton:footerButton
                                                                                      imageView:imageView];

    [parentView addSubview:self.fullScreenView];
    [self addInitialConstraintsToParentView:parentView fullScreenView:self.fullScreenView];

    UA_WEAKIFY(self);
    [self fullScreenView:self.fullScreenView animateInWithParentView:parentView completionHandler:^{
        UA_STRONGIFY(self);
        self.isShowing = YES;
    }];
}

- (UAInAppMessageCloseButton * _Nullable)addCloseButton {

    UAInAppMessageCloseButton *closeButton = [[UAInAppMessageCloseButton alloc] init];
    [closeButton addTarget:self
                    action:@selector(buttonTapped:)
          forControlEvents:UIControlEventTouchUpInside];

    return closeButton;
}

- (UAInAppMessageButton * _Nullable)addFooterButtonWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
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

    [self beginTeardown];

    UA_WEAKIFY(self);
    dispatch_async(dispatch_get_main_queue(), ^{
        UA_STRONGIFY(self);
        [self fullScreenView:self.fullScreenView animateOutWithParentView:self.fullScreenView.superview completionHandler:^{
            UA_STRONGIFY(self);
            [self finishTeardown];
            self.isShowing = NO;
        }];
    });
}

- (void)buttonTapped:(id)sender {
    // Check for close button
    if ([sender isKindOfClass:[UAInAppMessageCloseButton class]]) {
        [self dismiss];
        return;
    }

    UAInAppMessageButton *button = (UAInAppMessageButton *)sender;

    // Check button behavior
    if (button.buttonInfo.behavior == UAInAppMessageButtonInfoBehaviorCancel) {
        // Cancel IAM schedule
        [[UAirship inAppMessageManager] cancelMessageWithID:self.messageID];
    }

    [self dismiss];
}

#pragma mark -
#pragma mark Autolayout and Animation

- (void)addInitialConstraintsToParentView:(UIView *)parentView
                           fullScreenView:(UAInAppMessageFullScreenView *)fullScreenView {

    self.verticalConstraint = [NSLayoutConstraint constraintWithItem:fullScreenView
                                                           attribute:NSLayoutAttributeBottom
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:parentView
                                                           attribute:NSLayoutAttributeBottom
                                                          multiplier:1
                                                            constant:fullScreenView.bounds.size.height];

    self.verticalConstraint.active = YES;

    // Center on X axis
    [NSLayoutConstraint constraintWithItem:fullScreenView
                                 attribute:NSLayoutAttributeCenterX
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeCenterX
                                multiplier:1
                                  constant:0].active = YES;


    // Set width
    [NSLayoutConstraint constraintWithItem:fullScreenView
                                 attribute:NSLayoutAttributeWidth
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeWidth
                                multiplier:1
                                  constant:0].active = YES;

    // Set height
    [NSLayoutConstraint constraintWithItem:fullScreenView
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeHeight
                                multiplier:1
                                  constant:0].active = YES;

    [parentView layoutIfNeeded];
    [fullScreenView layoutIfNeeded];
}

- (void)fullScreenView:(UAInAppMessageFullScreenView *)fullScreenView animateInWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    self.verticalConstraint.constant = 0;

    // Center on Y axis
    [NSLayoutConstraint constraintWithItem:fullScreenView
                                 attribute:NSLayoutAttributeCenterY
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeCenterY
                                multiplier:1
                                  constant:0].active = YES;

    // Set Height
    [NSLayoutConstraint constraintWithItem:fullScreenView
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeHeight
                                multiplier:1
                                  constant:0].active = YES;

    [UIView animateWithDuration:DefaultFullScreenAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [parentView layoutIfNeeded];
        [fullScreenView layoutIfNeeded];
    } completion:^(BOOL finished) {
        completionHandler();
    }];
}

- (void)fullScreenView:(UAInAppMessageFullScreenView *)fullScreenView animateOutWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    self.verticalConstraint.constant = fullScreenView.bounds.size.height;

    [UIView animateWithDuration:DefaultFullScreenAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [parentView layoutIfNeeded];
        [fullScreenView layoutIfNeeded];
    } completion:^(BOOL finished){
        completionHandler();
    }];
}

#pragma mark -
#pragma mark Teardown

/**
 * Releases all resources. This method can be safely called
 * in dealloc as a protection against unexpected early release.
 */
- (void)teardown {
    [self beginTeardown];
    [self finishTeardown];
}

/**
 * Prepares the message view for dismissal by disabling interaction, removing
 * the pan gesture recognizer and releasing resources that can be disposed of
 * prior to starting the dismissal animation.
 */
- (void)beginTeardown {
    self.fullScreenView.userInteractionEnabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 * Finalizes dismissal by removing the message view from its
 * parent, and releasing the reference to self
 */
- (void)finishTeardown {
    [self.fullScreenView removeFromSuperview];
}

- (void)dealloc {
    [self teardown];
}

@end

NS_ASSUME_NONNULL_END
