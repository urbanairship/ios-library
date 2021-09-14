/* Copyright Airship and Contributors */

@import AirshipCore;
@import AirshipLocation;

#import "TagsTableViewController.h"

@implementation TagsTableViewController

NSString *addTagsSegue = @"addTagsSegue";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem* addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTag)];
    
    self.navigationItem.rightBarButtonItem = addButton;
}

- (void)setTableViewTheme{
    self.tableView.backgroundColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes: @{NSForegroundColorAttributeName:[UIColor whiteColor]}];
    self.navigationController.navigationBar.barTintColor = [UIColor blackColor];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:(animated)];
    [self.tableView reloadData];
}

- (void)addTag {
    [self performSegueWithIdentifier:addTagsSegue sender:self];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return UAirship.channel.tags.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"tagCell";
    
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"tagCell"];
    }
    cell.textLabel.text = UAirship.channel.tags[indexPath.row];
    cell.textLabel.textColor = [UIColor blackColor];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.51 green:0.51 blue:0.53 alpha:1.0];
    cell.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && [tableView cellForRowAtIndexPath:indexPath].textLabel.text != nil) {
        UATagEditor *tagEditor = [UAirship.channel editTags];
        [tagEditor removeTag:[tableView cellForRowAtIndexPath:indexPath].textLabel.text];
        [tagEditor apply];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation: UITableViewRowAnimationFade];
    }
}

@end
