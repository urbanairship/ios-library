/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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

@interface UAInboxMessageListController()

- (void)updateNavigationBadge;      // indicate title and unread count
- (void)refreshBatchUpdateButtons;  // indicate edit mode view
- (void)deleteMessageAtIndexPath:(NSIndexPath *)indexPath;
- (void)createToolbarItems;
- (void)createNavigationBadge;
- (void)editButtonPressed:(id)sender;
- (void)cancelButtonPressed:(id)sender;
- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableReloadData;
- (void)coverUpEmptyListIfNeeded;
- (void)showLoadingScreen;
- (void)hideLoadingScreen;
- (UAInboxMessage *)messageForIndexPath:(NSIndexPath *)indexPath;

- (void)updateSetOfUnreadMessagesWithMessage:(UAInboxMessage *)message atIndexPath:(NSIndexPath *)indexPath;
- (BOOL)checkSetOfIndexPaths:(NSSet *)setOfPaths forIndexPath:(NSIndexPath *)indexPath;
- (NSUInteger) countOfUnreadMessagesInSetOfIndexPaths:(NSSet *)set;

@property (nonatomic, retain) IBOutlet UITableView *messageTable;
@property (nonatomic, retain) IBOutlet UIView *loadingView;
@property (nonatomic, retain) IBOutlet UABeveledLoadingIndicator *loadingIndicator;
@property (nonatomic, retain) IBOutlet UILabel *loadingLabel;
@property (nonatomic, retain) IBOutlet UITabBarItem *tabbarItem;
@property (nonatomic, retain) IBOutlet UITabBar *tabbar;
@property (nonatomic, retain) NSMutableSet *setOfUnreadMessagesInSelection;
@property (nonatomic, retain) UIView *badgeView;
@property (nonatomic, retain) NSMutableSet *selectedIndexPathsForEditing;
@property (nonatomic, retain) UABarButtonSegmentedControl *deleteItem;
@property (nonatomic, retain) UIBarButtonItem *markAsReadButtonItem;
@property (nonatomic, retain) UIBarButtonItem *editItem;
@property (nonatomic, retain) UIBarButtonItem *cancelItem;
@property (nonatomic, retain) NSString *cellReusableId;
@property (nonatomic, retain) NSString *cellNibName;

@end

@implementation UAInboxMessageListController

- (void)dealloc {
    self.messageTable = nil;
    self.loadingView = nil;
    self.loadingIndicator = nil;
    self.loadingLabel = nil;
    self.tabbarItem = nil;
    self.tabbar = nil;
    self.setOfUnreadMessagesInSelection = nil;
    self.badgeView = nil;
    self.selectedIndexPathsForEditing = nil;
    self.deleteItem = nil;

    self.markAsReadButtonItem = nil;
    self.editItem = nil;
    self.cancelItem = nil;
    self.cellReusableId = nil;
    self.cellNibName = nil;

    [super dealloc];
}

- (void)initNibNames {
    self.cellReusableId = [@"UAInboxMessageListCell" retain];
    self.cellNibName = [@"UAInboxMessageListCell" retain];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [self initNibNames];
        
        self.shouldShowAlerts = YES;

        // make our existing layout work beyond iOS6
        if ([self respondsToSelector:NSSelectorFromString(@"edgesForExtendedLayout")]) {
            [self setValue:[NSNumber numberWithInt:0] forKey:@"edgesForExtendedLayout"];
        }
    }    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.editItem = [[UIBarButtonItem alloc]
                initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                target:self
                action:@selector(editButtonPressed:)];
    self.cancelItem = [[UIBarButtonItem alloc]
                  initWithTitle:UA_INBOX_TR(@"UA_Cancel")
                  style:UIBarButtonItemStyleDone
                  target:self
                  action:@selector(cancelButtonPressed:)];

    self.navigationItem.rightBarButtonItem = self.editItem;

    [self createToolbarItems];
    [self createNavigationBadge];

    self.selectedIndexPathsForEditing = [[[NSMutableSet alloc] init] autorelease];
}

