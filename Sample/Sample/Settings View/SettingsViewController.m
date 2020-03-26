/* Copyright Airship and Contributors */

@import AirshipCore;
@import AirshipLocation;

#import "SettingsViewController.h"


@interface SettingsViewController ()

@property (nonatomic, copy) NSString *localizedNone;
@property NSIndexPath* pushEnabled;
@property NSIndexPath* locationEnabled;
@property NSIndexPath* channelID;
@property NSIndexPath* namedUser;
@property NSIndexPath* tags;
@property NSIndexPath* analyticsEnabled;
@end

@implementation SettingsCell

- (void)layoutSubviews {
    [super layoutSubviews];
    
    NSString *sub = @"";
    
    if (sub == self.subtitle.text) {
        return;
    }
    
    if (!self.subtitle.text.length) {
        self.titleTopConstraint.priority = 100;
    } else {
        self.titleTopConstraint.priority = 999;
    }
}

@end

@implementation SettingsViewController

NSString *tagsSegue = @"tagsSegue";

static NSUInteger const sectionCount = 4;

typedef NS_ENUM(NSUInteger, UASettingsViewControllerSection) {
    UASettingsViewControllerSectionPush,
    UASettingsViewControllerSectionDevice,
    UASettingsViewControllerSectionAnalytics,
    UASettingsViewControllerSectionLocation
};

- (void)pushSettingsButtonTapped {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIImage *image = [UIImage imageNamed:@"outline_settings_black_24pt"];
    
    UIBarButtonItem *pushSettings = [[UIBarButtonItem alloc]initWithImage:image style:UIBarButtonItemStyleDone target:self action:@selector(pushSettingsButtonTapped)];
    
    self.navigationItem.rightBarButtonItem = pushSettings;
    [self.navigationController.navigationBar setTitleTextAttributes: @{NSForegroundColorAttributeName:[UIColor whiteColor]}];

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshView) name:UAChannelUpdatedEvent object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name: UIApplicationDidBecomeActiveNotification object:nil];
    
    self.pushEnabled = [NSIndexPath indexPathForRow:0 inSection:0];
    self.channelID = [NSIndexPath indexPathForRow:0 inSection:1];
    self.namedUser = [NSIndexPath indexPathForRow:1 inSection:1];
    self.tags = [NSIndexPath indexPathForRow:2 inSection:1];
    self.locationEnabled = [NSIndexPath indexPathForRow:0 inSection:2];
    self.analyticsEnabled = [NSIndexPath indexPathForRow:0 inSection:3];
    self.localizedNone = NSLocalizedStringFromTable(@"ua_none", @"UAPushUI", @"None");
}

- (void)setTableViewTheme {
    self.tableView.backgroundColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes: @{NSForegroundColorAttributeName:[UIColor whiteColor]}];
    self.navigationController.navigationBar.barTintColor = [UIColor blackColor];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)didBecomeActive {
    [self refreshView];
    [self setTableViewTheme];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshView];
}

