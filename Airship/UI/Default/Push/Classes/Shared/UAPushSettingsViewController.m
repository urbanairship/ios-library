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

#import "UAPushSettingsViewController.h"
#import "UAPush.h"
#import "UAirship.h"


@implementation UAPushSettingsViewController

@synthesize tableView;
@synthesize datePicker;
@synthesize quietTimeSwitch;
@synthesize fromCell;
@synthesize toCell;
@synthesize enabledCell;

#pragma mark -
#pragma mark Lifecycle methods

- (void)dealloc {
    [quietTimeSwitch release];
    [tableView release];
    [datePicker release];

    [super dealloc];
}

- (void)viewDidLoad {
    [self initViews];
    [super viewDidLoad];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)viewDidUnload {
    self.quietTimeSwitch = nil;
    self.tableView = nil;
    self.datePicker = nil;
    self.enabledCell = nil;
    self.toCell = nil;
    self.fromCell = nil;

    [super viewDidUnload];
}

#pragma mark -
#pragma mark UITableViewDataSource Methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = [indexPath row];
    if (row == 0) {
        enabledCell.selectionStyle = UITableViewCellSelectionStyleNone;
        return enabledCell;
    } else if (row == 1) {
        return fromCell;
    } else {
        return toCell;
    }
}

#pragma mark -
#pragma mark UITableVieDelegate Methods
- (void)tableView:(UITableView *)view didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 1 || indexPath.row == 2) {
        [self updateDatePicker:YES];
    } else {
        [self updateDatePicker:NO];
    }
}

#pragma mark -
#pragma mark logic

static NSString *cellID = @"QuietTimeCell";

- (void)initViews {
    self.title = @"Quiet Time";
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                            target:self
                                                                                            action:@selector(quit)]
                                              autorelease];

    UIRemoteNotificationType type = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    if (type == UIRemoteNotificationTypeNone) {
        quietTimeSwitch.on = NO;
    } else {
        quietTimeSwitch.on = YES;
    }

    fromCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
    toCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
    fromCell.textLabel.text = @"From";
    toCell.textLabel.text = @"To";

    NSDictionary *quietTime = [[NSUserDefaults standardUserDefaults] objectForKey:kQuiettime];
    if (quietTime) {
        NSDate *date1, *date2;
        NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];

        [formatter setDateFormat:@"HH:mm"];
        date1 = [formatter dateFromString:[quietTime objectForKey:@"start"]];
        date2 = [formatter dateFromString:[quietTime objectForKey:@"end"]];
        [formatter setDateFormat:@"hh:mm aaa"];
        fromCell.detailTextLabel.text = [formatter stringFromDate:date1];
        toCell.detailTextLabel.text = [formatter stringFromDate:date2];
    } else {
        fromCell.detailTextLabel.text = @"";
        toCell.detailTextLabel.text = @"";
    }

    NSDate *now = [[NSDate alloc] init];
    [datePicker setDate:now animated:YES];
    [now release];

    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGRect initBounds = datePicker.bounds;
    CGFloat statusBarOffset = [UIApplication sharedApplication].statusBarHidden ? 0 : 20;
    CGFloat navBarOffset = 0;
    if (self.navigationController && self.navigationController.isNavigationBarHidden == NO) {
        navBarOffset = 44;
    }
    pickerShownFrame = CGRectMake(0, screenBounds.size.height-initBounds.size.height-statusBarOffset-navBarOffset,
                                  screenBounds.size.width, initBounds.size.height);
    pickerHiddenFrame = CGRectMake(0, screenBounds.size.height-statusBarOffset-navBarOffset,
                                   screenBounds.size.width, initBounds.size.height);
    datePicker.frame = pickerHiddenFrame;
    [self.view setNeedsLayout];
}

- (IBAction)quit {
    [UAPush closeApnsSettingsAnimated:YES];
}

- (IBAction)pickerVauleChanged:(id)sender {

    NSDate *date = [datePicker date];
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"hh:mm aaa"];

    int row = [[self.tableView indexPathForSelectedRow] row];
    if (row == 1) {
        fromCell.detailTextLabel.text = [formatter stringFromDate:date];
        [fromCell setNeedsLayout];
    } else if (row == 2) {
        toCell.detailTextLabel.text = [formatter stringFromDate:date];
        [toCell setNeedsLayout];
    } else {
        NSDate *now = [[NSDate alloc] init];
        [datePicker setDate:now animated:YES];
        [now release];
        return;
    }

    NSString *fromString = fromCell.detailTextLabel.text;
    NSString *toString = toCell.detailTextLabel.text;
    NSDate *fromDate = [formatter dateFromString:fromString];
    NSDate *toDate = [formatter dateFromString:toString];

    [[UAPush shared] setQuiettimeFrom:fromDate To:toDate WithTimeZone:[NSTimeZone localTimeZone]];
}

- (IBAction)switchValueChanged:(id)sender {
    UIRemoteNotificationType type;

    if (quietTimeSwitch.on) {
        type = UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound;
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:type];
    } else {
        // Urban server will unregister this device token with apple server.
        [[UAirship shared] unRegisterDeviceToken];
    }
    [self updateDatePicker:NO];
}

- (void)updateDatePicker:(BOOL)show {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.4];
    if (show) {
        datePicker.frame = pickerShownFrame;
    } else {
        datePicker.frame = pickerHiddenFrame;
        [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:NO];
    }
    [UIView commitAnimations];

    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"hh:mm aaa"];
    NSString *fromString = fromCell.detailTextLabel.text;
    NSString *toString = toCell.detailTextLabel.text;

    int row = [[self.tableView indexPathForSelectedRow] row];
    if (row == 1 && [fromString length] != 0) {
        NSDate *fromDate = [formatter dateFromString:fromString];
        [datePicker setDate:fromDate animated:YES];
    } else if (row == 2 && [toString length] != 0) {
        NSDate *toDate = [formatter dateFromString:toString];
        [datePicker setDate:toDate animated:YES];
    }
}

@end