- (void)createToolbarItems {
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                                target:nil action:nil];
    fixedSpace.width = 0;
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                   target:nil action:nil];
    flexibleSpace.width = 25;

    self.deleteItem = [[[UABarButtonSegmentedControl alloc]
                        initWithItems:[NSArray arrayWithObject:UA_INBOX_TR(@"UA_Delete")]] autorelease];
    self.deleteItem.frame = CGRectMake(0, 0, 130, 30);
    self.deleteItem.segmentedControlStyle = UISegmentedControlStyleBar;
    self.deleteItem.momentary = NO;
    self.deleteItem.selectedSegmentIndex = UISegmentedControlNoSegment;
    [self.deleteItem addTarget:self action:@selector(batchUpdateButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.deleteItem addTarget:self action:@selector(batchUpdateButtonCanceled:) forControlEvents:UIControlEventTouchUpOutside];
    self.deleteItem.tintColor = [UIColor colorWithRed:0.70 green:0.171 blue:0.1 alpha:1.0];

    UIBarButtonItem *deleteButton = [[[UIBarButtonItem alloc] initWithCustomView:self.deleteItem] autorelease];
    deleteButton.width = 130;
    self.markAsReadButtonItem = [[UIBarButtonItem alloc] initWithTitle:UA_INBOX_TR(@"UA_Mark_as_Read")
                                                style:UIBarButtonItemStyleBordered
                                               target:self action:@selector(batchUpdateButtonPressed:)];
    self.markAsReadButtonItem.width = 130;

    self.toolbarItems = [NSArray arrayWithObjects:fixedSpace, deleteButton, flexibleSpace, self.markAsReadButtonItem, fixedSpace, nil];

    [fixedSpace release];
    [flexibleSpace release];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if ([UAInbox shared].messageList.isRetrieving) {
        [self showLoadingScreen];
    } else {
        [self coverUpEmptyListIfNeeded];
        [self tableReloadData];
        [self updateNavigationBadge];
    }
    
    [self.messageTable deselectRowAtIndexPath:[self.messageTable indexPathForSelectedRow] animated:animated];
    [self.navigationController.navigationBar addSubview:self.badgeView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.badgeView removeFromSuperview];
}

- (void)viewDidUnload {
    // Release any retained subviews of the main view.
    self.loadingIndicator = nil;
    self.loadingLabel = nil;
    self.messageTable = nil;
    [self.selectedIndexPathsForEditing removeAllObjects];
    
    self.selectedIndexPathsForEditing = nil;
    self.setOfUnreadMessagesInSelection = nil;
    self.deleteItem = nil;
    self.markAsReadButtonItem = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

// For batch update/delete
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.navigationController setToolbarHidden:!editing animated:animated];
    [self.messageTable setEditing:editing animated:animated];
}

- (void)tableReloadData {
    [self.messageTable reloadData];
    [self.messageTable deselectRowAtIndexPath:[self.messageTable indexPathForSelectedRow] animated:NO];
}

- (void)refreshAfterBatchUpdate {
    [self hideLoadingScreen];
    
    [self.selectedIndexPathsForEditing removeAllObjects];
    self.cancelItem.enabled = YES;
    [self cancelButtonPressed:nil];
    
    [self.messageTable deselectRowAtIndexPath:[self.messageTable indexPathForSelectedRow] animated:NO];
    
    [self refreshBatchUpdateButtons];
    
}

- (void)showLoadingScreen {
    self.loadingView.hidden = NO;
    self.loadingLabel.text = UA_INBOX_TR(@"UA_Loading");
    [self.loadingIndicator show];
    self.loadingLabel.hidden = NO;
}

- (void)coverUpEmptyListIfNeeded {
    int messageCount = [[UAInbox shared].messageList messageCount];
    
    self.loadingView.hidden = (messageCount != 0);
    
    if (messageCount == 0) {
        self.loadingLabel.text = UA_INBOX_TR(@"UA_No_Messages");
    }
}

