/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAInboxMessageListController.h"
#import "UAInboxMessageListCell.h"
#import "UABarButtonSegmentedControl.h"
#import "UAInboxUI.h"
#import "UAInboxMessageViewController.h"
#import "UAInbox.h"
#import "UAGlobal.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"

@implementation UAInboxMessageListController

@synthesize activity;
@synthesize loadingLabel, noMessagesLabel;
@synthesize messageTable;
@synthesize tabbar, tabbarItem;

- (void)dealloc {
    
    RELEASE_SAFELY(cellNibName);
    RELEASE_SAFELY(cellReusableId);
    RELEASE_SAFELY(messageTable);
    RELEASE_SAFELY(activity);
    RELEASE_SAFELY(loadingLabel);
    RELEASE_SAFELY(noMessagesLabel);
    RELEASE_SAFELY(selectedIndexPathsForEditing);
    RELEASE_SAFELY(deleteItem);
    RELEASE_SAFELY(moveItem);
    RELEASE_SAFELY(editItem);
    RELEASE_SAFELY(cancelItem);
    RELEASE_SAFELY(tabbar);
    RELEASE_SAFELY(tabbarItem);
    RELEASE_SAFELY(badgeView);
    
    [super dealloc];
}

- (void)initNibNames {
    cellReusableId = [@"UAInboxMessageListCell" retain];
    cellNibName = [@"UAInboxMessageListCell" retain];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [self initNibNames];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    loadingLabel.text = UA_INBOX_TR(@"UA_Loading");
    noMessagesLabel.text = UA_INBOX_TR(@"UA_No_Messages");
    
    editItem = [[UIBarButtonItem alloc]
                initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                target:self
                action:@selector(editButtonPressed:)];
    cancelItem = [[UIBarButtonItem alloc]
                  initWithTitle:UA_INBOX_TR(@"UA_Cancel")
                  style:UIBarButtonItemStyleDone
                  target:self
                  action:@selector(cancelButtonPressed:)];

    self.navigationItem.rightBarButtonItem = editItem;

    [self createToolbarItems];
    [self createNavigationBadge];

    selectedIndexPathsForEditing = [[NSMutableSet alloc] init];
    
    [UAInbox loadInbox];
}

- (void)createToolbarItems {
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                                target:nil action:nil];
    fixedSpace.width = 0;
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                   target:nil action:nil];
    flexibleSpace.width = 25;

    deleteItem = [[UABarButtonSegmentedControl alloc]
                  initWithItems:[NSArray arrayWithObject:UA_INBOX_TR(@"UA_Delete")]];
    deleteItem.frame = CGRectMake(0, 0, 130, 30);
    deleteItem.segmentedControlStyle = UISegmentedControlStyleBar;
    deleteItem.momentary = NO;
    deleteItem.selectedSegmentIndex = UISegmentedControlNoSegment;
    [deleteItem addTarget:self action:@selector(batchUpdateButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [deleteItem addTarget:self action:@selector(batchUpdateButtonCanceled:) forControlEvents:UIControlEventTouchUpOutside];
    deleteItem.tintColor = [UIColor colorWithRed:0.70 green:0.171 blue:0.1 alpha:1.0];

    UIBarButtonItem *deleteButton = [[[UIBarButtonItem alloc] initWithCustomView:deleteItem] autorelease];
    deleteButton.width = 130;
    moveItem = [[UIBarButtonItem alloc] initWithTitle:UA_INBOX_TR(@"UA_Mark_as_Read")
                                                style:UIBarButtonItemStyleBordered
                                               target:self action:@selector(batchUpdateButtonPressed:)];
    moveItem.width = 130;

    self.toolbarItems = [NSArray arrayWithObjects:fixedSpace, deleteButton, flexibleSpace, moveItem, fixedSpace, nil];

    [fixedSpace release];
    [flexibleSpace release];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[UAInbox shared].messageList addObserver:self];
    
    [messageTable deselectRowAtIndexPath:[messageTable indexPathForSelectedRow] animated:animated];
    [self.navigationController.navigationBar addSubview:badgeView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[UAInbox shared].messageList removeObserver:self];
    
    [badgeView removeFromSuperview];
}

