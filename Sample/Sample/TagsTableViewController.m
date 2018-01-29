/* Copyright 2018 Urban Airship and Contributors */

@import AirshipKit;

#import "TagsTableViewController.h"

#define kUAAddTagsSegue @"addTagsSegue"

@interface TagsTableViewController ()

@end

@implementation TagsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc]
                                  initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                  target:self
                                  action:@selector(addTag:)];

    self.navigationItem.rightBarButtonItem = addButton;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView reloadData];
}

- (void)addTag:(id)sender {
    [self performSegueWithIdentifier:kUAAddTagsSegue sender:self];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [UAirship push].tags.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tagCell" forIndexPath:indexPath];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"tagCell"];
    }
    cell.textLabel.text = [UAirship push].tags[indexPath.row];

    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {

        [[UAirship push] removeTag:[tableView cellForRowAtIndexPath:indexPath].textLabel.text];

        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

        [[UAirship push] updateRegistration];
    }
}

@end
