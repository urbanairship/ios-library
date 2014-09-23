/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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
#import "UAInboxMessageViewController.h"
#import "UAInboxLocalization.h"
#import "UAInbox.h"
#import "UAGlobal.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"

#import "UAURLProtocol.h"

/*
 * List-view image controls: default image path and cache values
 */
#define kUAPlaceholderIconImage @"list-image-placeholder.png"
#define kUAIconImageCacheMaxCount 100
#define kUAIconImageCacheMaxByteCost (1024 * 1024) /* 1MB */

@interface UAInboxMessageListController()

- (void)updateNavigationTitleText;// update nav controller title with unread count
- (void)refreshBatchUpdateButtons;// indicate edit mode view
- (void)deleteMessageAtIndexPath:(NSIndexPath *)indexPath;
- (void)createToolbarItems;

- (void)selectAllButtonPressed:(id)sender;
- (void)editButtonPressed:(id)sender;
- (void)cancelButtonPressed:(id)sender;

- (void)tableReloadData;
- (void)coverUpEmptyListIfNeeded;
- (void)showLoadingScreen;
- (void)hideLoadingScreen;

- (UAInboxMessage *)messageForIndexPath:(NSIndexPath *)indexPath;

/**
 * Returns the number of unread messages in the specified set of index paths for the current table view.
 */
- (NSUInteger)countOfUnreadMessagesInIndexPaths:(NSArray *)paths;

//
// List Icon Support
//

/**
 * Retrieve the list view icon for all the currently visible index paths.
 */
- (void)retrieveImagesForOnscreenRows;

/**
 * Retrieves the list view icon for a given index path, if available.
 */
- (void)retrieveIconForIndexPath:(NSIndexPath *)indexPath;

/**
 * Returns the URL for a given message's list view icon (or nil if not set).
 */
- (NSString *)iconURLStringForMessage:(UAInboxMessage *)message;


@property (nonatomic, weak) IBOutlet UITableView *messageTable;

@property (nonatomic, weak) IBOutlet UIView *loadingView;
@property (nonatomic, weak) IBOutlet UABeveledLoadingIndicator *loadingIndicator;
@property (nonatomic, weak) IBOutlet UILabel *loadingLabel;

@property (nonatomic, strong) UIBarButtonItem *deleteItem;
@property (nonatomic, strong) UIBarButtonItem *selectAllButtonItem;
@property (nonatomic, strong) UIBarButtonItem *markAsReadButtonItem;
@property (nonatomic, strong) UIBarButtonItem *editItem;
@property (nonatomic, strong) UIBarButtonItem *cancelItem;

@property (nonatomic, copy) NSString *cellReusableId;
@property (nonatomic, copy) NSString *cellNibName;

@property (nonatomic, strong) NSArray *messages;


/**
 * A dictionary of sets of (NSIndexPath *) with absolute URLs (NSString *) for keys.
 * Used to track current list icon fetches.
 * Try to use this on the main thread.
 */
@property (nonatomic, strong) NSMutableDictionary *currentIconURLRequests;

/**
 * An icon cache that stores UIImage representations of fetched icon images
 * The default limit is 1MB or 100 items
 * Images are also stored in the UA HTTP Cache, so a re-fetch will typically only
 * incur the decoding (PNG->UIImage) costs.
 */
@property (nonatomic, strong) NSCache *iconCache;

@end

@implementation UAInboxMessageListController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {

        self.cellReusableId = @"UAInboxMessageListCell";
        self.cellNibName = @"UAInboxMessageListCell";

        self.shouldShowAlerts = YES;
        self.iconCache = [[NSCache alloc] init];
        self.iconCache.countLimit = kUAIconImageCacheMaxCount;
        self.iconCache.totalCostLimit = kUAIconImageCacheMaxByteCost;
        self.currentIconURLRequests = [NSMutableDictionary dictionary];
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
                  initWithTitle:UAInboxLocalizedString(@"UA_Cancel")
                  style:UIBarButtonItemStyleDone
                  target:self
                  action:@selector(cancelButtonPressed:)];

    self.navigationItem.rightBarButtonItem = self.editItem;

    [self createToolbarItems];

    [self updateNavigationTitleText];
}

