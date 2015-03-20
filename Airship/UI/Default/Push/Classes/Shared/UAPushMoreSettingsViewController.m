/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import "UAPushMoreSettingsViewController.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAPushLocalization.h"
#import "UAPushSettingsAliasViewController.h"
#import "UAPushSettingsNamedUserViewController.h"
#import "UAPushSettingsTagsViewController.h"
#import "UAPushSettingsSoundsViewController.h"
#import "UALocationSettingsViewController.h"
#import "UAUser.h"
#import "UAConfig.h"

#define kUAPushDeviceTokenPath @"deviceToken"
#define kUAPushChannelIDPath @"channelID"

enum {
    SectionDeviceToken = 0,
    SectionHelp        = 2,
    SectionLocation    = 3,
    SectionCount       = 4,
};

enum {
    DeviceTokenSectionTypesCell = 0,
    DeviceTokenSectionDisabledTypesCell = 1,
    DeviceTokenSectionChannelCell = 2,
    DeviceTokenSectionInboxUserCell = 3,
    DeviceTokenSectionTokenCell = 4,
    DeviceTokenSectionAliasCell = 5,
    DeviceTokenSectionTagsCell  = 6,
    DeviceTokenSectionNamedUserCell = 7,
    DeviceTokenSectionRowCount  = 8,
};

enum {
    HelpSectionSounds   = 0,
    HelpSectionRowCount = 1
};

static NSUInteger locationRowCount = 1;

@interface UAPushMoreSettingsViewController ()

@property (nonatomic, strong) UITableViewRowAction *pasteboardAction;
@property (nonatomic, strong) UITableViewRowAction *sendEmailAction;

@end

@implementation UAPushMoreSettingsViewController

- (void)dealloc {

    [[NSNotificationCenter defaultCenter] removeObserver:self.userCreatedObserver name:UAUserCreatedNotification object:nil];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Push Notification Demo";

    // make our existing layout work beyond iOS6
    if ([self respondsToSelector:NSSelectorFromString(@"edgesForExtendedLayout")]) {
        [self setValue:[NSNumber numberWithInt:0] forKey:@"edgesForExtendedLayout"];
    }

    [self initCells];
    [self buildRowActions];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[UAirship push] addObserver:self forKeyPath:kUAPushDeviceTokenPath options:NSKeyValueObservingOptionNew context:nil];
    [[UAirship push] addObserver:self forKeyPath:kUAPushChannelIDPath options:NSKeyValueObservingOptionNew context:nil];

    [self updateCellValues];
    UITableView *strongTableView = self.tableView;
    [strongTableView deselectRowAtIndexPath:[strongTableView indexPathForSelectedRow] animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:NO];
    [[UAirship push] removeObserver:self forKeyPath:kUAPushDeviceTokenPath];
    [[UAirship push] removeObserver:self forKeyPath:kUAPushChannelIDPath];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self.tableView flashScrollIndicators];
}

#pragma mark -

