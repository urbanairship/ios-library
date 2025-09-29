/* Copyright Airship and Contributors */

#import "PreferenceCenterViewController.h"
@import AirshipObjectiveC;

@implementation PreferenceCenterViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSError *error = nil;
    UIView *preferenceCenterView = [UAPreferenceCenterViewControllerFactory
                                    embedWithPreferenceCenterID:@"app_default"
                                    preferenceCenterThemePlist:nil
                                    in:self
                                    error:&error];
    preferenceCenterView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:preferenceCenterView];

    [NSLayoutConstraint activateConstraints:@[
        [preferenceCenterView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [preferenceCenterView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [preferenceCenterView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [preferenceCenterView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];

    if (error) {
        NSLog(@"Error embedding preference center: %@", error);
    }
}

@end