- (void)createToolbarItems {

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                   target:nil
                                                                                   action:nil];

    self.selectAllButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAInboxLocalizedString(@"UA_Select_All")
                                               style:UIBarButtonItemStylePlain
                                              target:self
                                              action:@selector(selectAllButtonPressed:)];


    self.deleteItem = [[UIBarButtonItem alloc] initWithTitle:UAInboxLocalizedString(@"UA_Delete")
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(batchUpdateButtonPressed:)];
    self.deleteItem.tintColor = [UIColor redColor];
    
    self.markAsReadButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAInboxLocalizedString(@"UA_Mark_as_Read")
                                                style:UIBarButtonItemStylePlain
                                               target:self action:@selector(batchUpdateButtonPressed:)];

    self.toolbarItems = @[self.selectAllButtonItem, flexibleSpace, self.deleteItem, flexibleSpace, self.markAsReadButtonItem];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.backBarButtonItem = nil;
    self.messages = [UAInbox shared].messageList.messages;

    if ([UAInbox shared].messageList.isRetrieving) {
        [self showLoadingScreen];
    } else {
        [self hideLoadingScreen];
        [self tableReloadData];
        [self updateNavigationTitleText];
    }

    UITableView *strongMessageTable = self.messageTable;

    [strongMessageTable deselectRowAtIndexPath:[strongMessageTable indexPathForSelectedRow] animated:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageListWillUpdate)
                                                 name:UAInboxMessageListWillUpdateNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageListUpdated)
                                                 name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UAInboxMessageListUpdatedNotification object:nil];

    // NOTE: This next bit is optional. You may want to clear the cache when the view disappears, though you can also
    // just clear the cache on low memory warning (as implemented)

    // [self.iconCache removeAllObjects]; // Remove all the objects - they can be repopulated from the URL cache
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.iconCache removeAllObjects];
}

// For batch update/delete
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {

    // Set allowsMultipleSelectionDuringEditing to YES only while
    // editing. This allows multi-select AND swipe to delete.
    UITableView *strongMessageTable = self.messageTable;
    strongMessageTable.allowsMultipleSelectionDuringEditing = editing;

    [self.navigationController setToolbarHidden:!editing animated:animated];
    [strongMessageTable setEditing:editing animated:animated];

    [super setEditing:editing animated:animated];
}

- (void)tableReloadData {
    UITableView *strongMessageTable = self.messageTable;
    [strongMessageTable reloadData];
    [strongMessageTable deselectRowAtIndexPath:[strongMessageTable indexPathForSelectedRow] animated:NO];
}

- (void)refreshAfterBatchUpdate {
    // end editing
    self.cancelItem.enabled = YES;
    [self cancelButtonPressed:nil];

    // reset selection
    UITableView *strongMessageTable = self.messageTable;
    [strongMessageTable deselectRowAtIndexPath:[strongMessageTable indexPathForSelectedRow] animated:NO];

    // force button update
    [self refreshBatchUpdateButtons];
}

- (void)showLoadingScreen {
    self.loadingView.hidden = NO;


    UILabel *strongLoadingLabel = self.loadingLabel;
    strongLoadingLabel.text = UAInboxLocalizedString(@"UA_Loading");
    // Set label color to white to contrast with dark beveled loading indicator background
    self.loadingLabel.textColor = [UIColor whiteColor];
    [self.messageTable setSeparatorStyle:UITableViewCellSelectionStyleDefault];

    UABeveledLoadingIndicator *strongLoadingIndicator = self.loadingIndicator;
    strongLoadingIndicator.alpha = 0.9;

    [strongLoadingIndicator show];
    strongLoadingLabel.hidden = NO;
}

