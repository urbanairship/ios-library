/* Copyright Airship and Contributors */

#import "UADefaultMessageCenterSplitViewController.h"
#import "UADefaultMessageCenterListViewController.h"
#import "UADefaultMessageCenterMessageViewController.h"
#import "UAMessageCenter.h"
#import "UAMessageCenterStyle.h"
#import "UAMessageCenterLocalization.h"
#import "UAInboxMessage.h"
#import "UAMessageCenterResources.h"
#import "UADefaultMessageCenterSplitViewDelegate.h"
#import "UAInboxMessageList.h"
#import "UAAirshipMessageCenterCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface UADefaultMessageCenterSplitViewController ()

@property (nonatomic, strong) UADefaultMessageCenterListViewController *listViewController;
@property (nonatomic, strong) UADefaultMessageCenterMessageViewController *messageViewController;
@property (nonatomic, strong) UINavigationController *listNavigationController;
@property (nonatomic, strong) UINavigationController *messageNavigationController;
@property (nonatomic, strong) UADefaultMessageCenterSplitViewDelegate *defaultSplitViewDelegate;
@property (nonatomic, assign) BOOL visible;
@property (nonatomic, copy, nullable) NSString *deferredMessageID;
@property (nonatomic, copy, nullable) NSString *pendingMessageID;

/**
 * The previous navigation bar style. Used for resetting the bar style to the style set before message center display.
 * Note: 0 for default Bar style, 1 for black bar style.
 */
@property (nonatomic, strong, nullable) NSNumber *previousNavigationBarStyle;

@end

@implementation UADefaultMessageCenterSplitViewController

- (void)configure {
    self.listViewController = [[UADefaultMessageCenterListViewController alloc] initWithNibName:@"UADefaultMessageCenterListViewController"
                                                                                         bundle:[UAMessageCenterResources bundle]];

    self.listNavigationController = [[UINavigationController alloc] initWithRootViewController:self.listViewController];
    self.viewControllers = @[self.listNavigationController];
    
    self.title = UAMessageCenterLocalizedString(@"ua_message_center_title");

    self.listViewController.delegate = self;

    self.defaultSplitViewDelegate = [[UADefaultMessageCenterSplitViewDelegate alloc] initWithListViewController:self.listViewController];
    self.delegate = self.defaultSplitViewDelegate;
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) {
        [self configure];
    }

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];

    if (self) {
        [self configure];
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.messageViewController = [[UADefaultMessageCenterMessageViewController alloc] initWithNibName:@"UADefaultMessageCenterMessageViewController"
                                                                                               bundle:[UAMessageCenterResources bundle]];
    self.messageViewController.disableMessageLinkPreviewAndCallouts = self.disableMessageLinkPreviewAndCallouts;
    self.messageViewController.delegate = self;

    self.messageNavigationController = [[UINavigationController alloc] initWithRootViewController:self.messageViewController];
    self.viewControllers = @[self.listNavigationController,self.messageNavigationController];
    
    // display both view controllers in horizontally regular contexts
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    
    if (self.messageCenterStyle) {
        [self applyStyle];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self setNavigationBarStyle];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self restoreNavigationBarStyle];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super  viewDidDisappear:animated];
    self.visible = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    self.visible = YES;
    
    if (self.deferredMessageID) {
        [self presentMessage:self.deferredMessageID];
        self.deferredMessageID = nil;
    }
}

- (void)setMessageCenterStyle:(UAMessageCenterStyle *)style {
    _messageCenterStyle = style;
    self.listViewController.messageCenterStyle = style;

    [self applyStyle];
}

#if !defined(__IPHONE_14_0)
- (void)setStyle:(UAMessageCenterStyle *)style {
    [self setMessageCenterStyle:style];
}
- (UAMessageCenterStyle *)style {
    return self.messageCenterStyle;
}
#endif