- (void)viewDidUnload {
    // Release any retained subviews of the main view.
    self.activity = nil;
    self.loadingLabel = nil;
    self.noMessagesLabel = nil;
    self.messageTable = nil;
    [selectedIndexPathsForEditing removeAllObjects];
    RELEASE_SAFELY(selectedIndexPathsForEditing);
    RELEASE_SAFELY(deleteItem);
    RELEASE_SAFELY(moveItem);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

// For batch update/delete
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.navigationController setToolbarHidden:!editing animated:animated];
    [messageTable setEditing:editing animated:animated];
}

- (void)tableReloadData {
    [messageTable reloadData];
    [messageTable deselectRowAtIndexPath:[messageTable indexPathForSelectedRow] animated:NO];
}

#pragma mark -
#pragma mark Button Action Methods

- (void)editButtonPressed:(id)sender {
    
    self.navigationItem.leftBarButtonItem.enabled = NO;
    
    if ([UAInboxMessageList shared].isBatchUpdating) {
        return;
    }
    
    self.navigationItem.rightBarButtonItem = cancelItem;
    [messageTable deselectRowAtIndexPath:[messageTable indexPathForSelectedRow] animated:YES];
    [self setEditing:YES animated:YES];
    // refresh need to be called after setEdit, because in iPad platform,
    // the trash button is decided by the table list's edit status.
    [self refreshBatchUpdateButtons];
}

- (void)cancelButtonPressed:(id)sender {
    
    self.navigationItem.leftBarButtonItem.enabled = YES;
    
    self.navigationItem.rightBarButtonItem = editItem;

    if ([selectedIndexPathsForEditing count] > 0) {
        NSSet *visibleCells = [NSSet setWithArray:[messageTable indexPathsForVisibleRows]];
        [selectedIndexPathsForEditing intersectSet:visibleCells];

        for (NSIndexPath *indexPath in selectedIndexPathsForEditing) {
            [messageTable cellForRowAtIndexPath:indexPath].selected = NO;
        }

        [selectedIndexPathsForEditing removeAllObjects];
    }

    [self setEditing:NO animated:YES];
    [self updateNavigationBadge];
}

- (void)batchUpdateButtonPressed:(id)sender {
    NSMutableIndexSet *messageIDs = [NSMutableIndexSet indexSet];
    for (NSIndexPath *indexPath in selectedIndexPathsForEditing) {
        [messageIDs addIndex:indexPath.row];
    }

    cancelItem.enabled = NO;

    if (sender == moveItem) {
        if ([[UAInbox shared].messageList batchUpdate:messageIDs option:UABatchReadMessages] != YES) {
            UALOG(@"Server is busy, please try later.");
        }
    } else {
        if ([[UAInbox shared].messageList batchUpdate:messageIDs option:UABatchDeleteMessages] != YES) {
            UALOG(@"Server is busy, please try later.");
        }
    }

    deleteItem.selectedSegmentIndex = UISegmentedControlNoSegment;
    [self refreshBatchUpdateButtons];
}

- (void)batchUpdateButtonCanceled:(id)sender {
    deleteItem.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)refreshBatchUpdateButtons {
    NSString* deleteStr = UA_INBOX_TR(@"UA_Delete");
    NSString* markReadStr = UA_INBOX_TR(@"UA_Mark_as_Read");

    NSUInteger count = [selectedIndexPathsForEditing count];
    if (count == 0) {
        [deleteItem setTitle:deleteStr forSegmentAtIndex:0];
        moveItem.title = markReadStr;
        deleteItem.enabled = NO;
        moveItem.enabled = NO;
    } else {
        [deleteItem setTitle:[NSString stringWithFormat:@"%@ (%d)", deleteStr, count] forSegmentAtIndex:0];
        moveItem.title = [NSString stringWithFormat:@"%@ (%d)", markReadStr, count];
        if ([UAInbox shared].messageList.isBusying) {
            deleteItem.enabled = NO;
            moveItem.enabled = NO;
        } else {
            deleteItem.enabled = YES;
            moveItem.enabled = YES;
        }
    }
}

