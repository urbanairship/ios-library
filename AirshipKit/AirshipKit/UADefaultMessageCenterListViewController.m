/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

#import "UADefaultMessageCenterListViewController.h"
#import "UADefaultMessageCenterListCell.h"
#import "UADefaultMessageCenterMessageViewController.h"
#import "UAInboxMessage.h"
#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "UAURLProtocol.h"
#import "UAMessageCenterLocalization.h"
#import "UADefaultMessageCenterStyle.h"

/*
 * List-view image controls: default image path and cache values
 */
#define kUAPlaceholderIconImage @"ua-inbox-icon-placeholder"
#define kUAIconImageCacheMaxCount 100
#define kUAIconImageCacheMaxByteCost (2 * 1024 * 1024) /* 2MB */
#define kUADefaultMessageCenterListCellNibName @"UADefaultMessageCenterListCell"

@interface UADefaultMessageCenterListViewController()

/**
 * The placeholder image to display in lieu of the icon
 */
@property (nonatomic, strong) UIImage *placeholderIcon;

/**
 * The table view of message list cells
 */
@property (nonatomic, weak) IBOutlet UITableView *messageTable;

/**
 * Convenience accessor for the messages to be displayed in the message table.
 */
@property (nonatomic, readonly) NSArray *messages;

/**
 * The view displayed when there are no messages
 */
@property (nonatomic, weak) IBOutlet UIView *coverView;

/**
 * Label displayed in the coverView
 */
@property (nonatomic, weak) IBOutlet UILabel *coverLabel;

/**
 * The default tint color to use when overriding the inherited tint.
 */
@property (nonatomic, strong) UIColor *defaultTintColor;

/**
 * Bar button items for navigation bar and toolbar
 */
@property (nonatomic, strong) UIBarButtonItem *deleteItem;
@property (nonatomic, strong) UIBarButtonItem *selectAllButtonItem;
@property (nonatomic, strong) UIBarButtonItem *markAsReadButtonItem;
@property (nonatomic, strong) UIBarButtonItem *editItem;
@property (nonatomic, strong) UIBarButtonItem *cancelItem;


/**
 * The currently selected index path.
 */
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

/**
 * Whether the interface is currently collapsed
 */
@property (nonatomic, assign) BOOL collapsed;

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

/**
 * A refresh control used for "pull to refresh" behavior.
 */
@property (nonatomic, strong) UIRefreshControl *refreshControl;

/**
 * A concurrent dispatch queue to use for fetching icon images.
 */
@property (nonatomic, strong) dispatch_queue_t iconFetchQueue;

@end

@implementation UADefaultMessageCenterListViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        self.iconCache = [[NSCache alloc] init];
        self.iconCache.countLimit = kUAIconImageCacheMaxCount;
        self.iconCache.totalCostLimit = kUAIconImageCacheMaxByteCost;
        self.currentIconURLRequests = [NSMutableDictionary dictionary];
        self.refreshControl = [[UIRefreshControl alloc] init];
        self.iconFetchQueue = dispatch_queue_create("com.urbanairship.messagecenter.ListIconQueue", DISPATCH_QUEUE_CONCURRENT);

        // grab the default tint color from a dummy view
        self.defaultTintColor = [[UIView alloc] init].tintColor;
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
                       initWithTitle:UAMessageCenterLocalizedString(@"ua_cancel")
                       style:UIBarButtonItemStyleDone
                       target:self
                       action:@selector(cancelButtonPressed:)];

    self.navigationItem.rightBarButtonItem = self.editItem;

    [self createToolbarItems];

    self.coverLabel.text = UAMessageCenterLocalizedString(@"ua_empty_message_list");

    if (self.style.listColor) {
        self.messageTable.backgroundColor = self.style.listColor;
    }

    if (self.style.cellSeparatorColor) {
        self.messageTable.separatorColor = self.style.cellSeparatorColor;
    }

    [self.refreshControl addTarget:self action:@selector(refreshStateChanged:) forControlEvents:UIControlEventValueChanged];

    UITableViewController *tableController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    tableController.view = self.messageTable;
    tableController.refreshControl = self.refreshControl;

    if (self.style.listColor) {
        self.refreshControl.backgroundColor = self.style.listColor;
    }

    if (self.style.refreshTintColor) {
        self.refreshControl.tintColor = self.style.refreshTintColor;
    }

    // This allows us to use the UITableViewController for managing the refresh control, while keeping the
    // outer chrome of the list view controller intact
    [self addChildViewController:tableController];
}

