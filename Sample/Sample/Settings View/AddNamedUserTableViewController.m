/* Copyright Airship and Contributors */

@import AirshipCore;
@import AirshipLocation;

#import "AddNamedUserTableViewController.h"

@implementation AddNamedUserTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.addNamedUserTextField.delegate = self;
}

- (void)setCellTheme {
    self.addNamedUserCell.backgroundColor = [UIColor whiteColor];
    self.addNamedUserTitle.textColor = [UIColor blackColor];
    self.addNamedUserTextField.textColor = [UIColor blackColor];
}

- (void)setTableViewTheme {
    self.tableView.backgroundColor = [UIColor whiteColor];
    
    [self.navigationController.navigationBar setTitleTextAttributes: @{NSForegroundColorAttributeName:[UIColor whiteColor]}];
    self.navigationController.navigationBar.barTintColor = [UIColor blackColor];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setCellTheme];
    [self setTableViewTheme];
    
    if (UAirship.contact.namedUserID != nil) {
        self.addNamedUserTextField.text = UAirship.contact.namedUserID;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)textFieldShouldReturn: (UITextField *)textField {
    if (textField.text != nil && textField.text.length > 0) {
        [UAirship.contact identify:textField.text];
    } else {
        [UAirship.contact reset];
    }
    
    [self.view endEditing:YES];
    
    [UAirship.channel updateRegistration];
    
    return [self.navigationController popViewControllerAnimated:YES] != nil;
}

@end