- (void)hideLoadingScreen {
    [self.loadingIndicator hide];
    [self coverUpEmptyListIfNeeded];
}

// indexPath.row is for use with grouped table views, see NSIndexPath UIKit Additions
- (UAInboxMessage *)messageForIndexPath:(NSIndexPath *)indexPath {
    NSArray *messages = [[UAInboxMessageList shared] messages];
    return [messages objectAtIndex:indexPath.row];
}

- (void)updateSetOfUnreadMessagesWithMessage:(UAInboxMessage *)message atIndexPath:(NSIndexPath *)indexPath {
    if (nil == self.setOfUnreadMessagesInSelection) {
        self.setOfUnreadMessagesInSelection = [NSMutableSet set];
    }
    BOOL messageIsListedAsUnread = [self checkSetOfIndexPaths:self.setOfUnreadMessagesInSelection forIndexPath:indexPath];
    if(messageIsListedAsUnread && message.unread){
        return;
    }
    if(messageIsListedAsUnread && !message.unread){
        [self.setOfUnreadMessagesInSelection removeObject:indexPath];
    }
    if(!messageIsListedAsUnread && message.unread){
        [self.setOfUnreadMessagesInSelection addObject:indexPath];
    }
    
}

- (NSUInteger) countOfUnreadMessagesInSetOfIndexPaths:(NSSet *)set {
    NSUInteger count = 0;
    BOOL isMarkedUnread = NO;
    for (NSIndexPath *path in set) {
        isMarkedUnread = [self checkSetOfIndexPaths:self.setOfUnreadMessagesInSelection forIndexPath:path];
        if(isMarkedUnread) count++;
    }
    return count;
}

- (BOOL)checkSetOfIndexPaths:(NSSet *)setOfPaths forIndexPath:(NSIndexPath *)indexPath {
    for (NSIndexPath *path in setOfPaths) {
        if ([path compare:indexPath] == NSOrderedSame) {
            return YES;
        };
    }
    return NO;
}

#pragma mark -
#pragma mark Button Action Methods

- (void)editButtonPressed:(id)sender {
    
    self.navigationItem.leftBarButtonItem.enabled = NO;
    
    if ([UAInboxMessageList shared].isBatchUpdating) {
        return;
    }
    
    self.navigationItem.rightBarButtonItem = self.cancelItem;
    [self.messageTable deselectRowAtIndexPath:[self.messageTable indexPathForSelectedRow] animated:YES];
    [self setEditing:YES animated:YES];
    // refresh need to be called after setEdit, because in iPad platform,
    // the trash button is decided by the table list's edit status.
    [self refreshBatchUpdateButtons];
}

- (void)cancelButtonPressed:(id)sender {
    
    self.navigationItem.leftBarButtonItem.enabled = YES;
    
    self.navigationItem.rightBarButtonItem = self.editItem;

    if ([self.selectedIndexPathsForEditing count] > 0) {
        NSSet *visibleCells = [NSSet setWithArray:[self.messageTable indexPathsForVisibleRows]];
        [self.selectedIndexPathsForEditing intersectSet:visibleCells];

        for (NSIndexPath *indexPath in self.selectedIndexPathsForEditing) {
            [self.messageTable cellForRowAtIndexPath:indexPath].selected = NO;
        }

        [self.selectedIndexPathsForEditing removeAllObjects];
    }

    [self setEditing:NO animated:YES];
    [self updateNavigationBadge];
}

- (void)batchUpdateButtonPressed:(id)sender {
    NSMutableIndexSet *messageIDs = [NSMutableIndexSet indexSet];
    for (NSIndexPath *indexPath in self.selectedIndexPathsForEditing) {
        [messageIDs addIndex:indexPath.row];
    }

    self.cancelItem.enabled = NO;

    if (sender == self.markAsReadButtonItem) {
        [[UAInbox shared].messageList performBatchUpdateCommand:UABatchReadMessages withMessageIndexSet:messageIDs];
    } else {
        [[UAInbox shared].messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:messageIDs];
    }

    self.deleteItem.selectedSegmentIndex = UISegmentedControlNoSegment;
    [self refreshBatchUpdateButtons];
}

