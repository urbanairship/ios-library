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

#import "UAirship.h"
#import "UAPush.h"
#import "UAPushLocalization.h"
#import "UAPushSettingsViewController.h"
#import "UALocationService.h"
#import "UAAnalytics.h"

// Overall counts for sectioned table view
enum {
    SectionPushEnabled = 0,
    SectionAirshipLocationEnabled = 1,
    SectionAnalyticsEnabled = 2,
    SectionQuietTime   = 3,
    SectionCount       = 4
};

// The section for the push enabled switch is 0
// The row count for the push table view is 1
static NSUInteger PushEnabledSectionRowCount = 1;

// The section for the Airship is 1
static NSUInteger AirshipLocationEnabledSectionRowCount = 1;

static NSUInteger AnalyticsEnabledSectionRowCount = 1;

// Enums for the Quiet time table view
enum {
    QuietTimeSectionSwitchCell  = 0,
    QuietTimeSectionStartCell   = 1,
    QuietTimeSectionEndCell     = 2,
    QuietTimeSectionRowCount    = 3
};

@implementation UAPushSettingsViewController

#pragma mark -
#pragma mark Lifecycle methods


- (void)viewDidLoad {
    [super viewDidLoad];
    [self initViews];

    // Register for foreground notifications so that we can update
    // our push settings when a user comes back from Settings.app
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSettingsLinkText)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {

    //Hide the picker if it was left up last time
    [self updateDatePicker:NO];

    [self updateSettingsLinkText];

    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self saveState];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
    //if shown, update picker and scroll offset
    if (self.pickerDisplayed) {
        [self updateDatePicker:YES];
    }
}

#pragma mark -
#pragma mark UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.pushEnabledSwitch.on) {
        return SectionCount;
    } else {
        return SectionCount - 1;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    BOOL pushEnabledSwitchOn = self.pushEnabledSwitch.on;

    switch (section) {
        case SectionPushEnabled:
        {
            return (NSInteger)PushEnabledSectionRowCount;
        }
        case SectionAirshipLocationEnabled:
        {
            return (NSInteger)AirshipLocationEnabledSectionRowCount;
        }
        case SectionAnalyticsEnabled:
        {
            return (NSInteger)AnalyticsEnabledSectionRowCount;
        }
        case SectionQuietTime:
        {
            if (pushEnabledSwitchOn && self.quietTimeSwitch.on) {
                return QuietTimeSectionRowCount;
            } else if (pushEnabledSwitchOn) {
                return 1;
            }
        }
        default:
            break;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == SectionQuietTime) {
        if (indexPath.row == QuietTimeSectionSwitchCell) {
            self.quietTimeEnabledCell.selectionStyle = UITableViewCellSelectionStyleNone;
            return self.quietTimeEnabledCell;
        } else if (indexPath.row == QuietTimeSectionStartCell) {
            return self.fromCell;
        } else {
            return self.toCell;
        }
    } else if (indexPath.section == SectionPushEnabled) {
        if ([self shouldDisplaySystemPushLink]) {
            return self.pushSystemSettingsCell;
        } else {
            return self.pushEnabledCell;
        }
    } else if (indexPath.section == SectionAirshipLocationEnabled) {
        return self.airshipLocationEnabledCell;
    } else if (indexPath.section == SectionAnalyticsEnabled) {
        return self.analyticsEnabledCell;
    }
    return nil;
}

#pragma mark -
#pragma mark UITableVieDelegate Methods
- (void)tableView:(UITableView *)view didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == SectionPushEnabled) {

        if ([self shouldDisplaySystemPushLink]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }

    } else if (indexPath.section == SectionQuietTime) {
        if (indexPath.row == 1 || indexPath.row == 2) {
            [self updateDatePicker:YES];
        } else {
            [self updateDatePicker:NO];
        }
    }
}

#pragma mark -
#pragma mark logic

