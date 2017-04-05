/* Copyright 2017 Urban Airship and Contributors */

@import AirshipKit;

#import "AddNamedUserTableViewController.h"

@interface AddNamedUserTableViewController ()

@end

@implementation AddNamedUserTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.addNamedUserTextField.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if ([UAirship namedUser].identifier) {
        self.addNamedUserTextField.text = [UAirship namedUser].identifier;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    [self.view endEditing:YES];

    NSString *newNamedUser = self.addNamedUserTextField.text;

    // Trim leading whitespace
    NSRange range = [newNamedUser rangeOfString:@"^\\s*" options:NSRegularExpressionSearch];
    NSString *result = [newNamedUser stringByReplacingCharactersInRange:range withString:@""];

    if (result.length) {
        [UAirship namedUser].identifier = result;
    } else {
        textField.text = nil;
        [UAirship namedUser].identifier = nil;
    }

    [[UAirship push] updateRegistration];

    UINavigationController *navigationController = (UINavigationController *) self.parentViewController;
    [navigationController popViewControllerAnimated:YES];

    return YES;
}

@end
