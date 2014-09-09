/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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

#import <UIKit/UIKit.h>

@interface UAPushSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, weak) IBOutlet UITableView *tableView;

// The datePicker IBOutlet needs to be strong because it is removed from the view
// when both 'Push Enabled' and 'Quiet Time' is set to false. It needs to be
// re-created and added back to the view when both 'Push Enabled' and 'Quiet Time'
// is set to true.
@property (nonatomic, strong) IBOutlet UIDatePicker *datePicker;
@property (nonatomic, assign) CGRect pickerShownFrame;
@property (nonatomic, assign) CGRect pickerHiddenFrame;

// The pushEnabledCell IBOutlet needs to be strong because it has to be
// re-created and added back to the view for iOS 6.
@property (nonatomic, strong) IBOutlet UITableViewCell *pushEnabledCell;
@property (nonatomic, weak) IBOutlet UILabel *pushEnabledLabel;
@property (nonatomic, weak) IBOutlet UISwitch *pushEnabledSwitch;

// This cell provides a link to the app's system settings on iOS8
@property (nonatomic, strong) UITableViewCell *pushSystemSettingsCell;

// These quiet time IBOutlets needs to be strong because they are removed from
// the table view when 'Push Enabled' is set to false. When 'Push Enabled' is
// set to true, they need to be re-created and added back to the table view.
@property (nonatomic, strong) IBOutlet UITableViewCell *quietTimeEnabledCell;
@property (nonatomic, strong) IBOutlet UILabel *quietTimeLabel;
@property (nonatomic, strong) IBOutlet UISwitch *quietTimeSwitch;
@property (nonatomic, strong) UITableViewCell *fromCell;
@property (nonatomic, strong) UITableViewCell *toCell;

// The airshipLocationEnabledCell IBOutlet needs to be strong because it has
// to be re-created and added back to the view for iOS 6.
@property (nonatomic, strong) IBOutlet UITableViewCell *airshipLocationEnabledCell;
@property (nonatomic, weak) IBOutlet UISwitch *airshipLocationEnabledSwitch;
@property (nonatomic, weak) IBOutlet UILabel *airshipLocationEnabledLabel;



@property (nonatomic, assign) BOOL dirty;
@property (nonatomic, assign) BOOL pickerDisplayed;

/**
 * Saves settings changed by the user.
 */
- (void)saveState;

- (IBAction)pickerValueChanged:(id)sender;
- (IBAction)switchValueChanged:(id)sender;

// Private Methods
- (void)initViews;
- (void)updatePickerLayout;
- (void)updateDatePicker:(BOOL)show;
- (void)updateQuietTime;


@end