- (void)initViews {

    self.title = UAPushLocalizedString(@"UA_Push_Settings_Title");

    UISwitch *pushEnabledSwitch = self.pushEnabledSwitch;
    pushEnabledSwitch.on = [UAirship push].userPushNotificationsEnabled;
    pushEnabledSwitch.enabled = !pushEnabledSwitch.on || ![UAirship push].requireSettingsAppToDisableUserNotifications;

    if (!self.pushSystemSettingsCell) {
        self.pushSystemSettingsCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                             reuseIdentifier:nil];

        // Only display disclosure warning and accept input if we can link to settings
        if ([UIUserNotificationSettings class]) {
            self.pushSystemSettingsCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            // Do not accept any touches if we can't link to settings
            self.pushSystemSettingsCell.userInteractionEnabled = NO;
        }
        self.pushSystemSettingsCell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    self.airshipLocationEnabledSwitch.on = [UALocationService airshipLocationServiceEnabled];
    // If the switch is enabled, don't send usage data
    self.analyticsEnabledSwitch.on = ![UAirship shared].analytics.enabled;
    
    self.pushEnabledLabel.text = UAPushLocalizedString(@"UA_Push_Settings_Enabled_Label");
    self.airshipLocationEnabledLabel.text = UAPushLocalizedString(@"UA_Push_Settings_Location_Enabled_Label");
    self.analyticsEnabledLabel.text = UAPushLocalizedString(@"UA_Push_Settings_Analytics_Enabled_Label");
    self.quietTimeLabel.text = UAPushLocalizedString(@"UA_Push_Settings_Quiet_Time_Label");
    
    self.fromCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    self.toCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    self.fromCell.textLabel.text = UAPushLocalizedString(@"UA_Quiet_Time_From");
    self.toCell.textLabel.text = UAPushLocalizedString(@"UA_Quiet_Time_To");
    
    NSDate *date1 = nil;
    NSDate *date2 = nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    
    
    NSDictionary *quietTime = [[UAirship push] quietTime];
    [formatter setDateFormat:@"HH:mm"];
    self.quietTimeSwitch.on = [UAirship push].quietTimeEnabled;
    if (quietTime != nil) {
        UALOG(@"Quiet time dict found: %@ to %@", [quietTime objectForKey:@"start"], [quietTime objectForKey:@"end"]);
        date1 = [formatter dateFromString:[quietTime objectForKey:@"start"]];
        date2 = [formatter dateFromString:[quietTime objectForKey:@"end"]];
    }
    
    if (date1 == nil || date2 == nil) {
        date1 = [formatter dateFromString:@"22:00"];//default start
        date2 = [formatter dateFromString:@"07:00"];//default end
    }

    [formatter setLocale:[NSLocale currentLocale]];
    [formatter setDateStyle:NSDateFormatterNoStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    self.fromCell.detailTextLabel.text = [formatter stringFromDate:date1];
    self.toCell.detailTextLabel.text = [formatter stringFromDate:date2];

    NSDate *now = [[NSDate alloc] init];
    [self.datePicker setDate:now animated:NO];

    self.pickerDisplayed = NO;
    self.pickerShownFrame = CGRectZero;
    self.pickerHiddenFrame = CGRectZero;

    // make our existing layout work in iOS7
    if ([self respondsToSelector:NSSelectorFromString(@"edgesForExtendedLayout")]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }

    [self.view setNeedsLayout];
}

- (void)updatePickerLayout {

    CGRect viewBounds = self.view.bounds;
    
    //Manually set the size of the picker for better landscape experience
    //Older  devies do not like the custom size. It breaks the picker.
                    
    //If the picker is in a portrait container, use std portrait picker dims

    if (viewBounds.size.height >= viewBounds.size.width) {
        self.datePicker.bounds = CGRectMake(0, 0, 320, 216);
    } else {
        self.datePicker.bounds = CGRectMake(0, 0, 480, 162);
    }
    
    // reset picker subviews
    for (UIView *subview in self.datePicker.subviews) {
        subview.frame = self.datePicker.bounds;
    }
    
    // reset the visible/hidden views
    int viewOffset = self.view.frame.origin.y;
    CGRect pickerBounds = self.datePicker.bounds;
    self.pickerShownFrame = CGRectMake(0, viewOffset+viewBounds.size.height-pickerBounds.size.height,
                                  viewBounds.size.width, pickerBounds.size.height);
    self.pickerHiddenFrame = CGRectMake(0, viewOffset+viewBounds.size.height,
                                   viewBounds.size.width, pickerBounds.size.height);
    
    //reset actual frame
    if (self.pickerDisplayed) {
        self.datePicker.frame = self.pickerShownFrame;
    } else {
        self.datePicker.frame = self.pickerHiddenFrame;
    }
}

- (void)saveState {
    
    if (self.dirty) {

        if (self.pushEnabledSwitch.on) {
            [self updateQuietTime];
        }
        
        self.dirty = NO;
    }
}

- (IBAction)pickerValueChanged:(id)sender {

    self.dirty = YES;

    NSDate *date = [self.datePicker date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterNoStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    
    NSInteger row = (NSInteger)[[self.tableView indexPathForSelectedRow] row];
    if (row == QuietTimeSectionStartCell) {
        self.fromCell.detailTextLabel.text = [formatter stringFromDate:date];
        [self.fromCell setNeedsLayout];
    } else if (row == QuietTimeSectionEndCell) {
        self.toCell.detailTextLabel.text = [formatter stringFromDate:date];
        [self.toCell setNeedsLayout];
    } else {
        NSDate *now = [[NSDate alloc] init];
        [self.datePicker setDate:now animated:YES];
        return;
    }

}

- (IBAction)switchValueChanged:(id)sender {
    
    self.dirty = YES;

    // Turn push on immediately so we can reveal the
    // settings link if necessary
    UISwitch *strongPushEnabledSwitch = self.pushEnabledSwitch;
    [UAirship push].userPushNotificationsEnabled = strongPushEnabledSwitch.on;
    strongPushEnabledSwitch.enabled = !strongPushEnabledSwitch.on || ![UAirship push].requireSettingsAppToDisableUserNotifications;
    
    if (!self.quietTimeSwitch.on || !strongPushEnabledSwitch.on) {
        [self updateDatePicker:NO];
    }
    [self.tableView reloadData];
    
    if (self.airshipLocationEnabledSwitch.on) {
        [UALocationService setAirshipLocationServiceEnabled:YES];
    }
    else {
        [UALocationService setAirshipLocationServiceEnabled:NO];
    }

    if (self.analyticsEnabledSwitch.on) {
        // If switch is enabled, don't send usage data
        [UAirship shared].analytics.enabled = NO;
    } else {
        [UAirship shared].analytics.enabled = YES;
    }

}

- (void)updateDatePicker:(BOOL)show {
    
    [self updatePickerLayout];
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.4];

    UITableView *strongTableView = self.tableView;

    if (show) {
        [self.view addSubview:self.datePicker];
        self.pickerDisplayed = YES;
        self.datePicker.frame = self.pickerShownFrame;
        
        //Scroll the table view so the "To" field is just above the top of the data picker
        int scrollOffset = MAX(0, 
                               self.toCell.frame.origin.y
                               + self.toCell.frame.size.height
                               + strongTableView.sectionFooterHeight
                               - self.datePicker.frame.origin.y);
        strongTableView.contentOffset = CGPointMake(0, scrollOffset);
    } else {
        self.pickerDisplayed = NO;
        strongTableView.contentOffset = CGPointZero;//reset scroll offset
        self.datePicker.frame = self.pickerHiddenFrame;
        [strongTableView deselectRowAtIndexPath:[strongTableView indexPathForSelectedRow] animated:NO];
    }
    [UIView commitAnimations];
    
    //remove picker display after animation
    if (!self.pickerDisplayed) {
        [self.datePicker removeFromSuperview];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterNoStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    
    NSString *fromString = self.fromCell.detailTextLabel.text;
    NSString *toString = self.toCell.detailTextLabel.text;

    NSUInteger row = (NSUInteger)[[strongTableView indexPathForSelectedRow] row];
    if (row == 1 && [fromString length] != 0) {
        NSDate *fromDate = [formatter dateFromString:fromString];
        [self.datePicker setDate:fromDate animated:YES];
    } else if (row == 2 && [toString length] != 0) {
        NSDate *toDate = [formatter dateFromString:toString];
        [self.datePicker setDate:toDate animated:YES];
    }
}

- (void)updateQuietTime {
    
    if (self.quietTimeSwitch.on) {
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterNoStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        
        NSString *fromString = self.fromCell.detailTextLabel.text;
        NSString *toString = self.toCell.detailTextLabel.text;
        NSDate *fromDate = [formatter dateFromString:fromString];
        NSDate *toDate = [formatter dateFromString:toString];
                
        [UAirship push].quietTimeEnabled = YES;

        NSDateComponents *fromComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:fromDate];
        NSDateComponents *toComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:toDate];


        [[UAirship push] setQuietTimeStartHour:(NSUInteger)fromComponents.hour
                                   startMinute:(NSUInteger)fromComponents.minute
                                       endHour:(NSUInteger)toComponents.hour
                                     endMinute:(NSUInteger)toComponents.minute];

        [[UAirship push] updateRegistration];
    } else {
        [UAirship push].quietTimeEnabled = NO;
        [[UAirship push] updateRegistration];
    }


}

