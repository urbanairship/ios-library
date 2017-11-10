/* Copyright 2017 Urban Airship and Contributors */

@import AirshipKit;
#import "HomeViewController.h"

@interface HomeViewController ()

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshView) name:@"channelIDUpdated" object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self refreshView];
}

- (IBAction)buttonTapped:(id)sender {
    if (sender == self.enablePushButton) {
        [UAirship push].userPushNotificationsEnabled = YES;
    }

    if (sender == self.channelIDButton && [UAirship push].channelID) {
        [UIPasteboard generalPasteboard].string = [UAirship push].channelID;
        UALegacyInAppMessage *message = [[UALegacyInAppMessage alloc] init];
        message.alert = NSLocalizedStringFromTable(@"UA_Copied_To_Clipboard", @"UAPushUI", @"Copied to clipboard string");
        message.position = UAInAppMessagePositionTop;
        message.duration = 1.5;
        message.primaryColor = [UIColor colorWithRed:255/255.f green:200/255.f blue:40/255.f alpha:1];
        message.secondaryColor = [UIColor colorWithRed:0/255.f green:105/255.f blue:143/255.f alpha:1];
        [[UAirship inAppMessaging] displayMessage:message];
    }
}

- (void)refreshView {
    if ([UAirship push].userPushNotificationsEnabled) {
        [self.channelIDButton setTitle:[UAirship push].channelID forState:UIControlStateNormal];
        self.channelIDButton.hidden = NO;
        self.enablePushButton.hidden = YES;
        return;
    }
    self.channelIDButton.hidden = YES;
    self.enablePushButton.hidden = NO;
}

@end
