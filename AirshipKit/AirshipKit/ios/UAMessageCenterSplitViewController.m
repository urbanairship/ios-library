/* Copyright Urban Airship and Contributors */

#import "UAMessageCenterSplitViewController.h"
#import "UAMessageCenterListViewController.h"
#import "UAMessageCenterMessageViewController.h"
#import "UAMessageCenter.h"
#import "UAMessageCenterStyle.h"
#import "UAirship.h"
#import "UAMessageCenterLocalization.h"
#import "UAConfig.h"
#import "UAInboxMessage.h"

@interface UAMessageCenterSplitViewController ()

@property (nonatomic, strong) UAMessageCenterListViewController *listViewController;
@property (nonatomic, strong) UIViewController<UAMessageCenterMessageViewProtocol> *messageViewController;
@property (nonatomic, strong) UINavigationController *listNav;
@property (nonatomic, strong) UINavigationController *messageNav;
@property (nonatomic, assign) BOOL showMessageViewOnViewDidAppear;

@end

@implementation UAMessageCenterSplitViewController

- (void)configure {

    self.listViewController = [[UAMessageCenterListViewController alloc] initWithNibName:@"UAMessageCenterListViewController"
                                                                                  bundle:[UAirship resources]
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
                                                                                            bundle:[UAirship resources]];
        self.listViewController.messageViewController = self.messageViewController;
        self.showMessageViewOnViewDidAppear = NO;
    }

    self.messageNav = [[UINavigationController alloc] initWithRootViewController:self.messageViewController];
    self.viewControllers = @[self.listNav,self.messageNav];
    
    // display both view controllers in horizontally regular contexts
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    
    if (self.style) {
        [self applyStyle];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.showMessageViewOnViewDidAppear) {
        self.showMessageViewOnViewDidAppear = NO;
        if (self.collapsed) {
            [self.listViewController displayMessageForID:self.messageViewController.message.messageID];
        }
    }
}

- (void)setStyle:(UAMessageCenterStyle *)style {
    _style = style;
    self.listViewController.style = style;

    if (self.listNav && self.messageNav) {
        [self applyStyle];
    }
}

- (void)applyStyle {
    if (self.style.navigationBarColor) {
        self.listNav.navigationBar.barTintColor = self.style.navigationBarColor;
        self.messageNav.navigationBar.barTintColor = self.style.navigationBarColor;
    }

    // Only apply opaque property if a style is set
    if (self.style) {
        self.listNav.navigationBar.translucent = !self.style.navigationBarOpaque;
        self.messageNav.navigationBar.translucent = !self.style.navigationBarOpaque;
    }

    NSMutableDictionary *titleAttributes = [NSMutableDictionary dictionary];

    if (self.style.titleColor) {
        titleAttributes[NSForegroundColorAttributeName] = self.style.titleColor;
    }

    if (self.style.titleFont) {
        titleAttributes[NSFontAttributeName] = self.style.titleFont;
    }

    if (titleAttributes.count) {
        self.listNav.navigationBar.titleTextAttributes = titleAttributes;
        self.messageNav.navigationBar.titleTextAttributes = titleAttributes;
    }

    if (self.style.tintColor) {
        self.view.tintColor = self.style.tintColor;
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