#pragma mark -
#pragma mark System Settings Warning/Link

/**
 * Update the text in the table cells to reflect the current push-enabled state.
 */
- (void)updateSettingsLinkText {

    // Don't update the text if the cell shouldn't be displayed
    if (![self shouldDisplaySystemPushLink]) {
        return;
    }

    UIUserNotificationType types = [[UIApplication sharedApplication] currentUserNotificationSettings].types;

    // Types are not set as desired
    // NOTE: when comparing types, always make sure userPushNotificationsEnabled == YES, otherwise
    // we might be comparing prior to registration.
    if ([UAirship push].userPushNotificationsEnabled && types == UIUserNotificationTypeNone) {
        // No user notifications are available - point to settings
        self.pushSystemSettingsCell.textLabel.text = UAPushLocalizedString(@"UA_Push_Settings_Link_Disabled_Title");
        self.pushSystemSettingsCell.detailTextLabel.text = UAPushLocalizedString(@"UA_Push_Settings_Link_Disabled_Detail");
    } else if ([UAirship push].userPushNotificationsEnabled && types != [UAirship push].userNotificationTypes) {
        // Check the current setting rather than the button on/off state to ensure we're comparing
        // the right things, as registration won't occur until after the scren closes
        //
        // Only some user notification types are available - point to settings
        self.pushSystemSettingsCell.textLabel.text = UAPushLocalizedString(@"UA_Push_Settings_Link_Partially_Disabled_Title");
        self.pushSystemSettingsCell.detailTextLabel.text = UAPushLocalizedString(@"UA_Push_Settings_Link_Partially_Disabled_Detail");
    } else {
        // Default case - things are good. Just a friendly link.
        self.pushSystemSettingsCell.textLabel.text = UAPushLocalizedString(@"UA_Push_Settings_Link_Title");
        self.pushSystemSettingsCell.detailTextLabel.text = UAPushLocalizedString(@"UA_Push_Settings_Link_Detail");
    }

    [self.tableView reloadData];
}

/**
 * Return YES if the table should include a row with a system push settings link.
 *
 * @return YES if the row should be included, otherwise NO.
 */
- (BOOL)shouldDisplaySystemPushLink {
    // If the switch is on, AND we require link to user notification settings (i.e., iOS8), let's show the toggle
    return ([UAirship push].requireSettingsAppToDisableUserNotifications && [UAirship push].userPushNotificationsEnabled);
}

- (void)openSystemPushSettings {
    if ([self shouldDisplaySystemPushLink]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }
}

@end