- (void)coverUpEmptyListIfNeeded {
    self.loadingView.hidden = (self.messages.count != 0);
    
    if (self.messages.count == 0) {
        self.loadingLabel.text = UAInboxLocalizedString(@"UA_No_Messages");
        // Set label color to black to contrast with light tableview background
        self.loadingLabel.textColor = [UIColor blackColor];
        [self.messageTable setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    }
}

- (void)hideLoadingScreen {
    [self.loadingIndicator hide];
    [self coverUpEmptyListIfNeeded];
}

// indexPath.row is for use with grouped table views, see NSIndexPath UIKit Additions
- (UAInboxMessage *)messageForIndexPath:(NSIndexPath *)indexPath {
    return [self.messages objectAtIndex:(NSUInteger)indexPath.row];
}

- (NSUInteger)countOfUnreadMessagesInIndexPaths:(NSArray *)indexPaths {
    NSUInteger count = 0;
    for (NSIndexPath *path in indexPaths) {
        if ([self messageForIndexPath:path].unread) {
            ++count;
        }
    }
    return count;
}

- (void)displayMessage:(UAInboxMessage *)message {
    UAInboxMessageViewController *mvc;

    //if a message view is displaying, just load the new message
    UIViewController *top = self.navigationController.topViewController;
    if ([top class] == [UAInboxMessageViewController class]) {
        mvc = (UAInboxMessageViewController *) top;
        [mvc loadMessageForID:message.messageID];
    }
    //otherwise, push over a new message view
    else {
        mvc = [[UAInboxMessageViewController alloc] initWithNibName:@"UAInboxMessageViewController" bundle:nil];
        mvc.closeBlock = ^(BOOL animated){
            if (self.closeBlock) {
                self.closeBlock(animated);
            }
        };
        [mvc loadMessageForID:message.messageID];
        [self.navigationController pushViewController:mvc animated:YES];
    }
}


#pragma mark -
#pragma mark Button Action Methods

- (void)selectAllButtonPressed:(id)sender {

    UITableView *strongMessageTable = self.messageTable;
    NSInteger rows = [strongMessageTable numberOfRowsInSection:0];

    NSIndexPath *currentPath;
    if ([strongMessageTable.indexPathsForSelectedRows count] == rows) {
        //everything is selected, so we deselect all
        for (NSInteger i = 0; i < rows; ++i) {
            currentPath = [NSIndexPath indexPathForRow:i inSection:0];
            [strongMessageTable deselectRowAtIndexPath:currentPath
                                             animated:NO];
            [self tableView:strongMessageTable didSelectRowAtIndexPath:currentPath];
        }
    } else {
        // not everything is selected, so let's select all
        for (NSInteger i = 0; i < rows; ++i) {
            currentPath = [NSIndexPath indexPathForRow:i inSection:0];
            [strongMessageTable selectRowAtIndexPath:currentPath
                                           animated:NO
                                     scrollPosition:UITableViewScrollPositionNone];
            [self tableView:strongMessageTable didDeselectRowAtIndexPath:currentPath];
        }
    }


}

- (void)editButtonPressed:(id)sender {
    
    self.navigationItem.leftBarButtonItem.enabled = NO;
    
    if ([UAInbox shared].messageList.isBatchUpdating) {
        return;
    }

    self.navigationItem.rightBarButtonItem = self.cancelItem;
    UITableView *strongMessageTable = self.messageTable;
    [strongMessageTable deselectRowAtIndexPath:[strongMessageTable indexPathForSelectedRow] animated:YES];
    [self setEditing:YES animated:YES];

    // refresh need to be called after setEdit, because in iPad platform,
    // the trash button is decided by the table list's edit status.
    [self refreshBatchUpdateButtons];
}

- (void)cancelButtonPressed:(id)sender {
    
    self.navigationItem.leftBarButtonItem.enabled = YES;
    
    self.navigationItem.rightBarButtonItem = self.editItem;

    [self setEditing:NO animated:YES];
    [self updateNavigationTitleText];
}

- (void)batchUpdateButtonPressed:(id)sender {

    UITableView *strongMessageTable = self.messageTable;

    NSMutableArray *messages = [NSMutableArray array];
    for (NSIndexPath *indexPath in strongMessageTable.indexPathsForSelectedRows) {
        [messages addObject:[self.messages objectAtIndex:(NSUInteger)indexPath.row]];
    }

    self.cancelItem.enabled = NO;

    if (sender == self.markAsReadButtonItem) {

        [[UAInbox shared].messageList markMessagesRead:messages completionHandler:^{
            [self refreshAfterBatchUpdate];
        }];
    } else {
        [[UAInbox shared].messageList markMessagesDeleted:messages completionHandler:^{
            [self refreshAfterBatchUpdate];
        }];
    }

    [self refreshBatchUpdateButtons];
}


- (void)refreshBatchUpdateButtons {
    NSString *deleteStr = UAInboxLocalizedString(@"UA_Delete");
    NSString *markReadStr = UAInboxLocalizedString(@"UA_Mark_as_Read");

    UITableView *strongMessageTable = self.messageTable;
    NSUInteger count = [strongMessageTable.indexPathsForSelectedRows count];
    if (count == 0) {
        self.deleteItem.title = deleteStr;
        self.markAsReadButtonItem.title = markReadStr;
        self.deleteItem.enabled = NO;
        self.markAsReadButtonItem.enabled = NO;

    } else {
        self.deleteItem.title = [NSString stringWithFormat:@"%@ (%lu)", deleteStr, (unsigned long)count];

        NSUInteger unreadCountInSelection = [self countOfUnreadMessagesInIndexPaths:strongMessageTable.indexPathsForSelectedRows];
        self.markAsReadButtonItem.title = [NSString stringWithFormat:@"%@ (%lu)", markReadStr, (unsigned long)unreadCountInSelection];

        if ([UAInbox shared].messageList.isBatchUpdating) {
            self.deleteItem.enabled = NO;
            self.markAsReadButtonItem.enabled = NO;
        } else {
            self.deleteItem.enabled = YES;
            if (unreadCountInSelection != 0) {
                self.markAsReadButtonItem.enabled = YES;
            } else {
                self.markAsReadButtonItem.enabled = NO;
            }
        }
    }

    if ([strongMessageTable.indexPathsForSelectedRows count] < [strongMessageTable numberOfRowsInSection:0]) {
        self.selectAllButtonItem.title = UAInboxLocalizedString(@"UA_Select_All");
    } else {
        self.selectAllButtonItem.title = UAInboxLocalizedString(@"UA_Select_None");
    }

}

- (void)deleteMessageAtIndexPath:(NSIndexPath *)indexPath {

    if (!indexPath) return;//require an index path (for safety with literal below)

    UAInboxMessage *message = [self.messages objectAtIndex:(NSUInteger)indexPath.row];
    if (message) {
        [[UAInbox shared].messageList markMessagesDeleted:@[message] completionHandler:^{
            [self refreshAfterBatchUpdate];
        }];
    }

    [self refreshBatchUpdateButtons];
}

#pragma mark -
#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UAInboxMessageListCell *cell = (UAInboxMessageListCell *)[tableView dequeueReusableCellWithIdentifier:self.cellReusableId];
    if (!cell) {
        NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:self.cellNibName owner:nil options:nil];
        cell = [topLevelObjects objectAtIndex:0];
    }

    UAInboxMessage *message = [self.messages objectAtIndex:(NSUInteger)indexPath.row];

    [cell setData:message];

    UIImageView *localImageView = cell.listIconView;
    UITableView *strongMessageTable = self.messageTable;

    if ([self.iconCache objectForKey:[self iconURLStringForMessage:message]]) {
        localImageView.image = [self.iconCache objectForKey:[self iconURLStringForMessage:message]];
    } else {
        if (!strongMessageTable.dragging && !strongMessageTable.decelerating) {
            [self retrieveIconForIndexPath:indexPath];
        }

        // if a download is deferred or in progress, return a placeholder image
        localImageView.image = [UIImage imageNamed:kUAPlaceholderIconImage];
    }

    cell.editing = tableView.editing;

    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    [self deleteMessageAtIndexPath:indexPath];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.messages.count;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        return UITableViewCellEditingStyleNone;
    } else {
        return UITableViewCellEditingStyleDelete;
    }
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
    if (self.editing && ![[UAInbox shared].messageList isBatchUpdating]) {
        [self refreshBatchUpdateButtons];
    } else if (!self.editing) {
        [self displayMessage:message];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing && ![[UAInbox shared].messageList isBatchUpdating]) {
        [self refreshBatchUpdateButtons];
    }
}


