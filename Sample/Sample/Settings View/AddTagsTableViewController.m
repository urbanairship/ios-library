/* Copyright Airship and Contributors */

@import AirshipCore;
@import AirshipLocation;

#import "AddTagsTableViewController.h"

@interface AddTagsTableViewController ()

@property (weak, nonatomic) NSString *textFieldText;

@end

@implementation AddTagsTableViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    self.addCustomTagTextField.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.textFieldText != nil && self.textFieldText.length != 0) {
        [self updateTagsWithTag:self.textFieldText];
    }
}

- (void)setCellTheme {
   self.tableView.backgroundColor = [UIColor whiteColor];
    self.addCustomTagCell.backgroundColor = [UIColor whiteColor];
    self.addTagTitle.textColor = [UIColor blackColor];
    self.addCustomTagTextField.textColor = [UIColor blackColor];
    self.addCustomTagTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTable(@"ua_device_info_tag", @"UAPushUI", @"Tag") attributes:@{NSForegroundColorAttributeName: [UIColor grayColor]}];
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
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)textFieldDidChangeSelection:(UITextField *)textField {
    self.textFieldText = textField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.text == nil || textField.text.length == 0) {
        return NO;
    }

    [self updateTagsWithTag:textField.text];

    [self.view endEditing:YES];

    
    return [self.navigationController popViewControllerAnimated:YES] != nil;
}

- (void)updateTagsWithTag:(NSString *)tagString {
    UATagEditor *tagEditor = [UAirship.channel editTags];
    [tagEditor addTag:tagString];
    [tagEditor apply];
    [UAirship.channel updateRegistration];
}

@end
