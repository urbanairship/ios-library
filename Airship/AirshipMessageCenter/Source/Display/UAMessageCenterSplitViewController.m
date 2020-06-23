/* Copyright Airship and Contributors */

#import "UAMessageCenterSplitViewController.h"
#import "UAMessageCenterListViewController.h"
#import "UAMessageCenterMessageViewController.h"
#import "UAMessageCenter.h"
#import "UAMessageCenterStyle.h"
#import "UAMessageCenterLocalization.h"
#import "UAInboxMessage.h"
#import "UAMessageCenterResources.h"

#import "UAAirshipMessageCenterCoreImport.h"

@interface UAMessageCenterSplitViewController ()

@property (nonatomic, strong) UAMessageCenterListViewController *listViewController;
@property (nonatomic, strong) UIViewController<UAMessageCenterMessageViewProtocol> *messageViewController;
@property (nonatomic, strong) UINavigationController *listNav;
@property (nonatomic, strong) UINavigationController *messageNav;
@property (nonatomic, assign) BOOL showMessageViewOnViewDidAppear;

@end

#pragma GCC diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation UAMessageCenterSplitViewController
#pragma GCC diagnostic pop

- (void)configure {

    self.listViewController = [[UAMessageCenterListViewController alloc] initWithNibName:@"UAMessageCenterListViewController"
                                                                                  bundle:[UAMessageCenterResources bundle]
                                                                     splitViewController:self];
    self.listNav = [[UINavigationController alloc] initWithRootViewController:self.listViewController];
    self.viewControllers = @[self.listNav];

    self.title = UAMessageCenterLocalizedString(@"ua_message_center_title");

    self.delegate = self.listViewController;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) {
        [self configure];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];

    if (self) {
        [self configure];
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.listViewController.messageViewController) {
        self.messageViewController = self.listViewController.messageViewController;
        self.showMessageViewOnViewDidAppear = YES;
    } else {
        self.messageViewController = [[UAMessageCenterMessageViewController alloc] initWithNibName:@"UAMessageCenterMessageViewController"
                                                                                            bundle:[UAMessageCenterResources bundle]];
        self.listViewController.messageViewController = self.messageViewController;
        self.showMessageViewOnViewDidAppear = NO;
    }

    self.messageNav = [[UINavigationController alloc] initWithRootViewController:self.messageViewController];
    self.viewControllers = @[self.listNav,self.messageNav];

    // display both view controllers in horizontally regular contexts
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;

    if (self.messageCenterStyle) {
        [self applyStyle];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.showMessageViewOnViewDidAppear) {
        self.showMessageViewOnViewDidAppear = NO;
        if (self.collapsed && self.messageViewController.message) {
            [self.listViewController displayMessageForID:self.messageViewController.message.messageID];
        }
    }
}

- (void)setMessageCenterStyle:(UAMessageCenterStyle *)style {
    _messageCenterStyle = style;
    self.listViewController.messageCenterStyle = style;

    if (self.listNav && self.messageNav) {
        [self applyStyle];
    }
}

- (void)applyStyle {
    if (self.messageCenterStyle.navigationBarColor) {
        self.listNav.navigationBar.barTintColor = self.messageCenterStyle.navigationBarColor;
        self.messageNav.navigationBar.barTintColor = self.messageCenterStyle.navigationBarColor;
    }

    // Only apply opaque property if a style is set
    if (self.messageCenterStyle) {
        self.listNav.navigationBar.translucent = !self.messageCenterStyle.navigationBarOpaque;
        self.messageNav.navigationBar.translucent = !self.messageCenterStyle.navigationBarOpaque;
    }

    NSMutableDictionary *titleAttributes = [NSMutableDictionary dictionary];

    if (self.messageCenterStyle.titleColor) {
        titleAttributes[NSForegroundColorAttributeName] = self.messageCenterStyle.titleColor;
    }

    if (self.messageCenterStyle.titleFont) {
        titleAttributes[NSFontAttributeName] = self.messageCenterStyle.titleFont;
    }

    if (titleAttributes.count) {
        self.listNav.navigationBar.titleTextAttributes = titleAttributes;
        self.messageNav.navigationBar.titleTextAttributes = titleAttributes;
    }

    if (self.messageCenterStyle.tintColor) {
        self.view.tintColor = self.messageCenterStyle.tintColor;
    }
}

- (void)setFilter:(NSPredicate *)filter {
    _filter = filter;
    self.listViewController.filter = filter;
}

- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    self.listViewController.title = title;
}

@end
