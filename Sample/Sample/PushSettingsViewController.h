/* Copyright 2017 Urban Airship and Contributors */

@import UIKit;

@interface PushSettingsViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UITableViewCell *pushEnabledCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *channelIDCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *namedUserCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *aliasCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *tagsCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *locationEnabledCell;

@property (weak, nonatomic) IBOutlet UISwitch *pushEnabledSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *locationEnabledSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *analyticsSwitch;

@property (weak, nonatomic) IBOutlet UILabel *pushSettingsLabel;
@property (weak, nonatomic) IBOutlet UILabel *pushSettingsSubtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *locationEnabledLabel;
@property (weak, nonatomic) IBOutlet UILabel *locationEnabledSubtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *channelIDSubtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *namedUserSubtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *aliasSubtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *tagsSubtitleLabel;

- (IBAction)switchValueChanged:(id)sender;

@end

