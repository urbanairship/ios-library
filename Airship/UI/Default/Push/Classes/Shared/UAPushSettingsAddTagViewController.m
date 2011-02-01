//
//  UAPushSettingsAddTagViewController.m
//  PushSampleLib
//
//  Created by Jeff Towle on 2/1/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "UAPushSettingsAddTagViewController.h"
#import "UAPush.h"

@implementation UAPushSettingsAddTagViewController

@synthesize tagDelegate;
@synthesize tableView;
@synthesize tagCell;
@synthesize textCell;
@synthesize textLabel;
@synthesize tagField;

- (void)dealloc {
    RELEASE_SAFELY(cancelButton);
    RELEASE_SAFELY(saveButton);
    
    [tableView release];
    [tagCell release];
    [textCell release];
    [textLabel release];
    [tagField release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"New Tag";
    
    text = @"Assign a new tag to a device or a group of devices to simplify "
    @"the process of sending notifications.";
    
    tagField.text = @"";
    textLabel.text = text;
    
    //Create an add button in the nav bar
    if (cancelButton == nil) {
        cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    }
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    if (saveButton == nil) {
        saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(save:)];
    }
    self.navigationItem.rightBarButtonItem = saveButton;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

#pragma mark -
#pragma mark UITableViewDelegate

#define kCellPaddingHeight 10

// TODO: text?
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 44;
    } else {
        CGFloat height = [text sizeWithFont:textLabel.font
                          constrainedToSize:CGSizeMake(300, 1500)
                              lineBreakMode:UILineBreakModeWordWrap].height;
        return height + kCellPaddingHeight * 2;
    }
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        //tagField.text = [UAPush shared].alias;
        return tagCell;
    } else {
        textLabel.text = text;
        return textCell;
    }
}

#pragma mark -
#pragma mark UITextFieldDelegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
//    NSString *newAlias = aliasField.text;
//    if ([newAlias length] != 0) {
//        [UAPush shared].alias = newAlias;
//    }
}

#pragma mark -
#pragma mark Save/Cancel

- (void)save:(id)sender {
    
//    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:addTagController];
//    [[self navigationController] presentModalViewController:navigationController animated:YES];
//    [navigationController release];
//    [[UAPush shared].tags addObject:tagField.text];
//    [[UAPush shared] updateRegistration];
//    
//    [[self navigationController] dismissModalViewControllerAnimated:YES];
    [tagDelegate addTag:tagField.text];
    tagField.text = nil;
}

- (void)cancel:(id)sender {
    
    //    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:addTagController];
    //    [[self navigationController] presentModalViewController:navigationController animated:YES];
    //    [navigationController release];
    //[[self navigationController] dismissModalViewControllerAnimated:YES];
    [tagDelegate cancelAddTag];
    tagField.text = nil;
}
    

@end