- (void)refreshStateChanged:(UIRefreshControl *)sender {
    if (sender.refreshing) {
        [[UAirship inbox].messageList retrieveMessageListWithSuccessBlock:^{
            [sender endRefreshing];
        } withFailureBlock:^ {
            [sender endRefreshing];
        }];
    }
}

// Note: since the message list is refreshed with new model objects when reloaded,
// we can't reliably hold onto any single instance. This method is mostly for convenience.
- (NSArray *)messages {
    NSArray *allMessages = [UAirship inbox].messageList.messages;
    if (self.filter) {
        return [allMessages filteredArrayUsingPredicate:self.filter];
    } else {
        return allMessages;
    }
}

- (void)createToolbarItems {

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                   target:nil
                                                                                   action:nil];

    self.selectAllButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_select_all")
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(selectAllButtonPressed:)];

    // Override any inherited tint color, to avoid potential clashes
    self.selectAllButtonItem.tintColor = self.defaultTintColor;


    self.deleteItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_delete")
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(batchUpdateButtonPressed:)];
    self.deleteItem.tintColor = [UIColor redColor];

    self.markAsReadButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_mark_read")
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self action:@selector(batchUpdateButtonPressed:)];

    // Override any inherited tint color, to avoid potential clashes
    self.markAsReadButtonItem.tintColor = self.defaultTintColor;

    self.toolbarItems = @[self.selectAllButtonItem, flexibleSpace, self.deleteItem, flexibleSpace, self.markAsReadButtonItem];

}

- (void)reload {
    [self.messageTable reloadData];

    // Cover up if necessary
    self.coverView.hidden = self.messages.count > 0;

    // If a cell was previously selected and there are messages to display
    if (self.selectedIndexPath && self.messages.count) {
        // Find the corresponding row or its nearest accessible neighbor
        NSInteger row = MIN((NSInteger)self.messages.count - 1, self.selectedIndexPath.row);

        // If the message previously at that index is no longer present
        if (self.selectedIndexPath.row != row) {
            self.selectedIndexPath = [NSIndexPath indexPathForRow:row inSection:0];
        }

        // If the UI is not collapsed, make sure the row is selected
        if (!self.splitViewController.collapsed) {
            [self.messageTable selectRowAtIndexPath:self.selectedIndexPath animated:YES scrollPosition:UITableViewScrollPositionTop];
        }

    } else {
        self.selectedIndexPath = nil;
    }

}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];

    self.navigationItem.backBarButtonItem = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageListUpdated)
                                                 name:UAInboxMessageListUpdatedNotification object:nil];
    [self reload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.splitViewController.collapsed && self.selectedIndexPath) {
        [self.messageTable selectRowAtIndexPath:self.selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionTop];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.iconCache removeAllObjects];
}

// For batch update/delete
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];

    // Set allowsMultipleSelectionDuringEditing to YES only while
    // editing. This allows multi-select AND swipe to delete.
    UITableView *strongMessageTable = self.messageTable;
    strongMessageTable.allowsMultipleSelectionDuringEditing = editing;

    [self.navigationController setToolbarHidden:!editing animated:animated];
    [strongMessageTable setEditing:editing animated:animated];
}