- (void)batchUpdateButtonCanceled:(id)sender {
    self.deleteItem.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)refreshBatchUpdateButtons {
    NSString* deleteStr = UA_INBOX_TR(@"UA_Delete");
    NSString* markReadStr = UA_INBOX_TR(@"UA_Mark_as_Read");
    
    NSUInteger count = [self.selectedIndexPathsForEditing count];
    if (count == 0) {
        [self.deleteItem setTitle:deleteStr forSegmentAtIndex:0];
        self.markAsReadButtonItem.title = markReadStr;
        self.deleteItem.enabled = NO;
        self.markAsReadButtonItem.enabled = NO;
    } else {
        [self.deleteItem setTitle:[NSString stringWithFormat:@"%@ (%d)", deleteStr, count] forSegmentAtIndex:0];
        NSUInteger ureadCountInSelection = [self countOfUnreadMessagesInSetOfIndexPaths:self.selectedIndexPathsForEditing];
        self.markAsReadButtonItem.title = [NSString stringWithFormat:@"%@ (%lu)", markReadStr, (unsigned long)ureadCountInSelection];
        if ([UAInbox shared].messageList.isBatchUpdating) {
            self.deleteItem.enabled = NO;
            self.markAsReadButtonItem.enabled = NO;
        } else {
            self.deleteItem.enabled = YES;
            if (ureadCountInSelection != 0) {
                self.markAsReadButtonItem.enabled = YES;
            } else {
                self.markAsReadButtonItem.enabled = NO;
            }
        }
    }

}

- (void)deleteMessageAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
    [set addIndex:indexPath.row];
    [self.selectedIndexPathsForEditing removeAllObjects];
    [self.selectedIndexPathsForEditing addObject:indexPath];
    [[UAInbox shared].messageList performBatchUpdateCommand:UABatchDeleteMessages withMessageIndexSet:set];
    [self refreshBatchUpdateButtons];
}

#pragma mark -
#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UAInboxMessageListCell* cell = (UAInboxMessageListCell*)[tableView dequeueReusableCellWithIdentifier:self.cellReusableId];
    if (cell == nil) {
        NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:self.cellNibName owner: nil options: nil];
        cell = [topLevelObjects objectAtIndex:0];
    }

    [cell setData:[[UAInbox shared].messageList messageAtIndex:indexPath.row]];

    cell.editing = tableView.editing;
    if (cell.editing) {
        cell.selected = [self.selectedIndexPathsForEditing containsObject:indexPath];
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
    self.editItem.enabled = (messageCount == 0) ? NO : YES;
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
    UAInboxMessage *message = [self messageForIndexPath:indexPath];
    [self updateSetOfUnreadMessagesWithMessage:message atIndexPath:indexPath];
    if (self.editing && ![[UAInbox shared].messageList isBatchUpdating]) {
        if ([self.selectedIndexPathsForEditing containsObject:indexPath]) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            [self.selectedIndexPathsForEditing removeObject:indexPath];
        } else {
            [self.selectedIndexPathsForEditing addObject:indexPath];
        }
        [self refreshBatchUpdateButtons];
        [[tableView cellForRowAtIndexPath:indexPath] setNeedsLayout];
    } else if (!self.editing) {
        [self didSelectRowAtIndexPath:indexPath];
    }
   
}


- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UAInboxMessage *message = [[UAInboxMessageList shared] messageAtIndex:indexPath.row];
    [UAInbox displayMessage:self.navigationController message:message.messageID];
}

#pragma mark -
#pragma mark UAInboxMessageListObserver