- (void)applyStyle {
    if (self.messageCenterStyle.navigationBarColor) {
        self.listNavigationController.navigationBar.barTintColor = self.messageCenterStyle.navigationBarColor;
        self.messageNavigationController.navigationBar.barTintColor = self.messageCenterStyle.navigationBarColor;
    }

    // Only apply opaque property if a style is set
    if (self.messageCenterStyle) {
        self.listNavigationController.navigationBar.translucent = !self.messageCenterStyle.navigationBarOpaque;
        self.messageNavigationController.navigationBar.translucent = !self.messageCenterStyle.navigationBarOpaque;
    }

    NSMutableDictionary *titleAttributes = [NSMutableDictionary dictionary];

    if (self.messageCenterStyle.titleColor) {
        titleAttributes[NSForegroundColorAttributeName] = self.messageCenterStyle.titleColor;
    }

    if (self.messageCenterStyle.titleFont) {
        titleAttributes[NSFontAttributeName] = self.messageCenterStyle.titleFont;
    }

    if (titleAttributes.count) {
        self.listNavigationController.navigationBar.titleTextAttributes = titleAttributes;
        self.messageNavigationController.navigationBar.titleTextAttributes = titleAttributes;
    }

    if (self.messageCenterStyle.tintColor) {
        self.view.tintColor = self.messageCenterStyle.tintColor;
        self.messageNavigationController.navigationBar.tintColor = self.messageCenterStyle.tintColor;
    }
        
    if (@available(iOS 13, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        if (self.messageCenterStyle && self.messageCenterStyle.navigationBarOpaque) {
            [appearance configureWithOpaqueBackground];
        }
        if (self.messageCenterStyle.navigationBarColor) {
            appearance.backgroundColor = self.messageCenterStyle.navigationBarColor;
        }
        if (titleAttributes.count) {
            appearance.titleTextAttributes = titleAttributes;
        }
        self.messageNavigationController.navigationBar.standardAppearance = appearance;
        self.messageNavigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.listNavigationController.navigationBar.standardAppearance = appearance;
        self.listNavigationController.navigationBar.scrollEdgeAppearance = appearance;
    }

    [self setNavigationBarStyle];
}

- (void)setFilter:(NSPredicate *)filter {
    _filter = filter;
    self.listViewController.filter = filter;
}

- (void)setTitle:(nullable NSString *)title {
    [super setTitle:title];
    self.listViewController.title = title;
}

- (void)setDisableMessageLinkPreviewAndCallouts:(BOOL)disableMessageLinkPreviewAndCallouts {
    _disableMessageLinkPreviewAndCallouts = disableMessageLinkPreviewAndCallouts;
    self.messageViewController.disableMessageLinkPreviewAndCallouts = disableMessageLinkPreviewAndCallouts;
}

- (void)restoreNavigationBarStyle {
    // Restore the previous navigation bar style to the containing navigation controller
    if (self.messageCenterStyle && self.messageCenterStyle.navigationBarStyle && self.previousNavigationBarStyle) {
        self.navigationController.navigationBar.barStyle = (UIBarStyle)[self.previousNavigationBarStyle intValue];
    }

    self.previousNavigationBarStyle = nil;
}

// Note: This method should only be called once in viewWillAppear or it may not function as expected
- (void)setNavigationBarStyle {
    if (self.messageCenterStyle && self.messageCenterStyle.navigationBarStyle) {
        // Save the previous style of containing navigation controller, and set specified style
        if (!self.previousNavigationBarStyle) {
            // Only set once to prevent overwriting from multiple calls
            self.previousNavigationBarStyle = @(self.navigationController.navigationBar.barStyle);
        }

        self.listNavigationController.navigationBar.barStyle = (UIBarStyle)self.messageCenterStyle.navigationBarStyle;
        self.messageNavigationController.navigationBar.barStyle = (UIBarStyle)self.messageCenterStyle.navigationBarStyle;
    }
}

- (void)displayMessageForID:(NSString *)messageID {
    // If this message ID is not already in the message list, set it as pending
    if (![[UAMessageCenter shared].messageList messageForID:messageID]) {
        self.pendingMessageID = messageID;
    }

    // If already visible, go ahead and present it
    if (self.visible) {
        [self presentMessage:messageID];
    } else {
        // otherwise defer presentation until
        self.deferredMessageID = messageID;
    }
}

- (void)presentMessage:(NSString *)messageID {
    // If the message view controller is not already visible, make it visible
    if (![self.listNavigationController.visibleViewController isEqual:self.messageViewController]) {
        [self showDetailViewController:self.messageNavigationController sender:self];
    }

    if (!self.pendingMessageID) {
        self.listViewController.selectedMessageID = messageID;
    }

    [self.messageViewController loadMessageForID:messageID];
}

- (void)dismissMessage {
    [self.messageViewController clearMessage];

    // Hide message view if necessary
    if (self.collapsed && [self.listNavigationController.visibleViewController isEqual:self.messageViewController]) {
        [self.listNavigationController popViewControllerAnimated:YES];
    }
}

#pragma mark UAMessageCenterListViewDelegate

- (BOOL)shouldClearSelectionOnViewWillAppear {
    return self.collapsed;
}

- (void)didSelectMessageWithID:(nullable NSString *)messageID {
    if (messageID) {
        [self presentMessage:messageID];
    } else if (!self.pendingMessageID) {
        [self dismissMessage];
    }
}

#pragma mark UAMessageCenterMessageViewDelegate

- (void)displayNoLongerAvailableAlertOnOK:(void (^)(void))okCompletion {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_content_error")
                                                                   message:UAMessageCenterLocalizedString(@"ua_mc_no_longer_available")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (okCompletion) {
                                                                  okCompletion();
                                                              }
                                                          }];

    [alert addAction:defaultAction];

    [self presentViewController:alert animated:YES completion:nil];

}

