/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UAViewUtils.h"
#import "UAPush.h"
#import "UAPushSettingsTokenViewController.h"
#import "UAPushSettingsAliasViewController.h"
#import "UAPushSettingsTagsViewController.h"
#import "UAPushSettingsSoundsViewController.h"

enum {
    SectionDeviceToken = 0,
    SectionHelp        = 1,
    SectionCount       = 2
};

enum {
    DeviceTokenSectionTokenCell = 0,
    DeviceTokenSectionTypesCell = 1,
    DeviceTokenSectionAliasCell = 2,
    DeviceTokenSectionTagsCell = 3,
    DeviceTokenSectionRowCount  = 4
};

enum {
    HelpSectionSounds = 0,
    HelpSectionLog = 1,
    HelpSectionRowCount  = 2
};

@implementation UAPushMoreSettingsViewController

@synthesize footerImageView;
@synthesize tableView;

- (void)dealloc {
    [[UAirship shared] removeObserver:self];

    RELEASE_SAFELY(deviceTokenCell);
    RELEASE_SAFELY(deviceTokenTypesCell);
    RELEASE_SAFELY(deviceTokenAliasCell);
    RELEASE_SAFELY(deviceTokenTagsCell);
    RELEASE_SAFELY(helpSoundsCell);
    RELEASE_SAFELY(helpLogCell);
    
    self.footerImageView = nil;
    self.tableView = nil;
    
    
    RELEASE_SAFELY(tokenViewController);
    RELEASE_SAFELY(aliasViewController);
    RELEASE_SAFELY(tagsViewController);
    
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Push Notification Demo";

    self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc]
                                              initWithTitle:@"Back"
                                              style:UIBarButtonItemStyleBordered
                                              target:nil
                                              action:nil]
                                             autorelease];

    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
                                              initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                              target:self
                                              action:@selector(quit)]
                                             autorelease];

    [self initCells];

    [UAViewUtils roundView:footerImageView borderRadius:10
               borderWidth:1 color:[UIColor lightGrayColor]];
    [[UAirship shared] addObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    
//    deviceTokenCell.detailTextLabel.text = [UAirship shared].deviceToken ? [UAirship shared].deviceToken : @"Unavailable";
//    deviceTokenTypesCell.detailTextLabel.text = [UAPush pushTypeString];
//    deviceTokenAliasCell.detailTextLabel.text = [UAPush shared].alias ? [UAPush shared].alias : @"Not Set";
//    
    [self updateCellValues];
    
    [self.tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [tableView flashScrollIndicators];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    RELEASE_SAFELY(deviceTokenCell);
    RELEASE_SAFELY(deviceTokenTypesCell);
    RELEASE_SAFELY(deviceTokenAliasCell);
    RELEASE_SAFELY(deviceTokenTagsCell);
    RELEASE_SAFELY(helpSoundsCell);
    RELEASE_SAFELY(helpLogCell);
    
    
    self.footerImageView = nil;
    self.tableView = nil;
}

#pragma mark -

- (void)initCells {
    deviceTokenCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell00"];
    deviceTokenCell.textLabel.text = @"Device Token";
    //deviceTokenCell.detailTextLabel.text = [UAirship shared].deviceToken;
    deviceTokenCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    deviceTokenTypesCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"deviceTokenTypesCell"];
    deviceTokenTypesCell.textLabel.text = @"Notification Types";
    //deviceTokenTypesCell.detailTextLabel.text = [UAPush pushTypeString];
    //deviceTokenTypesCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    deviceTokenAliasCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell01"];
    deviceTokenAliasCell.textLabel.text = @"Alias";
    //deviceTokenAliasCell.detailTextLabel.text = [UAPush shared].alias;
    deviceTokenAliasCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    deviceTokenTagsCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell01"];
    deviceTokenTagsCell.textLabel.text = @"Tags";
    //deviceTokenTagsCell.detailTextLabel.text = [[UAPush shared].tags componentsJoinedByString:@", "];
    deviceTokenTagsCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    helpSoundsCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell10"];
    helpSoundsCell.textLabel.text = @"Custom Notification Sounds";
    helpSoundsCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    helpLogCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell11"];
    helpLogCell.textLabel.text = @"Device Log";
    helpLogCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    [self updateCellValues];
}

