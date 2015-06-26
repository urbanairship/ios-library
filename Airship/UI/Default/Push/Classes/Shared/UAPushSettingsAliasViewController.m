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

#import "UAPushSettingsAliasViewController.h"
#import "UAPush.h"
#import "NSString+UASizeWithFontCompatibility.h"
#import "UAirship.h"

enum {
    SectionDesc        = 0,
    SectionAlias       = 1,
    SectionCount       = 2
};

enum {
    AliasSectionInputRow = 0,
    AliasSectionRowCount = 1
};

enum {
    DescSectionText   = 0,
    DescSectionRowCount = 1
};

@implementation UAPushSettingsAliasViewController


- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Device Alias";

    UITextField *strongAliasField = self.aliasField;

    // Don't clear the text field pre-emptively
    strongAliasField.clearsOnBeginEditing = NO;
    strongAliasField.accessibilityLabel = @"Edit Alias";
    self.textLabel.text = @"Assign an alias to a device or a group of devices to simplify "
                     @"the process of sending notifications.";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.aliasField.text = [UAirship push].alias;
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
        case SectionAlias:
            return AliasSectionRowCount;
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
    
    if (indexPath.section == SectionAlias) {
        return self.aliasCell;
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
    
    NSString *newAlias = self.aliasField.text;

    // Trim leading whitespace
    NSRange range = [newAlias rangeOfString:@"^\\s*" options:NSRegularExpressionSearch];
    NSString *result = [newAlias stringByReplacingCharactersInRange:range withString:@""];

    if ([result length] != 0) {
        [[UAirship push] setAlias:result];
        [[UAirship push] updateRegistration];
    } else {
        textField.text = nil;
        [[UAirship push] setAlias:nil];
        [[UAirship push] updateRegistration];
    }
}

@end
