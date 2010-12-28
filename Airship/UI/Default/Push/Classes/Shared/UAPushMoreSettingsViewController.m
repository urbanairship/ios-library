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


@implementation UAPushMoreSettingsViewController

@synthesize footerImageView;
@synthesize tableView;

- (void)dealloc {
    [[UAirship shared] removeObserver:self];
    [tableView release];
    [footerImageView release];
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
    self.footerImageView = nil;
    self.tableView = nil;
}

#pragma mark -

- (void)initCells {
    cell00 = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell00"];
    cell00.textLabel.text = @"Device Token";
    cell00.detailTextLabel.text = [UAirship shared].deviceToken;
    cell00.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    cell01 = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell01"];
    cell01.textLabel.text = @"Device-token Alias";
    cell01.detailTextLabel.text = [UAPush shared].alias;
    cell01.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    cell10 = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell10"];
    cell10.textLabel.text = @"Custom Notification Sounds";
    cell10.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    cell11 = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell11"];
    cell11.textLabel.text = @"Device Log";
    cell11.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)quit {
    [UAPush closeTokenSettingsAnimated:YES];
}

#pragma mark -
#pragma mark UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? nil : @"Help";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if (indexPath.section == 0)
        if (indexPath.row == 0) {
            cell00.detailTextLabel.text = [UAirship shared].deviceToken ? [UAirship shared].deviceToken : @"Unavailable";
            cell = cell00;
        }
        else {
            cell01.detailTextLabel.text = [UAPush shared].alias ? [UAPush shared].alias : @"Not Set";
            cell = cell01;
        }
    else
        if (indexPath.row == 0)
            cell = cell10;
        else
            cell = cell11;

    return cell;
}

#pragma mark -
#pragma mark UITableVieDelegate Methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? 60 : 44;
}

- (void)tableView:(UITableView *)view didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            if (!tokenViewController)
                tokenViewController = [[UAPushSettingsTokenViewController alloc]
                                       initWithNibName:@"UAPushSettingsTokenView" bundle:nil];
            [self.navigationController pushViewController:tokenViewController animated:YES];
        } else {
            if (!aliasViewController)
                aliasViewController = [[UAPushSettingsAliasViewController alloc]
                                       initWithNibName:@"UAPushSettingsAliasView" bundle:nil];
            [self.navigationController pushViewController:aliasViewController animated:YES];
        }
    } else {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }

}

#pragma mark -
#pragma mark UA Registration Observer methods

- (void)registerDeviceTokenSucceed {
    cell00.detailTextLabel.text = [UAirship shared].deviceToken ? [UAirship shared].deviceToken : @"Unavailable";
    cell01.detailTextLabel.text = [UAPush shared].alias ? [UAPush shared].alias : @"Not Set";
    [cell00 setNeedsLayout];
    [cell01 setNeedsLayout];
}

@end