- (void)refreshAfterBatchUpdate {
    // end editing
    self.cancelItem.enabled = YES;
    [self cancelButtonPressed:nil];

    // force button update
    [self refreshBatchUpdateButtons];
}

// indexPath.row is for use with grouped table views, see NSIndexPath UIKit Additions
- (UAInboxMessage *)messageForIndexPath:(NSIndexPath *)indexPath {
    return [self.messages objectAtIndex:(NSUInteger)indexPath.row];
}

/**
 * Returns the number of unread messages in the specified set of index paths for the current table view.
 */
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
    UADefaultMessageCenterMessageViewController *mvc;

    //if a message view is displaying, just load the new message
    UIViewController *top = self.navigationController.topViewController;
    if ([top class] == [UADefaultMessageCenterMessageViewController class]) {
        mvc = (UADefaultMessageCenterMessageViewController *) top;
        [mvc loadMessageForID:message.messageID];
    }
    //otherwise, push over a new message view
    else {
        mvc = [[UADefaultMessageCenterMessageViewController alloc] initWithNibName:@"UADefaultMessageCenterMessageViewController" bundle:[UAirship resources]];

        mvc.filter = self.filter;

        __weak id weakSelf = self;
        mvc.closeBlock = ^(BOOL animated){

            UADefaultMessageCenterListViewController *strongSelf = weakSelf;

            if (!strongSelf) {
                return;
            }
            // Call the close block if present
            if (strongSelf.closeBlock) {
                strongSelf.closeBlock(animated);
            } else {
                // Fallback to displaying the inbox
                [self.navigationController popViewControllerAnimated:animated];
            }
        };

        mvc.message = message;

        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:mvc];

        if (self.style.navigationBarColor) {
            nav.navigationBar.barTintColor = self.style.navigationBarColor;
        }

        // Only apply opaque property if a style is set
        if (self.style) {
            nav.navigationBar.translucent = !self.style.navigationBarOpaque;
        }

        NSMutableDictionary *titleAttributes = [NSMutableDictionary dictionary];

        if (self.style.titleColor) {
            titleAttributes[NSForegroundColorAttributeName] = self.style.titleColor;
        }

        if (self.style.titleFont) {
            titleAttributes[NSFontAttributeName] = self.style.titleFont;
        }

        if (titleAttributes.count) {
            nav.navigationBar.titleTextAttributes = titleAttributes;
        }

        // note: not sure why this is necessary but the navigation controller isn't sized properly otherwise
        [nav.view layoutSubviews];
        [self showDetailViewController:nav sender:self];
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
            [self tableView:strongMessageTable didDeselectRowAtIndexPath:currentPath];
        }
    } else {
        // not everything is selected, so let's select all
        for (NSInteger i = 0; i < rows; ++i) {
            currentPath = [NSIndexPath indexPathForRow:i inSection:0];
            [strongMessageTable selectRowAtIndexPath:currentPath
                                            animated:NO
                                      scrollPosition:UITableViewScrollPositionNone];
            [self tableView:strongMessageTable didSelectRowAtIndexPath:currentPath];
        }
    }
}

- (void)editButtonPressed:(id)sender {

    self.navigationItem.leftBarButtonItem.enabled = NO;

    if ([UAirship inbox].messageList.isBatchUpdating) {
        return;
    }

    self.navigationItem.rightBarButtonItem = self.cancelItem;

    [self setEditing:YES animated:YES];

    // refresh need to be called after setEdit, because in iPad platform,
    // the trash button is decided by the table list's edit status.
    [self refreshBatchUpdateButtons];
}

- (void)cancelButtonPressed:(id)sender {

    self.navigationItem.leftBarButtonItem.enabled = YES;

    self.navigationItem.rightBarButtonItem = self.editItem;

    [self setEditing:NO animated:YES];
}

