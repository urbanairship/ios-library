/* Copyright Airship and Contributors */

#import "UADefaultMessageCenterUI.h"
#import "UAMessageCenter.h"
#import "UAUtils.h"
#import "UAMessageCenterLocalization.h"
#import "UAMessageCenterListViewController.h"
#import "UAMessageCenterMessageViewController.h"
#import "UAMessageCenterSplitViewController.h"
#import "UAMessageCenterStyle.h"

@interface UADefaultMessageCenterUI()
@property(nonatomic, strong) UAMessageCenterSplitViewController *splitViewController;
@end

@implementation UADefaultMessageCenterUI

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = UAMessageCenterLocalizedString(@"ua_message_center_title");
    }
    return self;
}

- (void)displayMessageCenterAnimated:(BOOL)animated
                          completion:(void(^)(void))completionHandler {
    if (!self.splitViewController) {
        self.splitViewController = [[UAMessageCenterSplitViewController alloc] initWithNibName:nil bundle:nil];
        self.splitViewController.filter = self.filter;

        UAMessageCenterListViewController *lvc = self.splitViewController.listViewController;

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

        [[UAUtils topController] presentViewController:self.splitViewController animated:animated completion:completionHandler];
    }
}

- (void)displayMessageCenterAnimated:(BOOL)animated {
    [self displayMessageCenterAnimated:animated completion:nil];
}

- (void)displayMessageCenterForMessageID:(NSString *)messageID animated:(BOOL)animated {
    UA_WEAKIFY(self)
    [self displayMessageCenterAnimated:animated completion:^{
        UA_STRONGIFY(self)
        [self.splitViewController.listViewController displayMessageForID:messageID];
    }];
}

- (void)dismissMessageCenterAnimated:(BOOL)animated {
    [self.splitViewController.presentingViewController dismissViewControllerAnimated:animated completion:nil];
    self.splitViewController = nil;
}

@end