- (void)refreshView {
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return sectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case UASettingsViewControllerSectionPush:
            return  NSLocalizedStringFromTable(@"ua_device_info_push_settings", @"UAPushUI", @"Push Settings");
        case UASettingsViewControllerSectionDevice:
            return NSLocalizedStringFromTable(@"ua_device_info_device_settings", @"UAPushUI", @"Device Settings");
        case UASettingsViewControllerSectionAnalytics:
            return NSLocalizedStringFromTable(@"ua_device_info_analytics_settings", @"UAPushUI", @"Analytics Settings");
        case UASettingsViewControllerSectionLocation:
            return NSLocalizedStringFromTable(@"ua_device_info_location_settings", @"UAPushUI", @"Location Settings");
        default:
            return @"";
    }
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)headerView forSection:(NSInteger)section {
    if([headerView isKindOfClass:[UITableViewHeaderFooterView class]]){
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) headerView;
        [tableViewHeaderFooterView.textLabel setTextColor:[UIColor colorWithRed:0.00 green:0.29 blue:1.00 alpha:1.00]];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    switch (section) {
        case UASettingsViewControllerSectionPush:
            return 1;
        case UASettingsViewControllerSectionDevice:
            return 3;
        case UASettingsViewControllerSectionAnalytics:
            return 1;
        case UASettingsViewControllerSectionLocation:
            return 1;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"SettingsCell";
    
    SettingsCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    cell.backgroundColor = [UIColor whiteColor];
    cell.title.textColor = [UIColor blackColor];
    cell.subtitle.textColor = [UIColor colorWithRed:0.51 green:0.51 blue:0.53 alpha:1.0];
    cell.cellSwitch.onTintColor = [UIColor colorWithRed:0.00 green:0.29 blue:1.00 alpha:1.00];
    cell.cellSwitch.tintColor = [UIColor colorWithRed:0.00 green:0.29 blue:1.00 alpha:1.00];
    
    cell.cellSwitch.hidden = YES;
    cell.cellSwitch.userInteractionEnabled = NO;
    cell.accessoryType = 0;
    cell.subtitle.text = nil;

    if (indexPath.section == UASettingsViewControllerSectionPush) {
        if (indexPath.row == self.pushEnabled.row) {
            cell.title.text = NSLocalizedStringFromTable(@"ua_device_info_push_settings", @"UAPushUI", @"Push Settings");
            cell.subtitle.text = NSLocalizedStringFromTable(@"ua_device_info_enable_push", @"UAPushUI", @"Enable Push");
            cell.cellSwitch.hidden = NO;
            cell.cellSwitch.on = UAirship.push.userPushNotificationsEnabled;
            cell.subtitle.text = [self pushTypeString];
            cell.subtitle.adjustsFontSizeToFitWidth = YES;
            cell.subtitle.minimumScaleFactor = 0.25;
            cell.subtitle.numberOfLines = 1;
        }
    }
    if (indexPath.section == UASettingsViewControllerSectionDevice) {
        if (indexPath.row == self.channelID.row) {
            cell.title.text = NSLocalizedStringFromTable(@"ua_device_info_channel_id", @"UAPushUI", @"Channel ID");
            cell.subtitle.text = UAirship.channel.identifier;
        }
    }
    if (indexPath.row == self.namedUser.row) {
        cell.title.text = NSLocalizedStringFromTable(@"ua_device_info_named_user", @"UAPushUI", @"Named User");
         cell.subtitle.text = (UAirship.namedUser.identifier == nil) ? self.localizedNone : UAirship.namedUser.identifier;
         cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (indexPath.row == self.tags.row) {
         cell.title.text = NSLocalizedStringFromTable(@"ua_device_info_tags", @"UAPushUI", @"Tags");
         if (UAirship.channel.tags.count > 0) {
             cell.subtitle.text = [UAirship.channel.tags componentsJoinedByString:@", "];
         } else {
             cell.subtitle.text = self.localizedNone;
         }

         cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (indexPath.section == UASettingsViewControllerSectionAnalytics) {
        if (indexPath.row == self.analyticsEnabled.row) {
            cell.title.text = NSLocalizedStringFromTable(@"ua_device_info_analytics_enabled", @"UAPushUI", @"Analytics Enabled");
            cell.subtitle.text = NSLocalizedStringFromTable(@"ua_device_info_enable_analytics_tracking", @"UAPushUI", @"Enable analytics tracking");
            cell.cellSwitch.hidden = NO;
            cell.cellSwitch.on = UAirship.analytics.isEnabled;
            cell.subtitle.adjustsFontSizeToFitWidth = YES;
        }
    }
    if (indexPath.section == UASettingsViewControllerSectionLocation) {
        if (indexPath.row == self.locationEnabled.row) {
            cell.title.text = NSLocalizedStringFromTable(@"ua_device_info_enable_location_enabled", @"UAPushUI", @"Location Enabled");
            cell.cellSwitch.hidden = NO;
            cell.cellSwitch.on = UALocation.shared.isLocationUpdatesEnabled;
            BOOL optedInToLocation = UALocation.shared.isLocationOptedIn;
            if(UALocation.shared.isLocationUpdatesEnabled && !optedInToLocation) {
                cell.subtitle.text = [NSLocalizedStringFromTable(@"ua_location_enabled_detail", @"UAPushUI", @"Enable GPS and WIFI Based Location detail label") stringByAppendingString:@" - NOT OPTED IN"];
            } else {
                cell.subtitle.text = self.localizedNone;
            }
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SettingsCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if (indexPath.section == 0) {
        if (indexPath.row == self.pushEnabled.row) {
            [cell.cellSwitch setOn:!cell.cellSwitch.on animated:YES];
            UAirship.push.userPushNotificationsEnabled = cell.cellSwitch.on;
        }
    }
    if (indexPath.section == 1) {
        if (indexPath.row == self.channelID.row) {
            if (UAirship.channel.identifier != nil) {
                UIPasteboard.generalPasteboard.string = cell.subtitle.text;
                [self showCopiedAlert];
            }
        }
        if (indexPath.row == self.namedUser.row) {
            [self performSegueWithIdentifier:@"namedUserSegue" sender:self];
        }
        if (indexPath.row == self.tags.row) {
            [self performSegueWithIdentifier:@"tagsSegue" sender:self];

        }
    }
    if (indexPath.section == 2) {
        if (indexPath.row == self.analyticsEnabled.row) {
            [cell.cellSwitch setOn:!cell.cellSwitch.on animated:YES];
            UAirship.push.userPushNotificationsEnabled = cell.cellSwitch.on;
        }
    }
    if (indexPath.section == 3) {
        if (indexPath.row == self.locationEnabled.row) {
            [cell.cellSwitch setOn:!cell.cellSwitch.on animated:YES];
            UAirship.push.userPushNotificationsEnabled = cell.cellSwitch.on;
        }
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)showCopiedAlert {
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

- (NSString *)pushTypeString {
    UAAuthorizedNotificationSettings authorizedSettings = [UAirship push].authorizedNotificationSettings;

    
    NSMutableArray *settingsArray = [[NSMutableArray alloc] init];;
    
    if ((UAAuthorizedNotificationSettingsAlert & authorizedSettings) > 0) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"ua_notification_type_alerts", @"UAPushUI", @"Alerts")];
    }
    
    if ((UAAuthorizedNotificationSettingsBadge & authorizedSettings) > 0) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"ua_notification_type_badges", @"UAPushUI", @"Badges")];
    }
    
    if ((UAAuthorizedNotificationSettingsSound & authorizedSettings) > 0) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"ua_notification_type_sounds", @"UAPushUI", @"Sounds")];
    }
    
    if ((UAAuthorizedNotificationSettingsCarPlay & authorizedSettings) > 0) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"ua_notification_type_car_play", @"UAPushUI", @"CarPlay")];
    }

    if ((UAAuthorizedNotificationSettingsLockScreen & authorizedSettings) > 0) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"ua_notification_type_lock_screen", @"UAPushUI", @"Lock Screen")];
    }

    if ((UAAuthorizedNotificationSettingsNotificationCenter & authorizedSettings) > 0) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"ua_notification_type_notification_center", @"UAPushUI", @"Notification Center")];
    }
    
    if ((UAAuthorizedNotificationSettingsCriticalAlert & authorizedSettings) > 0) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"ua_notification_type_critical_alert", @"UAPushUI", @"Critical Alert")];
    }
    
    if ((UAAuthorizedNotificationSettingsAnnouncement & authorizedSettings) > 0) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"ua_notification_type_announcement", @"UAPushUI", @"AirPod Announcement")];
    }
    
    if (settingsArray.count == 0) {
        [settingsArray addObject:NSLocalizedStringFromTable(@"ua_push_settings_link_disabled_title", @"UAPushUI", @"Pushes Currently Disabled")];
    }
    
    return [settingsArray componentsJoinedByString:(@", ")];
}

@end