- (void)deleteMessageAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
    [set addIndex:indexPath.row];
    [selectedIndexPathsForEditing removeAllObjects];
    [selectedIndexPathsForEditing addObject:indexPath];
    [[UAInbox shared].messageList batchUpdate:set
                                       option:UABatchDeleteMessages];
    [self refreshBatchUpdateButtons];
}

#pragma mark -
#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UAInboxMessageListCell* cell = (UAInboxMessageListCell*)[tableView dequeueReusableCellWithIdentifier:cellReusableId];
    if (cell == nil) {
        NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:cellNibName owner: nil options: nil];
        cell = [topLevelObjects objectAtIndex:0];
    }

    [cell setData:[[UAInbox shared].messageList messageAtIndex:indexPath.row]];

    cell.editing = tableView.editing;
    if (cell.editing) {
        cell.selected = [selectedIndexPathsForEditing containsObject:indexPath];
    } else {
        NSIndexPath *selectedPath = [tableView indexPathForSelectedRow];
        cell.selected = (selectedPath ? selectedPath.row == indexPath.row : NO);
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    [self deleteMessageAtIndexPath:indexPath];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    int messageCount = [[UAInbox shared].messageList messageCount];
    editItem.enabled = (messageCount == 0) ? NO : YES;
    return messageCount;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing)
        return UITableViewCellEditingStyleNone;
    else
        return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    self.navigationItem.rightBarButtonItem.enabled = YES;
}


#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing && ![[UAInbox shared].messageList isBatchUpdating]) {
        if ([selectedIndexPathsForEditing containsObject:indexPath]) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            [selectedIndexPathsForEditing removeObject:indexPath];
        } else {
            [selectedIndexPathsForEditing addObject:indexPath];
        }
        [self refreshBatchUpdateButtons];
        [[tableView cellForRowAtIndexPath:indexPath] setNeedsLayout];
    } else if (!self.editing) {
        [self didSelectRowAtIndexPath:indexPath];
    }
}

- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UAInboxMessageViewController *mvc = [[[UAInboxMessageViewController alloc] initWithNibName:@"UAInboxMessageViewController" bundle:nil] autorelease];
    [mvc loadMessageAtIndex:indexPath.row];
    [self.navigationController pushViewController:mvc animated:YES];
}

#pragma mark -
#pragma mark UAInboxMessageListObserver

- (void)messageListWillLoad {
    [activity startAnimating];
    loadingLabel.hidden = NO;
    noMessagesLabel.hidden = YES;
}

- (void)messageListLoaded {
	
	UALOG(@"got messageListLoaded");
	
    [activity stopAnimating];
    loadingLabel.hidden = YES;
    int messageCount = [[UAInbox shared].messageList messageCount];
    noMessagesLabel.hidden = (messageCount != 0);

	// TODO: add call to pushhandler here to get the messageid we should be viewing????
	//[UAInboxUI displayMessage:viewingMessageID];
	
    [self tableReloadData];
    [self updateNavigationBadge];
}

- (void)inboxError:(NSString *)message {
    [activity stopAnimating];
    loadingLabel.hidden = YES;
    UALOG(@"inboxError");
}