- (void)messageListWillLoad {
    [self showLoadingScreen];
}

- (void)messageListLoaded {
	
	UALOG(@"got messageListLoaded");
        
	// TODO: add call to pushhandler here to get the messageid we should be viewing????
	//[UAInboxUI displayMessage:viewingMessageID];
	
    [self hideLoadingScreen];
    
    [self tableReloadData];
    [self updateNavigationBadge];
}

- (void)inboxLoadFailed {
    
    [self hideLoadingScreen];
    
    [self tableReloadData];
    [self updateNavigationBadge];
    
    if (self.shouldShowAlerts) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Mailbox_Error_Title")
                                                        message:UA_INBOX_TR(@"UA_Error_Fetching_Message_List")
                                                       delegate:nil
                                              cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
        
    }
}


- (void)batchMarkAsReadFinished {
    [self.messageTable reloadRowsAtIndexPaths:[self.selectedIndexPathsForEditing allObjects]
                        withRowAnimation:UITableViewRowAnimationNone];
    [self refreshAfterBatchUpdate];
}


- (void)batchMarkAsReadFailed {
    if (self.shouldShowAlerts) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Mailbox_Error_Title")
                                                        message:UA_INBOX_TR(@"UA_Error_Mark_Read_Message")
                                                       delegate:nil
                                              cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
        
    }
    [self refreshAfterBatchUpdate];
}


- (void)batchDeleteFinished {
    [self.messageTable beginUpdates];
    [self.messageTable deleteRowsAtIndexPaths:[self.selectedIndexPathsForEditing allObjects]
                        withRowAnimation:UITableViewRowAnimationLeft];
    [self.messageTable endUpdates];
    
    [self refreshAfterBatchUpdate];
}


- (void)batchDeleteFailed {
    if (self.shouldShowAlerts) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Mailbox_Error_Title")
                                                        message:UA_INBOX_TR(@"UA_Error_Delete_Message")
                                                       delegate:nil
                                              cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
        
    }
    [self refreshAfterBatchUpdate];
}


- (void)singleMessageMarkAsReadFinished:(UAInboxMessage *)m {
    int row = [[UAInbox shared].messageList indexOfMessage:m];
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

    self.badgeView = [[[UIView alloc] initWithFrame:CGRectMake(badgePosition, 4, 100, 34)] autorelease];
    self.badgeView.backgroundColor = [UIColor clearColor];
    self.badgeView.clipsToBounds = NO;

    //TODO: MACRO-ize this properly
    if ([self.tabbar respondsToSelector:@selector(setTintColor:)]) {
        //if iOS5
        [self.tabbar setTintColor:[UIColor clearColor]];

        // if iOS5 or 6
        if (self.tabbar.subviews.count > 1) {
            [self.badgeView addSubview:[self.tabbar.subviews objectAtIndex:1]];
        } else if (self.tabbar.subviews.count > 0) {
            [self.badgeView addSubview:[self.tabbar.subviews objectAtIndex:0]];
        }
    } else {
        //if < iOS5
        [self.badgeView addSubview:[((UIView *)[self.tabbar.subviews objectAtIndex:0]).subviews objectAtIndex:0]];
    }

    self.badgeView.hidden = YES;
}

- (void)updateNavigationBadge {
    int count = [UAInbox shared].messageList.unreadCount;
    NSString *unreadCount = [NSString stringWithFormat:@"%d", count];
    float badgePosition = self.navigationController.navigationBar.frame.size.width/2 + label_width/2 - 33;

    if (count < 0) {
        count = 0;
    }
    
    self.badgeView.hidden = (count==0);
    self.tabbarItem.badgeValue = unreadCount;
    self.badgeView.frame = CGRectMake(badgePosition + 5.3*([unreadCount length]-1),
                                 self.badgeView.frame.origin.y,
                                 self.badgeView.frame.size.width,
                                 self.badgeView.frame.size.height);
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration{
    [self updateNavigationBadge];
}


@end
