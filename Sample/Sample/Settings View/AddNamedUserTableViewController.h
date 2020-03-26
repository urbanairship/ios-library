/* Copyright Airship and Contributors */

@import UIKit;

@interface AddNamedUserTableViewController : UITableViewController<UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITableViewCell *addNamedUserCell;

@property (weak, nonatomic) IBOutlet UILabel *addNamedUserTitle;

@property (weak, nonatomic) IBOutlet UITextField *addNamedUserTextField;

@end