#pragma mark -
#pragma mark NSNotificationCenter callbacks

- (void)messageListWillUpdate {
    [self showLoadingScreen];
}

- (void)messageListUpdated {
    UA_LDEBUG(@"UAInboxMessageListController messageListUpdated");
    self.messages = [UAInbox shared].messageList.messages;

    [self hideLoadingScreen];
    [self tableReloadData];
    [self refreshBatchUpdateButtons];
    [self updateNavigationTitleText];
}

#pragma mark -
#pragma mark Navigation Title Unread Count Updates


- (void)updateNavigationTitleText {
    NSInteger count = [UAInbox shared].messageList.unreadCount;

    if (count < 0) {
        count = 0;
    }

    self.title = [NSString stringWithFormat:UAInboxLocalizedString(@"UA_Inbox_List_Title"), count];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration{
    [self updateNavigationTitleText];

}

#pragma mark -
#pragma mark List Icon Loading (UIScrollViewDelegate)

// Load images for all onscreen rows when scrolling is finished
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self retrieveImagesForOnscreenRows];
    }
}

// Compute the eventual resting view bounds (r), and retrieve images for those cells
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset {

    CGRect r;
    r.origin = *targetContentOffset;
    r.size = self.view.bounds.size;

    NSArray *indexPaths = [self.messageTable indexPathsForRowsInRect:r];
    for (NSIndexPath *indexPath in indexPaths) {
        UA_LTRACE(@"Loading row %ld. Title: %@", (long)indexPath.row, [self messageForIndexPath:indexPath].title);
        [self retrieveIconForIndexPath:indexPath];
    }
}

