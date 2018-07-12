/* Copyright 2018 Urban Airship and Contributors */

@import AirshipKit;
#import "PushSettingsViewController.h"

@interface PushSettingsViewController ()

@end

@implementation PushSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshView) name:@"channelIDUpdated" object:nil];

    // Initialize switches
    self.locationEnabledSwitch.on = [UAirship location].locationUpdatesEnabled;
    self.analyticsSwitch.on = [UAirship analytics].enabled;

    // Add observer to didBecomeActive to update upon retrun from system settings screen
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:@"UIApplicationDidBecomeActiveNotification" object:nil];

    self.locationEnabledLabel.text = NSLocalizedStringFromTable(@"UA_Location_Enabled", @"UAPushUI", @"Location Enabled label");
    self.locationEnabledSubtitleLabel.text = NSLocalizedStringFromTable(@"UA_Location_Enabled_Detail", @"UAPushUI", @"Enable GPS and WIFI Based Location detail label");
}

- (void)didBecomeActive {
    [self refreshView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshView];
}

- (IBAction)switchValueChanged:(id)sender {

    // Only allow disabling user notifications on iOS 10+
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 0, 0}]) {
        [UAirship push].userPushNotificationsEnabled = self.pushEnabledSwitch.on;
    } else if (self.pushEnabledSwitch.on) {
        [UAirship push].userPushNotificationsEnabled = YES;
    }

    [UAirship location].locationUpdatesEnabled = self.locationEnabledSwitch.on;

    [UAirship analytics].enabled = self.analyticsSwitch.on;
}

- (void)refreshView {
    self.pushEnabledSwitch.on = [UAirship push].userPushNotificationsEnabled;

    self.channelIDSubtitleLabel.text = [UAirship push].channelID;

    self.namedUserSubtitleLabel.text = [UAirship namedUser].identifier == nil ? NSLocalizedStringFromTable(@"None", @"UAPushUI", @"None") : [UAirship namedUser].identifier;

    if ([UAirship push].tags.count) {
        self.tagsSubtitleLabel.text = [[UAirship push].tags componentsJoinedByString:@", "];
    } else {
        self.tagsSubtitleLabel.text = NSLocalizedStringFromTable(@"None", @"UAPushUI", @"None");
    }
}

- (NSString *)pushTypeString {
    UAAuthorizedNotificationSettings authorizedSettings = [UAirship push].authorizedNotificationSettings;

    NSMutableArray *settingsArray = [NSMutableArray arrayWithCapacity:3];

    if (authorizedSettings & UAAuthorizedNotificationSettingsAlert) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"UA_Notification_Type_Alerts", @"UAPushUI", @"Alerts")];
    }

    if (authorizedSettings & UAAuthorizedNotificationSettingsBadge) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"UA_Notification_Type_Badges", @"UAPushUI", @"Badges")];
    }

    if (authorizedSettings & UAAuthorizedNotificationSettingsSound) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"UA_Notification_Type_Sounds", @"UAPushUI", @"Sounds")];
    }

    if (![settingsArray count]) {
        return NSLocalizedStringFromTable(@"UA_Push_Settings_Link_Disabled_Title", @"UAPushUI", @"Pushes Currently Disabled");
    }

    return [settingsArray componentsJoinedByString:@", "];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == [tableView indexPathForCell:self.channelIDCell].section) {
        if (indexPath.row == [tableView indexPathForCell:self.channelIDCell].row) {
            if ([UAirship push].channelID) {
                [UIPasteboard generalPasteboard].string = self.channelIDSubtitleLabel.text;
                [self showCopyMessage];
            }
        }
    }
}

- (void)showCopyMessage {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:NSLocalizedStringFromTable(@"UA_Copied_To_Clipboard", @"UAPushUI", @"Copied to clipboard string")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"UA_OK", @"UAPushUI", @"OK button string")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];

    [alert addAction:okAction];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