- (void)inboxLoadFailed {
    [activity stopAnimating];
    loadingLabel.hidden = YES;
    [self tableReloadData];
    [self updateNavigationBadge];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Mailbox_Error_Title")
                                                    message:UA_INBOX_TR(@"UA_Error_Fetching_Message_List")
                                                   delegate:nil
                                          cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

- (void)messagesDidUpateWithOption:(id)option {
    if ([option intValue] == UABatchDeleteMessagesSuccess) {
        [messageTable beginUpdates];
        [messageTable deleteRowsAtIndexPaths:[selectedIndexPathsForEditing allObjects]
                            withRowAnimation:UITableViewRowAnimationLeft];
        [messageTable endUpdates];

    } else if ([option intValue] == UABatchReadMessagesSuccess) {
        [messageTable reloadRowsAtIndexPaths:[selectedIndexPathsForEditing allObjects]
                            withRowAnimation:UITableViewRowAnimationNone];
    } else if ([option intValue] == UABatchReadMessagesFailed) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Mailbox_Error_Title")
                                                        message:UA_INBOX_TR(@"UA_Error_Mark_Read_Message")
                                                       delegate:nil
                                              cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else if ([option intValue] == UABatchDeleteMessagesFailed) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Mailbox_Error_Title")
                                                        message:UA_INBOX_TR(@"UA_Error_Delete_Message")
                                                       delegate:nil
                                              cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    }

    [activity stopAnimating];
    loadingLabel.hidden = YES;
    int messageCount = [[UAInbox shared].messageList messageCount];
    noMessagesLabel.hidden = (messageCount != 0);
    
    [selectedIndexPathsForEditing removeAllObjects];
    cancelItem.enabled = YES;
    [self cancelButtonPressed:nil];
    
    [messageTable deselectRowAtIndexPath:[messageTable indexPathForSelectedRow] animated:NO];
    
    [self refreshBatchUpdateButtons];
}

- (void)singleMessageMarkAsReadFinished:(id)m {
    int row = [[UAInbox shared].messageList indexOfMessage:(UAInboxMessage *)m];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    UAInboxMessageListCell *cell = (UAInboxMessageListCell *)[self.messageTable cellForRowAtIndexPath:indexPath];
    cell.unreadIndicator.hidden = YES;
    [self updateNavigationBadge];
}

#pragma mark -
#pragma mark Navigation Bar Badge

static float label_width = 0.0;
- (void)createNavigationBadge {
    // Create a label to test the size of the title string, so we can determine
    // where to place the unread count badge.
    float badgePosition = self.navigationController.navigationBar.frame.size.width/2 + label_width/2 - 33;

    UILabel *testLabel = [[[UILabel alloc] init] autorelease];

    testLabel.text = self.title;
    testLabel.font = [UIFont boldSystemFontOfSize:20];
    [testLabel sizeToFit];
    label_width = testLabel.frame.size.width;

    badgeView = [[UIView alloc] initWithFrame:CGRectMake(badgePosition, 4, 100, 34)];
    badgeView.backgroundColor = [UIColor clearColor];
    badgeView.clipsToBounds = NO;

    //TODO: MACRO-ize this properly
    if ([tabbarItem respondsToSelector:@selector(finishedSelectedImage)]) { //HACK!!
        //if ios5
        tabbar.tintColor = [UIColor clearColor];
        [badgeView addSubview:[tabbar.subviews objectAtIndex:1]];
    } else {
        //if < ios5
        [badgeView addSubview:[((UIView *)[tabbar.subviews objectAtIndex:0]).subviews objectAtIndex:0]];
    }

    badgeView.hidden = YES;
}

- (void)updateNavigationBadge {
    int count = [UAInbox shared].messageList.unreadCount;
    NSString *unreadCount = [NSString stringWithFormat:@"%d", count];
    float badgePosition = self.navigationController.navigationBar.frame.size.width/2 + label_width/2 - 33;

    if (count < 0)
        count = 0;
    badgeView.hidden = (count==0);
    tabbarItem.badgeValue = unreadCount;
    badgeView.frame = CGRectMake(badgePosition + 5.3*([unreadCount length]-1),
                                 badgeView.frame.origin.y,
                                 badgeView.frame.size.width,
                                 badgeView.frame.size.height);
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration{
    [self updateNavigationBadge];
}


@end
