/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

// Import the Urban Airship umbrella header using the framework
#import <AirshipKit/AirshipKit.h>
#import "AddAliasTableViewController.h"

@interface AddAliasTableViewController ()

@end

@implementation AddAliasTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.addAliasTextField.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    if ([UAirship push].alias) {
        self.addAliasTextField.text = [UAirship push].alias;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    [self.view endEditing:YES];

    NSString *newAlias = self.addAliasTextField.text;

    // Trim leading whitespace
    NSRange range = [newAlias rangeOfString:@"^\\s*" options:NSRegularExpressionSearch];
    NSString *result = [newAlias stringByReplacingCharactersInRange:range withString:@""];

    if (result.length) {
        [UAirship push].alias = result;
    } else {
        textField.text = nil;
        [UAirship push].alias = nil;
    }

    [[UAirship push] updateRegistration];

    UINavigationController *navigationController = (UINavigationController *) self.parentViewController;
    [navigationController popViewControllerAnimated:YES];

    return YES;
}

@end