- (void)initCells {
    self.deviceTokenCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    self.deviceTokenCell.textLabel.text = @"Device Token";
    self.deviceTokenCell.accessibilityLabel = @"Device Token";
    
    self.deviceTokenTypesCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    self.deviceTokenTypesCell.textLabel.text = @"Notification Types";

    self.deviceTokenDisabledTypesCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    self.deviceTokenDisabledTypesCell.textLabel.text = @"Disabled Notification Types";
    
    self.deviceTokenAliasCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    self.deviceTokenAliasCell.textLabel.text = @"Alias";
    self.deviceTokenAliasCell.accessibilityLabel = @"Alias";
    self.deviceTokenAliasCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    self.deviceTokenTagsCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    self.deviceTokenTagsCell.textLabel.text = @"Tags";
    self.deviceTokenTagsCell.accessibilityLabel = @"Tags";
    self.deviceTokenTagsCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    self.deviceTokenNamedUserCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    self.deviceTokenNamedUserCell.textLabel.text = @"Named User";
    self.deviceTokenNamedUserCell.accessibilityLabel = @"Named User";
    self.deviceTokenNamedUserCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    self.channelCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    self.channelCell.textLabel.text = @"Channel ID";
    self.channelCell.accessibilityLabel = @"Channel ID";

    self.usernameCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    self.usernameCell.textLabel.text = @"Inbox User ID";
    self.usernameCell.accessibilityLabel = @"Inbox User ID";

    //if the user is still being created, update the cell once that is complete.
    if (![UAirship inboxUser].isCreated) {
        self.userCreatedObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UAUserCreatedNotification object:nil queue:nil usingBlock:^(NSNotification *note){
            [self updateCellValues];
            [self.usernameCell setNeedsLayout];

            [[NSNotificationCenter defaultCenter] removeObserver:self.userCreatedObserver name:UAUserCreatedNotification object:nil];
            self.userCreatedObserver = nil;
        }];
    }

    self.helpSoundsCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    self.helpSoundsCell.textLabel.text = @"Notification Sounds";
    self.helpSoundsCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    self.helpLogCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    self.helpLogCell.textLabel.text = @"Device Log";
    self.helpLogCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    self.locationCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    self.locationCell.textLabel.text = @"Location";
    
    [self updateCellValues];

}

- (void)buildRowActions {

    // All this functionality iOS 8+ only because it depends on this class
    if (![UITableViewRowAction class]) {
        return;
    }

    self.pasteboardAction =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Copy"
                                         handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {

                                            // This is the only section with actionable rows
                                            if (indexPath.section != SectionDeviceToken) {
                                                return;
                                            }

                                            NSString *pasteboardString;

                                            switch (indexPath.row) {
                                                case DeviceTokenSectionChannelCell:
                                                    pasteboardString = [UAirship push].channelID;
                                                    break;
                                                case DeviceTokenSectionTokenCell:
                                                    pasteboardString = [UAirship push].deviceToken;
                                                    break;
                                                case DeviceTokenSectionInboxUserCell:
                                                    pasteboardString = [UAirship inboxUser].username;
                                                    break;
                                            }

                                            if (pasteboardString) {
                                                [UIPasteboard generalPasteboard].string = pasteboardString;
                                            }
                                            self.tableView.editing = NO;
                                         }];

    self.sendEmailAction =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Email"
                                         handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {

                                             // This is the only section with actionable rows
                                             if (indexPath.section != SectionDeviceToken) {
                                                 return;
                                             }

                                             NSString *messageBody;

                                             switch (indexPath.row) {
                                                 case DeviceTokenSectionChannelCell:
                                                     messageBody = [NSString stringWithFormat:@"Your channel ID for app key %@ is %@",
                                                                    [UAirship shared].config.appKey,
                                                                    [UAirship push].channelID];
                                                     break;
                                                 case DeviceTokenSectionTokenCell:
                                                     messageBody = [NSString stringWithFormat:@"Your device token for app key %@ is %@",
                                                                    [UAirship shared].config.appKey,
                                                                    [UAirship push].deviceToken];
                                                     break;
                                                 case DeviceTokenSectionInboxUserCell:
                                                     messageBody = [NSString stringWithFormat:@"Your inbox user ID for app key %@ is %@",
                                                                    [UAirship shared].config.appKey,
                                                                    [UAirship inboxUser].username];
                                                     break;
                                             }

                                             if (messageBody) {
                                                 MFMailComposeViewController *mfViewController = [[MFMailComposeViewController alloc] init];
                                                 mfViewController.mailComposeDelegate = self;

                                                 [mfViewController setSubject:@"Channel ID"];
                                                 [mfViewController setMessageBody:messageBody isHTML:NO];

                                                 [self presentViewController:mfViewController animated:YES completion:NULL];
                                             }
                                             self.tableView.editing = NO;
                                         }];
    self.sendEmailAction.backgroundColor = [UIColor blueColor];
}

