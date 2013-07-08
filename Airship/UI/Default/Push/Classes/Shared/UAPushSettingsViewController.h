/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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

@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) IBOutlet UIDatePicker *datePicker;
@property (nonatomic, assign) CGRect pickerShownFrame;
@property (nonatomic, assign) CGRect pickerHiddenFrame;


@property (nonatomic, retain) IBOutlet UITableViewCell *pushEnabledCell;
@property (nonatomic, retain) IBOutlet UILabel *pushEnabledLabel;
@property (nonatomic, retain) IBOutlet UISwitch *pushEnabledSwitch;

@property (nonatomic, retain) IBOutlet UITableViewCell *quietTimeEnabledCell;
@property (nonatomic, retain) IBOutlet UILabel *quietTimeLabel;
@property (nonatomic, retain) IBOutlet UISwitch *quietTimeSwitch;
@property (nonatomic, retain) UITableViewCell *fromCell;
@property (nonatomic, retain) UITableViewCell *toCell;

@property (nonatomic, retain) IBOutlet UISwitch *airshipLocationEnabledSwitch;
@property (nonatomic, retain) IBOutlet UILabel *airshipLocationEnabledLabel;
@property (nonatomic, retain) IBOutlet UITableViewCell *airshipLocationEnabledCell;


@property (nonatomic, assign) BOOL dirty;
@property (nonatomic, assign) BOOL pickerDisplayed;


- (IBAction)quit;
- (IBAction)pickerValueChanged:(id)sender;
- (IBAction)switchValueChanged:(id)sender;

// Private Methods
- (void)initViews;
- (void)updatePickerLayout;
- (void)updateDatePicker:(BOOL)show;
- (void)updateQuietTime;


@end
