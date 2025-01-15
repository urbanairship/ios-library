/* Copyright Airship and Contributors */

#import "HomeViewController.h"
#import "HomeViewModel.h"

@import AirshipCore;
@import AirshipObjectiveC;

@interface HomeViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView  *verticalStack;
@property (nonatomic, strong) HomeViewModel *viewModel;

@property (nonatomic, strong) UIImageView *heroImageView;

@property (nonatomic, strong) UIButton *pushButton;

@property (nonatomic, strong) UIButton *channelIDButton;
@property (nonatomic, strong) UIButton *preferencesButton;

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.viewModel = [[HomeViewModel alloc] init];

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupScrollView];
    [self setupHero];
    [self setupPushButton];
    [self setupQuickSettings];
    [self layoutViews];

    [self refreshUI];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self refreshUI];
}

#pragma mark - UI Setup

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.verticalStack = [[UIStackView alloc] init];
    self.verticalStack.axis = UILayoutConstraintAxisVertical;
    self.verticalStack.spacing = 16.0;
    self.verticalStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.scrollView addSubview:self.verticalStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],

        [self.verticalStack.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:16],
        [self.verticalStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:16],
        [self.verticalStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-16],
        [self.verticalStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-16],
        [self.verticalStack.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-32]
    ]];
}

- (void)setupHero {
    self.heroImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"HomeHeroImage"]];
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFit;
}

- (void)setupPushButton {
    self.pushButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pushButton.layer.cornerRadius = 22.0;
    self.pushButton.layer.borderWidth = 2.0;
    self.pushButton.layer.borderColor = self.view.tintColor.CGColor;
    self.pushButton.clipsToBounds = YES;
    self.pushButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0];
    [self.pushButton addTarget:self
                        action:@selector(togglePushEnabled)
              forControlEvents:UIControlEventTouchUpInside];
}

- (void)setupQuickSettings {
    self.channelIDButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.channelIDButton setTitle:@"Channel ID: (Tap to Copy)" forState:UIControlStateNormal];
    self.channelIDButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.channelIDButton addTarget:self
                             action:@selector(copyChannelID)
                   forControlEvents:UIControlEventTouchUpInside];
}

- (void)layoutViews {
    [self.verticalStack addArrangedSubview:self.heroImageView];
    [self.verticalStack addArrangedSubview:self.channelIDButton];
    [self.verticalStack addArrangedSubview:self.pushButton];
}

#pragma mark - Actions

- (void)togglePushEnabled {
    [self.viewModel togglePushEnabled];
    [self refreshUI];
}

- (void)copyChannelID {
    [self.viewModel copyChannel];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:@"Channel copied to pasteboard"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)showPreferences {
    NSError *error = nil;
    UIView *preferencesView = [UAPreferenceCenterViewControllerFactory
                               embedWithPreferenceCenterID:@"MY_PREFERENCE_CENTER_ID"
                               preferenceCenterThemePlist:nil
                               in:self
                               error:&error];
    if (error) {
        NSLog(@"Error embedding preference center: %@", error);
        return;
    }

    UIViewController *vc = [[UIViewController alloc] init];
    [vc.view addSubview:preferencesView];
    preferencesView.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [preferencesView.topAnchor constraintEqualToAnchor:vc.view.topAnchor],
        [preferencesView.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor],
        [preferencesView.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor],
        [preferencesView.bottomAnchor constraintEqualToAnchor:vc.view.bottomAnchor]
    ]];

    vc.title = @"Preferences";

    if (self.navigationController) {
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        [self presentViewController:vc animated:YES completion:nil];
    }
}

#pragma mark - Helpers

- (UIView *)makeDivider {
    UIView *divider = [[UIView alloc] init];
    divider.backgroundColor = [UIColor separatorColor];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [divider.heightAnchor constraintEqualToConstant:1.0]
    ]];
    return divider;
}

- (void)refreshUI {
    NSString *title = self.viewModel.pushEnabled ? @"Disable Push" : @"Enable Push";
    [self.pushButton setTitle:title forState:UIControlStateNormal];

    NSString *chanText = self.viewModel.channelID ?: @"Unavailable";
    NSString *buttonTitle = [NSString stringWithFormat:@"Channel ID: %@", chanText];
    [self.channelIDButton setTitle:buttonTitle forState:UIControlStateNormal];
}

@end
