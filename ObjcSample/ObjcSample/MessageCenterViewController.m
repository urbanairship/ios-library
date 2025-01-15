/* Copyright Airship and Contributors */

#import "MessageCenterViewController.h"
@import AirshipObjectiveC;

@implementation MessageCenterViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIView *messageCenterView = [UAMessageCenterViewControllerFactory
                                 embedWithTheme:nil
                                 predicate:nil
                                 in:self];
    messageCenterView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:messageCenterView];

    [NSLayoutConstraint activateConstraints:@[
        [messageCenterView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [messageCenterView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [messageCenterView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [messageCenterView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

@end
