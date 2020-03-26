/* Copyright Airship and Contributors */

@import UIKit;

@interface AddTagsTableViewController : UITableViewController <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITableViewCell *addCustomTagCell;

@property (weak, nonatomic) IBOutlet UILabel *addTagTitle;

@property (weak, nonatomic) IBOutlet UITextField *addCustomTagTextField;

@end
