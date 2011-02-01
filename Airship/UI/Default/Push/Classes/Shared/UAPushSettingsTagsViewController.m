//
//  UAPushSettingsTagsViewController.m
//  PushSampleLib
//
//  Created by Jeff Towle on 1/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "UAPushSettingsTagsViewController.h"
#import "UAPushSettingsAddTagViewController.h"
#import "UAPush.h"

@implementation UAPushSettingsTagsViewController


#pragma mark -
#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    

    
    
    //Create an add button in the nav bar
    if (addButton == nil) {
        addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addItem:)];
    }
    self.navigationItem.rightBarButtonItem = addButton;
}

- (void)viewWillAppear:(BOOL)animated {
    
    [self setEditing:YES];
    
    [super viewWillAppear:animated];
}

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/
/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [[UAPush shared].tags count];//tags plus an "add" row
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell;
    
    /////////////
    
    static NSString *CellIdentifier = @"Cell";
    
    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell...
    
    cell.textLabel.text = [[UAPush shared].tags objectAtIndex:indexPath.row];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}




// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        
        
        // Delete the row from the data source.
        NSString *tagToDelete = [[UAPush shared].tags objectAtIndex:indexPath.row];
        [[UAPush shared].tags removeObjectAtIndex:indexPath.row];
        
        // Delete the row from the view
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        
        // Commit to server
        [[UAPush shared] removeTagFromCurrentDevice:tagToDelete];
    }
}



/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    /*
    <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
    // ...
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:detailViewController animated:YES];
    [detailViewController release];
    */
}

#pragma mark -
#pragma mark Add Item

- (void)addItem:(id)sender {
    
    if (addTagController == nil) {
        addTagController = [[UAPushSettingsAddTagViewController alloc] init];
        addTagController.tagDelegate = self;
    }
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:addTagController];
    [[self navigationController] presentModalViewController:navigationController animated:YES];
    [navigationController release];
}


 - (void)addTag:(NSString *)tag {
     
     [[self navigationController] dismissModalViewControllerAnimated:YES];
     
     if ([[UAPush shared].tags containsObject:tag]) {
         UALOG(@"Tag %@ already exists.", tag);
         return;
     }
     
     NSInteger index = [[UAPush shared].tags count];
     
     
     [[UAPush shared].tags insertObject:tag atIndex:index];
     
     NSArray *indexArray = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:index inSection:0]];
     

     
     
     [self.tableView insertRowsAtIndexPaths:indexArray withRowAnimation:UITableViewRowAnimationTop];
 }
 
 - (void)cancelAddTag {
     [[self navigationController] dismissModalViewControllerAnimated:YES];
 }
     
#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
    
    [super viewDidUnload];
    RELEASE_SAFELY(addButton);
}


- (void)dealloc {
    
    RELEASE_SAFELY(addButton);
    RELEASE_SAFELY(addTagController);
    
    [super dealloc];
}


@end