#pragma mark -
#pragma mark UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SectionDeviceToken:
            return DeviceTokenSectionRowCount;
        case SectionHelp:
            return HelpSectionRowCount;
        case SectionLocation:
            return (NSInteger)locationRowCount;
        default:
            break;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    switch (section) {
        case SectionDeviceToken:
            return @"Device Settings";
        case SectionHelp:
            return @"Bundle Info";
        case SectionLocation:
            return @"Location";
        default:
            break;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    if (indexPath.section == SectionDeviceToken) {
        
        switch (indexPath.row) {
            case DeviceTokenSectionTokenCell:
                cell = self.deviceTokenCell;
                break;
            case DeviceTokenSectionChannelCell:
                cell = self.channelCell;
                break;
            case DeviceTokenSectionInboxUserCell:
                cell = self.usernameCell;
                break;
            case DeviceTokenSectionTypesCell:
                cell = self.deviceTokenTypesCell;
                break;
            case DeviceTokenSectionDisabledTypesCell:
                cell = self.deviceTokenDisabledTypesCell;
                break;
            case DeviceTokenSectionAliasCell:
                cell = self.deviceTokenAliasCell;
                break;
            case DeviceTokenSectionNamedUserCell:
                cell = self.deviceTokenNamedUserCell;
                break;
            case DeviceTokenSectionTagsCell:
                cell = self.deviceTokenTagsCell;
                break;
            default:
                break;
        }
        
    } else if (indexPath.section == SectionHelp) {

        if (indexPath.row == HelpSectionSounds) {
            cell = self.helpSoundsCell;
        }
        
    } else if (indexPath.section == SectionLocation) {
        cell = self.locationCell;
    }

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }
    return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate and UITableViewDataSource Methods

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (![UITableViewRowAction class]) {
        return nil;
    }

    // Return row actions for copy/email-able cells (device token, channel ID, user ID)
    if (indexPath.section == SectionDeviceToken
            && (indexPath.row == DeviceTokenSectionChannelCell || indexPath.row == DeviceTokenSectionTokenCell || indexPath.row == DeviceTokenSectionInboxUserCell)) {

        // Always include pasteboard, but only include email if the device supports it / has it set up
        return [MFMailComposeViewController canSendMail] ? @[self.sendEmailAction, self.pasteboardAction] : @[self.pasteboardAction];
    }

    return nil;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Nothing is needed here. It's just required for iOS to show table view swipe actions.
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // If there are actions for the row, let it edit.
    return [self tableView:tableView editActionsForRowAtIndexPath:indexPath].count > 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? 55 : 44;
}

