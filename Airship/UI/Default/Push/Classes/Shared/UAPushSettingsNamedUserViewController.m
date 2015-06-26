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

#import "UAPushSettingsNamedUserViewController.h"
#import "UAPush.h"
#import "NSString+UASizeWithFontCompatibility.h"
#import "UAirship.h"

enum {
    SectionDesc        = 0,
    SectionNamedUser   = 1,
    SectionCount       = 2
};

enum {
    NamedUserSectionInputRow = 0,
    NamedUserSectionRowCount = 1
};

enum {
    DescSectionText   = 0,
    DescSectionRowCount = 1
};

@implementation UAPushSettingsNamedUserViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Device Named User";

    UITextField *strongNamedUserField = self.namedUserField;

    // Don't clear the text field pre-emptively
    strongNamedUserField.clearsOnBeginEditing = NO;
    strongNamedUserField.accessibilityLabel = @"Edit NamedUser";
    self.textLabel.text = @"Assign a named user ID to a device or a group of devices to simplify "
    @"the process of sending notifications.";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.namedUserField.text = [UAirship push].namedUser.identifier;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // This will occur before the text field finishes on its own when popping the view controller
    [self.view.window endEditing:animated];
}

#pragma mark -
#pragma mark UITableViewDelegate

#define kCellPaddingHeight 10

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == SectionDesc) {
        UILabel *strongTextLabel = self.textLabel;
        CGFloat height = [strongTextLabel.text uaSizeWithFont:strongTextLabel.font
                                            constrainedToSize:CGSizeMake(300, 1500)
                                                lineBreakMode:NSLineBreakByWordWrapping].height;
        return height + kCellPaddingHeight * 2;
    } else {
        return 44;
    }

}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    switch (section) {
        case SectionNamedUser:
            return NamedUserSectionRowCount;
        case SectionDesc:
            return DescSectionRowCount;
        default:
            break;
    }

    return 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SectionCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == SectionNamedUser) {
        return self.namedUserCell;
    } else if (indexPath.section == SectionDesc) {
        return self.textCell;
    }

    return nil;
}

#pragma mark -
#pragma mark UITextFieldDelegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    NSString *newNamedUser = self.namedUserField.text;

    // Trim leading whitespace
    NSRange range = [newNamedUser rangeOfString:@"^\\s*" options:NSRegularExpressionSearch];
    NSString *result = [newNamedUser stringByReplacingCharactersInRange:range withString:@""];

    if ([result length] != 0) {
        [UAirship push].namedUser.identifier = result;
    } else {
        textField.text = nil;
        [UAirship push].namedUser.identifier = nil;
    }
}


@end