- (void)batchUpdateButtonPressed:(id)sender {

    UITableView *strongMessageTable = self.messageTable;

    NSMutableArray *messages = [NSMutableArray array];
    for (NSIndexPath *indexPath in strongMessageTable.indexPathsForSelectedRows) {
        [messages addObject:[self.messages objectAtIndex:(NSUInteger)indexPath.row]];
    }

    self.cancelItem.enabled = NO;

    if (sender == self.markAsReadButtonItem) {
        [[UAirship inbox].messageList markMessagesRead:messages completionHandler:^{
            [self refreshAfterBatchUpdate];
        }];
    } else {
        [[UAirship inbox].messageList markMessagesDeleted:messages completionHandler:^{
            [self refreshAfterBatchUpdate];
        }];
    }
}


- (void)refreshBatchUpdateButtons {
    if (self.editing) {
        NSString *deleteStr = UAMessageCenterLocalizedString(@"ua_delete");
        NSString *markReadStr = UAMessageCenterLocalizedString(@"ua_mark_read");

        UITableView *strongMessageTable = self.messageTable;
        NSUInteger count = [strongMessageTable.indexPathsForSelectedRows count];
        if (!count) {
            self.deleteItem.title = deleteStr;
            self.markAsReadButtonItem.title = markReadStr;
            self.deleteItem.enabled = NO;
            self.markAsReadButtonItem.enabled = NO;

        } else {
            self.deleteItem.title = [NSString stringWithFormat:@"%@ (%lu)", deleteStr, (unsigned long)count];

            NSUInteger unreadCountInSelection = [self countOfUnreadMessagesInIndexPaths:strongMessageTable.indexPathsForSelectedRows];
            self.markAsReadButtonItem.title = [NSString stringWithFormat:@"%@ (%lu)", markReadStr, (unsigned long)unreadCountInSelection];

            if ([UAirship inbox].messageList.isBatchUpdating) {
                self.deleteItem.enabled = NO;
                self.markAsReadButtonItem.enabled = NO;
            } else {
                self.deleteItem.enabled = YES;
                if (unreadCountInSelection) {
                    self.markAsReadButtonItem.enabled = YES;
                } else {
                    self.markAsReadButtonItem.enabled = NO;
                }
            }
        }

        if ([strongMessageTable.indexPathsForSelectedRows count] < [strongMessageTable numberOfRowsInSection:0]) {
            self.selectAllButtonItem.title = UAMessageCenterLocalizedString(@"ua_select_all");
        } else {
            self.selectAllButtonItem.title = UAMessageCenterLocalizedString(@"ua_select_none");
        }
    }
}

- (void)deleteMessageAtIndexPath:(NSIndexPath *)indexPath {

    if (!indexPath) {
        //require an index path (for safety with literal below)
        return;
    }

    UAInboxMessage *message = [self.messages objectAtIndex:(NSUInteger)indexPath.row];

    if (message) {
        [[UAirship inbox].messageList markMessagesDeleted:@[message] completionHandler:^{
            [self refreshAfterBatchUpdate];
        }];
    }
}

- (UIImage *)placeholderIcon {
    if (self.style.placeholderIcon) {
        return self.style.placeholderIcon;
    }

    if (! _placeholderIcon) {
        _placeholderIcon =[UIImage imageNamed:@"UADefaultMessageCenterPlaceholderIcon.png" inBundle:[UAirship resources] compatibleWithTraitCollection:nil];
    }
    return _placeholderIcon;
}

