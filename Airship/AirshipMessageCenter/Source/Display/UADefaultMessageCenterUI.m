/* Copyright Airship and Contributors */

#import "UADefaultMessageCenterUI.h"
#import "UAMessageCenter.h"
#import "UAMessageCenterLocalization.h"
#import "UADefaultMessageCenterListViewController.h"
#import "UADefaultMessageCenterSplitViewController.h"
#import "UAMessageCenterStyle.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
#import "UAAirshipMessageCenterCoreImport.h"

@interface UADefaultMessageCenterUI()
@property(nonatomic, strong) UADefaultMessageCenterSplitViewController *splitViewController;
@property(nonatomic, strong) UIWindow *messageCenterWindow;
@end

@implementation UADefaultMessageCenterUI

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = UAMessageCenterLocalizedString(@"ua_message_center_title");
    }
    return self;
}

- (void)setFilter:(NSPredicate *)filter {
    _filter = filter;
    self.splitViewController.filter = filter;
}

- (void)setDisableMessageLinkPreviewAndCallouts:(BOOL)disableMessageLinkPreviewAndCallouts {
    _disableMessageLinkPreviewAndCallouts = disableMessageLinkPreviewAndCallouts;
    self.splitViewController.disableMessageLinkPreviewAndCallouts = disableMessageLinkPreviewAndCallouts;
}

- (void)setMessageCenterStyle:(UAMessageCenterStyle *)style {
    _messageCenterStyle = style;
    self.splitViewController.messageCenterStyle = style;
}

#if !defined(__IPHONE_14_0)
- (void)setStyle:(UAMessageCenterStyle *)style {
    [self setMessageCenterStyle:style];
}
- (UAMessageCenterStyle *)style {
    return self.messageCenterStyle;
}
#endif

- (void)setTitle:(NSString *)title {
    _title = title;
    self.splitViewController.title = title;
}

- (void)createSplitViewController {
    self.splitViewController = [[UADefaultMessageCenterSplitViewController alloc] initWithNibName:nil bundle:nil];

    self.splitViewController.filter = self.filter;
    self.splitViewController.disableMessageLinkPreviewAndCallouts = self.disableMessageLinkPreviewAndCallouts;

    self.splitViewController.messageCenterStyle = self.messageCenterStyle;
    self.splitViewController.title = self.title;

    self.splitViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    self.splitViewController.modalPresentationStyle = UIModalPresentationFullScreen;

    UADefaultMessageCenterListViewController *lvc = self.splitViewController.listViewController;

    // if "Done" has been localized, use it, otherwise use iOS's UIBarButtonSystemItemDone
    if (UAMessageCenterLocalizedStringExists(@"ua_done")) {
        lvc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_done")
                                                                                style:UIBarButtonItemStyleDone
                                                                               target:self
                                                                               action:@selector(dismiss)];
    } else {
        lvc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                             target:self
                                                                                             action:@selector(dismiss)];
    }
}

- (void)displayMessageCenterAnimated:(BOOL)animated
                          completion:(void(^)(void))completionHandler {
    if (!self.splitViewController) {
        [self createSplitViewController];
        
        self.messageCenterWindow = [UAUtils presentInNewWindow:self.splitViewController];
    } else {
        if (completionHandler) {
            completionHandler();
        }
    }
}

- (void)displayMessageCenterAnimated:(BOOL)animated {
    [self displayMessageCenterAnimated:animated completion:nil];
}

- (void)displayMessageCenterForMessageID:(NSString *)messageID animated:(BOOL)animated {
    UA_WEAKIFY(self)
    [self displayMessageCenterAnimated:animated completion:^{
        UA_STRONGIFY(self)
        [self.splitViewController displayMessageForID:messageID];
    }];
}

- (void)dismissMessageCenterAnimated:(BOOL)animated {
    [self.splitViewController.presentingViewController dismissViewControllerAnimated:animated completion:nil];
    self.splitViewController = nil;
    self.messageCenterWindow = nil;
}

- (void)dismiss {
    [self dismissMessageCenterAnimated:YES];
}

@end