- (void)displayFailedToLoadAlertOnOK:(void (^)(void))okCompletion onRetry:(nullable void (^)(void))retryCompletion {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_connection_error")
                                                                   message:UAMessageCenterLocalizedString(@"ua_mc_failed_to_load")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (okCompletion) {
                                                                  okCompletion();
                                                              }
                                                          }];

    [alert addAction:defaultAction];

    if (retryCompletion) {
        UIAlertAction *retryAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_retry_button")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
                                                                if (retryCompletion) {
                                                                    retryCompletion();
                                                                }
                                                            }];

        [alert addAction:retryAction];
    }

    [self presentViewController:alert animated:YES completion:nil];
}


- (void)messageLoadStarted:(NSString *)messageID {
    UA_LTRACE(@"message load started: %@", messageID);
}

- (void)messageLoadSucceeded:(NSString *)messageID {
    UA_LTRACE(@"message load succeeded: %@", messageID);

    self.listViewController.selectedMessageID = messageID;

    if ([messageID isEqualToString:self.pendingMessageID]) {
        self.pendingMessageID = nil;
    }
}

- (void)messageLoadFailed:(NSString *)messageID error:(NSError *)error {
    UA_LTRACE(@"message load failed: %@", messageID);

    void (^retry)(void) = ^{
        UA_WEAKIFY(self);
        [self displayFailedToLoadAlertOnOK:^{
            [self resetUIState];
        } onRetry:^{
            UA_STRONGIFY(self);
            [self displayMessageForID:messageID];
        }];
    };

    void (^handleFailed)(void) = ^{
        UA_WEAKIFY(self);
        [self displayFailedToLoadAlertOnOK:^{
            UA_STRONGIFY(self);
            [self resetUIState];
        } onRetry:nil];
    };

    void (^handleExpired)(void) = ^{
        UA_WEAKIFY(self);
        [self displayNoLongerAvailableAlertOnOK:^{
            UA_STRONGIFY(self)
            [self resetUIState];
        }];
    };

    if ([error.domain isEqualToString:UAMessageCenterMessageLoadErrorDomain]) {
        if (error.code == UAMessageCenterMessageLoadErrorCodeFailureStatus) {
            // Encountered a failure status code
            NSUInteger status = [error.userInfo[UAMessageCenterMessageLoadErrorHTTPStatusKey] unsignedIntValue];
            
            if (status >= 500) {
                retry();
            } else if (status == 410) {
                // Gone: message has been permanently deleted from the backend.
                handleExpired();
            } else {
                handleFailed();
            }
        } else if (error.code == UAMessageCenterMessageLoadErrorCodeMessageExpired) {
            handleExpired();
        } else {
            retry();
        }
    } else {
        // Other errors
        retry();
    }
}

- (void)resetUIState {
    // Deselect message
    self.listViewController.selectedMessageID = nil;

    // Hide message view if necessary
    if (self.collapsed && [self.listNavigationController.visibleViewController isEqual:self.messageViewController]) {
        [self.listNavigationController popViewControllerAnimated:YES];
    }
}

- (void)refreshMessageList {
    // refresh message list
    [[UAMessageCenter shared].messageList retrieveMessageListWithSuccessBlock:nil
                                                             withFailureBlock:nil];
}

- (void)messageClosed:(NSString *)messageID {
    UA_LTRACE(@"message closed: %@", messageID);
    [self dismissMessage];
}

@end

NS_ASSUME_NONNULL_END