#pragma mark -
#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *nibName = kUADefaultMessageCenterListCellNibName;
    NSBundle *bundle = [UAirship resources];

    UADefaultMessageCenterListCell *cell = (UADefaultMessageCenterListCell *)[tableView dequeueReusableCellWithIdentifier:nibName];

    if (!cell) {
        cell = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];
    }

    cell.style = self.style;
    UAInboxMessage *message = [self.messages objectAtIndex:(NSUInteger)indexPath.row];
    [cell setData:message];

    UIImageView *localImageView = cell.listIconView;
    UITableView *strongMessageTable = self.messageTable;

    if ([self.iconCache objectForKey:[self iconURLStringForMessage:message]]) {
        localImageView.image = [self.iconCache objectForKey:[self iconURLStringForMessage:message]];
    } else {
        if (!strongMessageTable.dragging && !strongMessageTable.decelerating) {
            [self retrieveIconForIndexPath:indexPath iconSize:localImageView.frame.size];
        }

        UIImage *placeholderIcon = self.placeholderIcon;

        CGRect frame = cell.listIconView.frame;

        // If a download is deferred or in progress, set a placeholder image
        localImageView.image = placeholderIcon;

        // Resize to match the original frame if needed
        cell.listIconView.frame = CGRectMake(frame.origin.x, frame.origin.y, CGRectGetWidth(frame), CGRectGetHeight(frame));
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
                                            forRowAtIndexPath:(NSIndexPath *)indexPath {
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

    if (self.editing) {
        [self refreshBatchUpdateButtons];
    } else {
        self.selectedIndexPath = indexPath;
        [self displayMessage:message];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        [self refreshBatchUpdateButtons];
    }
}

#pragma mark -
#pragma mark NSNotificationCenter callbacks

- (void)messageListUpdated {
    UA_LDEBUG(@"UADefaultMessageCenterListViewController messageListUpdated");
    [self reload];
    [self refreshBatchUpdateButtons];
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
        UITableViewCell *cell = [self.messageTable cellForRowAtIndexPath:indexPath];
        UA_LTRACE(@"Loading row %ld. Title: %@", (long)indexPath.row, [self messageForIndexPath:indexPath].title);
        [self retrieveIconForIndexPath:indexPath iconSize:cell.imageView.frame.size];
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

#pragma mark - UISplitViewControllerDelegate

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController {
    // Only collapse onto the primary (list) controller if there's no currently selected message or we're in batch editing mode
    return self.selectedIndexPath == nil || self.editing;
}

- (UIViewController *)primaryViewControllerForExpandingSplitViewController:(UISplitViewController *)splitViewController {
    self.collapsed = NO;
    if (self.selectedIndexPath) {
        // Delay selection by a beat, to allow rotation to finish
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.messageTable selectRowAtIndexPath:self.selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionTop];
        });
    }
    // Returning nil causes the split view controller to default to the the existing primary view controller
    return nil;
}

- (UIViewController *)primaryViewControllerForCollapsingSplitViewController:(UISplitViewController *)splitViewController {
    self.collapsed = YES;
    // Returning nil causes the split view controller to default to the the existing secondary view controller
    return nil;
}

#pragma mark - List Icon Load + Fetch

/**
 * Scales a source image to the provided size.
 */
- (UIImage *)scaleImage:(UIImage *)source toSize:(CGSize)size {

    CGFloat sourceWidth = source.size.width;
    CGFloat sourceHeight = source.size.height;

    CGFloat widthFactor = size.width / sourceWidth;
    CGFloat heightFactor = size.height / sourceHeight;
    CGFloat maxFactor = MAX(widthFactor, heightFactor);

    CGFloat scaledWidth = truncf(sourceWidth * maxFactor);
    CGFloat scaledHeight = truncf(sourceHeight * maxFactor);

    CGAffineTransform transform = CGAffineTransformMakeScale(maxFactor, maxFactor);
    CGSize transformSize = CGSizeApplyAffineTransform(source.size, transform);

    // Note: passing 0.0 causes the function below to use the scale factor of the main screen
    CGFloat transformScaleFactor = 0.0;

    UIGraphicsBeginImageContextWithOptions(transformSize, NO, transformScaleFactor);

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);

    [source drawInRect:CGRectMake(0, 0, scaledWidth, scaledHeight)];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return scaledImage;
}

/**
 * Retrieve the list view icon for all the currently visible index paths.
 */