// Load the images when deceleration completes (though the end dragging should try to fetch these first)
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self retrieveImagesForOnscreenRows];
}

// A tap on the status bar will force a scroll to the top
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    return YES;
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    [self retrieveImagesForOnscreenRows];
}

#pragma mark - List Icon Load + Fetch

- (void)retrieveImagesForOnscreenRows {
    NSArray *visiblePaths = [self.messageTable indexPathsForVisibleRows];
    for (NSIndexPath *indexPath in visiblePaths) {
        [self retrieveIconForIndexPath:indexPath];
    }
}

- (void)retrieveIconForIndexPath:(NSIndexPath *)indexPath {

    UAInboxMessage *message = [self.messages objectAtIndex:(NSUInteger)indexPath.row];

    NSString *iconListURLString = [self iconURLStringForMessage:message];
    if (!iconListURLString) {
        // nothing to do here!
        return;
    }

    NSURL *iconListURL = [NSURL URLWithString:iconListURLString];
    [UAURLProtocol addCachableURL:iconListURL];// Tell the UA cache to keep this data

    // Let's not download if the app already has the decoded icon
    if (![self.iconCache objectForKey:iconListURLString]) {

        // NOTE: All add/remove operations on the cache & in-progress set should be done
        // on the main thread. They'll be cleared below in a dispatch_asynch/main queue block.

        // Next, check to see if we're currently requesting the icon
        // Add the index path to the set of paths to update when a request is completed and then proceed if necessary
        NSMutableSet *currentRequestedIndexPaths = [self.currentIconURLRequests objectForKey:iconListURLString];
        if ([currentRequestedIndexPaths count]) {
            [currentRequestedIndexPaths addObject:indexPath];
            return;// now we wait for the in-flight request to finish
        } else {
            // No in-flight request. Add and continue;
            [self.currentIconURLRequests setValue:[NSMutableSet setWithObject:indexPath] forKey:iconListURLString];
        }

        // Use a weak reference to self in case our UI disappears while we're off in the cloud
        __weak UAInboxMessageListController *weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul), ^{

            UA_LTRACE(@"Fetching RP Icon: %@", iconListURLString);

            // This decodes the image at full size. Scaling can be added here
            // as an additional enhancement if for some reason your resources
            // are too large for a given device.
            NSData *iconImageData = [NSData dataWithContentsOfURL:iconListURL];
            UIImage *iconImage = [UIImage imageWithData:iconImageData];

            dispatch_async(dispatch_get_main_queue(), ^{
                // Recapture our `self` for the duration of this block
                UAInboxMessageListController *strongSelf = weakSelf;

                // Place the icon image in the cache and reload the row
                if (iconImage) {

                    //estimate decoded size using 4bytes/px (ARGB)
                    NSUInteger sizeInBytes = iconImage.size.height * iconImage.size.width * 4;
                    [strongSelf.iconCache setObject:iconImage forKey:iconListURLString cost:sizeInBytes];
                    UA_LTRACE(@"Added image to cache (%@) with size in bytes: %lu", iconListURL, (unsigned long)sizeInBytes);

                    NSArray *indexPaths = [(NSSet *)[strongSelf.currentIconURLRequests objectForKey:iconListURLString] allObjects];
                    [strongSelf.messageTable reloadRowsAtIndexPaths:indexPaths
                                                   withRowAnimation:UITableViewRowAnimationNone];
                }

                // Clear the request marker
                [strongSelf.currentIconURLRequests removeObjectForKey:iconListURLString];
            });
        });
    }
}

- (NSString *)iconURLStringForMessage:(UAInboxMessage *) message {
    NSDictionary *icons = [message.rawMessageObject objectForKey:@"icons"];
    return [icons objectForKey:@"list_icon"];
}


@end