- (void)tableView:(UITableView *)view didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableView *strongTableView = self.tableView;

    if (indexPath.section == SectionDeviceToken) {
        if (indexPath.row == DeviceTokenSectionAliasCell) {
            if (!self.aliasViewController) {
                self.aliasViewController = [[UAPushSettingsAliasViewController alloc]
                                            initWithNibName:@"UAPushSettingsAliasView" bundle:nil];
            }
            [self.navigationController pushViewController:self.aliasViewController animated:YES];

        } else if (indexPath.row == DeviceTokenSectionNamedUserCell) {
            if (!self.namedUserViewController) {
                self.namedUserViewController = [[UAPushSettingsNamedUserViewController alloc]
                                       initWithNibName:@"UAPushSettingsNamedUserView" bundle:nil];
            }
            [self.navigationController pushViewController:self.namedUserViewController animated:YES];
            
        } else if (indexPath.row == DeviceTokenSectionTagsCell) {
            if (!self.tagsViewController) {
                self.tagsViewController = [[UAPushSettingsTagsViewController alloc]
                                      initWithNibName:@"UAPushSettingsTagsViewController" bundle:nil];
            }
            [self.navigationController pushViewController:self.tagsViewController animated:YES];
            
        } else {
            [strongTableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    } else if (indexPath.section == SectionHelp) {
        if (indexPath.row == HelpSectionSounds) {
            UAPushSettingsSoundsViewController *soundsViewController = [[UAPushSettingsSoundsViewController alloc] 
                                                                         initWithNibName:@"UAPushSettingsSoundsViewController" bundle:nil];
            [self.navigationController pushViewController:soundsViewController animated:YES];
        } else {
            [strongTableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        

    } else if (indexPath.section == SectionLocation) {
        UALocationSettingsViewController* locationViewController = [[UALocationSettingsViewController alloc] 
                                                                     initWithNibName:@"UALocationSettingsViewController" 
                                                                     bundle:nil];
        [self.navigationController pushViewController:locationViewController animated:YES];
        [strongTableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else {
        [strongTableView deselectRowAtIndexPath:indexPath animated:YES];
    }

}

#pragma mark -
#pragma mark KVO methods

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:kUAPushDeviceTokenPath] || [keyPath isEqualToString:kUAPushChannelIDPath]) {
        [self updateCellValues];

        [self.deviceTokenCell setNeedsLayout];
        [self.deviceTokenTypesCell setNeedsLayout];
        [self.deviceTokenDisabledTypesCell setNeedsLayout];
        [self.deviceTokenAliasCell setNeedsLayout];
        [self.deviceTokenNamedUserCell setNeedsLayout];
        [self.deviceTokenTagsCell setNeedsLayout];
        [self.channelCell setNeedsLayout];
    }
}


- (void)updateCellValues {
    
    self.deviceTokenCell.detailTextLabel.text = [UAirship push].deviceToken ? [UAirship push].deviceToken : @"Unavailable";

    UIUserNotificationType enabledTypes = [[UAirship push] currentEnabledNotificationTypes];

    self.deviceTokenTypesCell.detailTextLabel.text = [self pushTypeString:enabledTypes];
    
    UIUserNotificationType disabledTypes = enabledTypes ^ [UAirship push].userNotificationTypes;
    self.deviceTokenDisabledTypesCell.detailTextLabel.text = [self pushTypeString:disabledTypes];
    
    self.deviceTokenAliasCell.detailTextLabel.text = [UAirship push].alias ? [UAirship push].alias : @"Not Set";

    NSString *namedUserID = [UAirship push].namedUser.identifier;
    self.deviceTokenNamedUserCell.detailTextLabel.text = namedUserID ? namedUserID : @"Not Set";
    
    if ([[UAirship push].tags count] > 0) {
        self.deviceTokenTagsCell.detailTextLabel.text = [[UAirship push].tags componentsJoinedByString:@", "];
    } else {
        self.deviceTokenTagsCell.detailTextLabel.text = @"None";
    }

    self.channelCell.detailTextLabel.text = [UAirship push].channelID ? [UAirship push].channelID : @"Unavailable";
    self.usernameCell.detailTextLabel.text = [UAirship inboxUser].username ?: @"Unavailable";
}

- (NSString *)pushTypeString:(UIUserNotificationType)types {
    NSMutableArray *typeArray = [NSMutableArray arrayWithCapacity:3];

    //Use the same order as the Settings->Notifications panel
    if (types & UIUserNotificationTypeBadge) {
        [typeArray addObject:UAPushLocalizedString(@"UA_Notification_Type_Badges")];
    }

    if (types & UIUserNotificationTypeAlert) {
        [typeArray addObject:UAPushLocalizedString(@"UA_Notification_Type_Alerts")];
    }

    if (types & UIUserNotificationTypeSound) {
        [typeArray addObject:UAPushLocalizedString(@"UA_Notification_Type_Sounds")];
    }

    if ([typeArray count] > 0) {
        return [typeArray componentsJoinedByString:@", "];
    }

    return UAPushLocalizedString(@"None");
}

#pragma mark -
#pragma mark MFMailComposeViewControllerDelegate Methods

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message Status"
                                                    message:@""
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];

    switch (result) {
        case MFMailComposeResultSent:
            alert.message = @"Sent";
            break;
        case MFMailComposeResultCancelled:
            // Do not alert here - it was user initiated
            break;
        case MFMailComposeResultSaved:
            alert.message = @"Saved";
            break;
        case MFMailComposeResultFailed:
            alert.message = @"Failed";
            break;
    }

    [alert show];

    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