- (void)retrieveImagesForOnscreenRows {
    NSArray *visiblePaths = [self.messageTable indexPathsForVisibleRows];
    for (NSIndexPath *indexPath in visiblePaths) {
        UITableViewCell *cell = [self.messageTable cellForRowAtIndexPath:indexPath];
        [self retrieveIconForIndexPath:indexPath iconSize:cell.imageView.frame.size];
    }
}

/**
 * Retrieves the list view icon for a given index path, if available.
 */
- (void)retrieveIconForIndexPath:(NSIndexPath *)indexPath iconSize:(CGSize)iconSize {

    UAInboxMessage *message = [self.messages objectAtIndex:(NSUInteger)indexPath.row];

    NSString *iconListURLString = [self iconURLStringForMessage:message];

    if (!iconListURLString) {
        // Nothing to do here
        return;
    }

    // If the icon isn't already in the cache
    if (![self.iconCache objectForKey:iconListURLString]) {

        NSURL *iconListURL = [NSURL URLWithString:iconListURLString];

        // Tell the cache to remember the URL
        [UAURLProtocol addCachableURL:iconListURL];

        // NOTE: All add/remove operations on the cache & in-progress set should be done
        // on the main thread. They'll be cleared below in a dispatch_async/main queue block.

        // Next, check to see if we're currently requesting the icon
        // Add the index path to the set of paths to update when a request is completed and then proceed if necessary
        NSMutableSet *currentRequestedIndexPaths = [self.currentIconURLRequests objectForKey:iconListURLString];
        if ([currentRequestedIndexPaths count]) {
            [currentRequestedIndexPaths addObject:indexPath];
            // Wait for the in-flight request to finish
            return;
        } else {
            // No in-flight request. Add and continue.
            [self.currentIconURLRequests setValue:[NSMutableSet setWithObject:indexPath] forKey:iconListURLString];
        }

        __weak UADefaultMessageCenterListViewController *weakSelf = self;
        dispatch_async(self.iconFetchQueue, ^{

            UA_LTRACE(@"Fetching RP Icon: %@", iconListURLString);

            // Note: this decodes the source image at full size
            NSData *iconImageData = [NSData dataWithContentsOfURL:iconListURL];
            UIImage *iconImage = [UIImage imageWithData:iconImageData];
            iconImage = [self scaleImage:iconImage toSize:iconSize];

            dispatch_async(dispatch_get_main_queue(), ^{
                // Recapture self for the duration of this block
                UADefaultMessageCenterListViewController *strongSelf = weakSelf;

                // Place the icon image in the cache and reload the row
                if (iconImage) {

                    NSUInteger sizeInBytes = CGImageGetHeight(iconImage.CGImage) * CGImageGetBytesPerRow(iconImage.CGImage);

                    [strongSelf.iconCache setObject:iconImage forKey:iconListURLString];
                    UA_LTRACE(@"Added image to cache (%@) with size in bytes: %lu", iconListURL, (unsigned long)sizeInBytes);

                    // Update cells directly rather than forcing a reload (which deselects)
                    UADefaultMessageCenterListCell *cell;
                    for (NSIndexPath *indexPath in (NSSet *)[strongSelf.currentIconURLRequests objectForKey:iconListURLString]) {
                        cell = (UADefaultMessageCenterListCell *)[strongSelf.messageTable cellForRowAtIndexPath:indexPath];
                        cell.listIconView.image = iconImage;
                    }
                }
                
                // Clear the request marker
                [strongSelf.currentIconURLRequests removeObjectForKey:iconListURLString];
            });
        });
    }
}

/**
 * Returns the URL for a given message's list view icon (or nil if not set).
 */
- (NSString *)iconURLStringForMessage:(UAInboxMessage *) message {
    NSDictionary *icons = [message.rawMessageObject objectForKey:@"icons"];
    return [icons objectForKey:@"list_icon"];
}

@end