- (void)quit {
    [UAPush closeTokenSettingsAnimated:YES];
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
        default:
            break;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    switch (section) {
        case SectionHelp:
            return @"Help";
        default:
            break;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if (indexPath.section == SectionDeviceToken) {
        
        switch (indexPath.row) {
            case DeviceTokenSectionTokenCell:
                //deviceTokenCell.detailTextLabel.text = [UAirship shared].deviceToken ? [UAirship shared].deviceToken : @"Unavailable";
                cell = deviceTokenCell;
                break;
            case DeviceTokenSectionTypesCell:
                //deviceTokenTypesCell.detailTextLabel.text = [UAPush pushTypeString];
                cell = deviceTokenTypesCell;
                break;
            case DeviceTokenSectionAliasCell:
                //deviceTokenAliasCell.detailTextLabel.text = [UAPush shared].alias ? [UAPush shared].alias : @"Not Set";
                cell = deviceTokenAliasCell;
                break;
            case DeviceTokenSectionTagsCell:
                cell = deviceTokenTagsCell;
                break;
            default:
                break;
        }
        
        
//        if (indexPath.row == DeviceTokenSectionTokenCell) {
//            deviceTokenCell.detailTextLabel.text = [UAirship shared].deviceToken ? [UAirship shared].deviceToken : @"Unavailable";
//            cell = deviceTokenCell;
//        } else if (indexPath.row == DeviceTokenSectionTypesCell) {
//            deviceTokenTypesCell.detailTextLabel.text = [UAPush pushTypeString];
//            cell = deviceTokenTypesCell;
//        } else if (indexPath.row == DeviceTokenSectionAliasCell) {
//            deviceTokenAliasCell.detailTextLabel.text = [UAPush shared].alias ? [UAPush shared].alias : @"Not Set";
//            cell = deviceTokenAliasCell;
//        }
    } else if (indexPath.section == SectionHelp) {

        if (indexPath.row == HelpSectionSounds) {
            cell = helpSoundsCell;
        } else if (indexPath.row == HelpSectionLog) {
            cell = helpLogCell;
        }
    }

    return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate Methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? 60 : 44;
}

- (void)tableView:(UITableView *)view didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == SectionDeviceToken) {
        if (indexPath.row == DeviceTokenSectionTokenCell) {
            if (!tokenViewController) {
                tokenViewController = [[UAPushSettingsTokenViewController alloc]
                                       initWithNibName:@"UAPushSettingsTokenView" bundle:nil];
            }
            [self.navigationController pushViewController:tokenViewController animated:YES];
        } else if (indexPath.row == DeviceTokenSectionAliasCell) {
            if (!aliasViewController) {
                aliasViewController = [[UAPushSettingsAliasViewController alloc]
                                       initWithNibName:@"UAPushSettingsAliasView" bundle:nil];
            }
            [self.navigationController pushViewController:aliasViewController animated:YES];
            
        }else if (indexPath.row == DeviceTokenSectionTagsCell) {
            if (!tagsViewController) {
                tagsViewController = [[UAPushSettingsTagsViewController alloc] init];
            }
            [self.navigationController pushViewController:tagsViewController animated:YES];
            
        } else {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    } else if (indexPath.section == SectionHelp) {
        if (indexPath.row == HelpSectionSounds) {

            UAPushSettingsSoundsViewController *soundsViewController = [[[UAPushSettingsSoundsViewController alloc] init] autorelease];
            [self.navigationController pushViewController:soundsViewController animated:YES];
        } else {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        }


    } else {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }

}

#pragma mark -
#pragma mark UA Registration Observer methods

- (void)registerDeviceTokenSucceed {
//    deviceTokenCell.detailTextLabel.text = [UAirship shared].deviceToken ? [UAirship shared].deviceToken : @"Unavailable";
//    deviceTokenTypesCell.detailTextLabel.text = [UAPush pushTypeString];
//    deviceTokenAliasCell.detailTextLabel.text = [UAPush shared].alias ? [UAPush shared].alias : @"Not Set";
//    deviceTokenTagsCell.detailTextLabel.text = [[UAPush shared].tags componentsJoinedByString:@", "];
//    
    
    [self updateCellValues];
    
    [deviceTokenCell setNeedsLayout];
    [deviceTokenTypesCell setNeedsLayout];
    [deviceTokenAliasCell setNeedsLayout];
    [deviceTokenTagsCell setNeedsLayout];
}

- (void)updateCellValues {
    
    deviceTokenCell.detailTextLabel.text = [UAirship shared].deviceToken ? [UAirship shared].deviceToken : @"Unavailable";
    deviceTokenTypesCell.detailTextLabel.text = [UAPush pushTypeString];
    deviceTokenAliasCell.detailTextLabel.text = [UAPush shared].alias ? [UAPush shared].alias : @"Not Set";
    
    if ([[UAPush shared].tags count] > 0) {
        deviceTokenTagsCell.detailTextLabel.text = [[UAPush shared].tags componentsJoinedByString:@", "];
    } else {
        deviceTokenTagsCell.detailTextLabel.text = @"None";
    }
}

@end
