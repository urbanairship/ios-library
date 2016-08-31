/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// Import the Urban Airship umbrella header using the framework
#import <AirshipKit/AirshipKit.h>
#import "PushSettingsViewController.h"

@interface PushSettingsViewController ()

@end

@implementation PushSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshView) name:@"channelIDUpdated" object:nil];

    // Initialize switches
    self.pushEnabledSwitch.on = [UAirship push].userPushNotificationsEnabled;
    self.locationEnabledSwitch.on = [UAirship location].locationUpdatesEnabled;
    self.analyticsSwitch.on = [UAirship shared].analytics.enabled;

    // Add observer to didBecomeActive to update upon retrun from system settings screen
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:@"UIApplicationDidBecomeActiveNotification" object:nil];

    self.locationEnabledLabel.text = NSLocalizedStringFromTable(@"UA_Location_Enabled", @"UAPushUI", @"Location Enabled label");
    self.locationEnabledSubtitleLabel.text = NSLocalizedStringFromTable(@"UA_Location_Enabled_Detail", @"UAPushUI", @"Enable GPS and WIFI Based Location detail label");
}

- (void)didBecomeActive {
    [self refreshView];
}

- (void)viewWillAppear:(BOOL)animated {
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

    [UAirship shared].analytics.enabled = self.analyticsSwitch.on;
}

- (void)refreshView {

    self.channelIDSubtitleLabel.text = [UAirship push].channelID;

    self.aliasSubtitleLabel.text = [UAirship push].alias == nil ? NSLocalizedStringFromTable(@"None", @"UAPushUI", @"None") : [UAirship push].alias;

    self.namedUserSubtitleLabel.text = [UAirship namedUser].identifier == nil ? NSLocalizedStringFromTable(@"None", @"UAPushUI", @"None") : [UAirship namedUser].identifier;

    if ([UAirship push].tags.count) {
        self.tagsSubtitleLabel.text = [[UAirship push].tags componentsJoinedByString:@", "];
    } else {
        self.tagsSubtitleLabel.text = NSLocalizedStringFromTable(@"None", @"UAPushUI", @"None");
    }

    // iOS 8 & 9 - user notifications cannot be disabled, so remove switch and link to system settings
    if (![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 0, 0}] && [UAirship push].userPushNotificationsEnabled) {
        self.pushSettingsLabel.text = NSLocalizedStringFromTable(@"UA_Push_Settings_Title", @"UAPushUI", @"System Push Settings Label");
        self.pushSettingsSubtitleLabel.text = [self pushTypeString];
        self.pushEnabledSwitch.hidden = YES;
        self.pushEnabledCell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
}

- (NSString *)pushTypeString {
    UANotificationOptions options = [UAirship push].authorizedNotificationOptions;

    NSMutableArray *typeArray = [NSMutableArray arrayWithCapacity:3];

    if (options & UANotificationOptionAlert) {
        [typeArray addObject:NSLocalizedStringFromTable(@"UA_Notification_Type_Alerts", @"UAPushUI", @"Alerts")];
    }

    if (options & UANotificationOptionBadge) {
        [typeArray addObject:NSLocalizedStringFromTable(@"UA_Notification_Type_Badges", @"UAPushUI", @"Badges")];
    }

    if (options & UANotificationOptionSound) {
        [typeArray addObject:NSLocalizedStringFromTable(@"UA_Notification_Type_Sounds", @"UAPushUI", @"Sounds")];
    }

    if (![typeArray count]) {
        return NSLocalizedStringFromTable(@"UA_Push_Settings_Link_Disabled_Title", @"UAPushUI", @"Pushes Currently Disabled");
    }

    return [typeArray componentsJoinedByString:@", "];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];


    // iOS 8 & 9 - redirect push enabled cell to system settings
    if (![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 0, 0}] && [UAirship push].userPushNotificationsEnabled) {
        if (indexPath.section == [tableView indexPathForCell:self.pushEnabledCell].section) {
            if (indexPath.row == [tableView indexPathForCell:self.pushEnabledCell].row) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
            }
        }
    }

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
    UAInAppMessage *message = [[UAInAppMessage alloc] init];
    message.alert = NSLocalizedStringFromTable(@"UA_Copied_To_Clipboard", @"UAPushUI", @"Copied to clipboard string");
    message.position = UAInAppMessagePositionTop;
    message.duration = 1.5;
    message.primaryColor = [UIColor colorWithRed:255/255.f green:200/255.f blue:40/255.f alpha:1];
    message.secondaryColor = [UIColor colorWithRed:0/255.f green:105/255.f blue:143/255.f alpha:1];
    [[UAirship inAppMessaging] displayMessage:message];
}

@end
