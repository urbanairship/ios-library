/* Copyright 2017 Urban Airship and Contributors */

@import AirshipKit;
#import "AddTagsTableViewController.h"

@interface AddTagsTableViewController ()

@end

@implementation AddTagsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.addCustomTagTextField.delegate = self;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {

    [self.view endEditing:YES];

    NSString *newTag = self.addCustomTagTextField.text;

    // Trim leading whitespace
    NSRange range = [newTag rangeOfString:@"^\\s*" options:NSRegularExpressionSearch];
    NSString *result = [newTag stringByReplacingCharactersInRange:range withString:@""];

    if (result.length) {
        [[UAirship push] addTag:newTag];
    } else {
        return NO;
    }

    [[UAirship push] updateRegistration];

    UINavigationController *navigationController = (UINavigationController *) self.parentViewController;
    [navigationController popViewControllerAnimated:YES];

    return YES;
}

@end
