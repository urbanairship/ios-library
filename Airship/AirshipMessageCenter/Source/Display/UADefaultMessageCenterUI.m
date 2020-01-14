/* Copyright Airship and Contributors */

#import "UADefaultMessageCenterUI.h"
#import "UAMessageCenter.h"
#import "UAMessageCenterLocalization.h"
#import "UADefaultMessageCenterListViewController.h"
#import "UADefaultMessageCenterMessageViewController.h"
#import "UADefaultMessageCenterSplitViewController.h"
#import "UADefaultMessageCenterSplitViewDelegate.h"
#import "UAMessageCenterStyle.h"

#import "UAAirshipMessageCenterCoreImport.h"

@interface UADefaultMessageCenterUI()
@property(nonatomic, strong) UADefaultMessageCenterSplitViewController *splitViewController;
@property(nonatomic, strong) UADefaultMessageCenterSplitViewDelegate *splitViewDelegate;
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

- (void)setStyle:(UAMessageCenterStyle *)style {
    _style = style;
    self.splitViewController.style = style;
}

- (void)setTitle:(NSString *)title {
    _title = title;
    self.splitViewController.title = title;
}

- (void)displayMessageCenterAnimated:(BOOL)animated
                          completion:(void(^)(void))completionHandler {
    if (!self.splitViewController) {
        self.splitViewController = [[UADefaultMessageCenterSplitViewController alloc] initWithNibName:nil bundle:nil];
        
        self.splitViewController.filter = self.filter;
        self.splitViewController.disableMessageLinkPreviewAndCallouts = self.disableMessageLinkPreviewAndCallouts;

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

        self.splitViewController.style = self.style;
        self.splitViewController.title = self.title;

        self.splitViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.splitViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    }

    if (!self.splitViewController.presentingViewController) {
        [[UAUtils topController] presentViewController:self.splitViewController animated:animated completion:completionHandler];
    } else {
        completionHandler();
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
}

- (void)dismiss {
    [self dismissMessageCenterAnimated:YES];
}

#pragma mark -
#pragma mark UAMessageCenterMessagePresentationDelegate

- (void)presentMessage:(UAInboxMessage *)message {

}

@end
