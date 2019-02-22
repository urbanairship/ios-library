/* Copyright Urban Airship and Contributors */

#import "UAMessageCenter.h"
#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAUtils+Internal.h"
#import "UAMessageCenterLocalization.h"
#import "UAMessageCenterListViewController.h"
#import "UAMessageCenterMessageViewController.h"
#import "UAMessageCenterSplitViewController.h"
#import "UAMessageCenterStyle.h"
#import "UAConfig.h"

@interface UAMessageCenter()
@property(nonatomic, strong) UAMessageCenterSplitViewController *splitViewController;
@end

@implementation UAMessageCenter

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = UAMessageCenterLocalizedString(@"ua_message_center_title");
    }
    return self;
}

+ (instancetype)messageCenterWithConfig:(UAConfig *)config {
    UAMessageCenter *center = [[UAMessageCenter alloc] init];
    center.style = [UAMessageCenterStyle styleWithContentsOfFile:config.messageCenterStyleConfig];
    return center;
}

- (void)display:(BOOL)animated completion:(void(^)(void))completionHandler {
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

- (void)display:(BOOL)animated {
    [self display:animated completion:nil];
}

- (void)display {
    [self display:YES];
}

- (void)displayMessageForID:(NSString *)messageID animated:(BOOL)animated {
    UA_WEAKIFY(self)
    [self display:animated completion:^{
        UA_STRONGIFY(self)
        [self.splitViewController.listViewController displayMessageForID:messageID];
    }];
}

- (void)displayMessageForID:(NSString *)messageID {
    [self displayMessageForID:messageID animated:NO];
}

- (void)dismiss:(BOOL)animated {
    [self.splitViewController.presentingViewController dismissViewControllerAnimated:animated completion:nil];
    self.splitViewController = nil;
}

- (void)dismiss {
    [self dismiss:YES];
}

@end
