/* Copyright 2017 Urban Airship and Contributors */

@import AirshipKit;

#import "AddAliasTableViewController.h"

@interface AddAliasTableViewController ()

@end

@implementation AddAliasTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.addAliasTextField.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
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
