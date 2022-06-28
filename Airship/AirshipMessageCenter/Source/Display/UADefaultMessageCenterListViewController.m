/* Copyright Airship and Contributors */

#import "UADefaultMessageCenterListViewController.h"
#import "UAMessageCenterListCell.h"
#import "UAInboxMessage.h"
#import "UAMessageCenter.h"
#import "UAInboxMessageList.h"
#import "UAMessageCenterLocalization.h"
#import "UAMessageCenterStyle.h"
#import "UAMessageCenterResources.h"
#import "UAAirshipMessageCenterCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

/*
 * List-view image controls: default image path and cache values
 */
#define kUAPlaceholderIconImage @"ua-inbox-icon-placeholder"
#define kUAIconImageCacheMaxCount 100
#define kUAIconImageCacheMaxByteCost (2 * 1024 * 1024) /* 2MB */
#define kUAMessageCenterListCellNibName @"UAMessageCenterListCell"

NS_ASSUME_NONNULL_BEGIN

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
 * The messages displayed in the message table.
 */
@property (nonatomic, copy) NSArray *messages;

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
 * The an array of currently selected message IDs during editing.
 */
@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *selectedMessageIDs;

/**
 * A dictionary of sets of (NSIndexPath *) with absolute URLs (NSString *) for keys.
 * Used to track current list icon fetches.
 * Try to use this on the main thread.
 */
@property (nonatomic, strong) NSMutableDictionary *currentIconURLRequests;

/**
 * An icon cache that stores UIImage representations of fetched icon images
 * The default limit is 1MB or 100 items
 * Images are also stored in the Airship HTTP Cache, so a re-fetch will typically only
 * incur the decoding (PNG->UIImage) costs.
 */
@property (nonatomic, strong) NSCache *iconCache;

/**
 * A refresh control used for "pull to refresh" behavior.
 */
@property (nonatomic, strong) UIRefreshControl *refreshControl;

/**
 * The refresh control is still animating.
 */
@property (nonatomic, assign) BOOL refreshControlAnimating;

/**
 * A concurrent dispatch queue to use for fetching icon images.
 */
@property (nonatomic, strong) dispatch_queue_t iconFetchQueue;

@end

@implementation UADefaultMessageCenterListViewController


- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
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
    
    // if "Edit" has been localized, use it, otherwise use iOS's UIBarButtonSystemItemEdit
    self.editItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_edit_messages")
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(editButtonPressed:)];
    self.editItem.accessibilityHint = UAMessageCenterLocalizedString(@"ua_edit_messages_description");
    
    self.cancelItem = [[UIBarButtonItem alloc]
                       initWithTitle:UAMessageCenterLocalizedString(@"ua_cancel_edit_messages")
                       style:UIBarButtonItemStyleDone
                       target:self
                       action:@selector(cancelButtonPressed:)];
    self.cancelItem.accessibilityHint = UAMessageCenterLocalizedString(@"ua_cancel_edit_messages_description");

    self.navigationItem.rightBarButtonItem = self.editItem;

    [self createToolbarItems];

    [self.refreshControl addTarget:self action:@selector(refreshStateChanged:) forControlEvents:UIControlEventValueChanged];

    UITableViewController *tableController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    tableController.view = self.messageTable;
    tableController.refreshControl = self.refreshControl;
    tableController.clearsSelectionOnViewWillAppear = false;

    [self applyStyle];

    // This allows us to use the UITableViewController for managing the refresh control, while keeping the
    // outer chrome of the list view controller intact
    [self addChildViewController:tableController];
    
    // get initial list of messages in the inbox
    [self copyMessages];

    // watch for changes to the message list
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageListUpdated)
                                                 name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationItem.backBarButtonItem = nil;

    // Delay reloading by a beat to help selection/scrolling work more reliably
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reload];

        if (self.editing) {
            return;
        }

        if ([self.delegate shouldClearSelectionOnViewWillAppear]) {
            [self.messageTable deselectRowAtIndexPath:self.selectedIndexPath animated:YES];
            self.selectedIndexPath = nil;
        }
    });
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.iconCache removeAllObjects];
}

- (void)setFilter:(NSPredicate *)filter {
    _filter = filter;
}

- (void)setMessageCenterStyle:(UAMessageCenterStyle *)style {
    _messageCenterStyle = style;
    
    [self applyStyle];
}

#if !defined(__IPHONE_14_0)
- (void)setStyle:(UAMessageCenterStyle *)style {
    [self setMessageCenterStyle:style];
}
- (UAMessageCenterStyle *)style {
    return self.messageCenterStyle;
}
#endif

- (void)applyStyle {
    if (self.messageCenterStyle.editButtonTitleColor) {
        self.editItem.tintColor = self.messageCenterStyle.editButtonTitleColor;
    }
    
    if (self.messageCenterStyle.cancelButtonTitleColor) {
        self.cancelItem.tintColor = self.messageCenterStyle.cancelButtonTitleColor;
    }
    
    if (self.messageCenterStyle.listColor) {
        self.messageTable.backgroundColor = self.messageCenterStyle.listColor;
        self.refreshControl.backgroundColor = self.messageCenterStyle.listColor;
    } else if (@available(iOS 13.0, *)) {
        self.messageTable.backgroundColor = [UIColor systemBackgroundColor];
        self.refreshControl.backgroundColor = [UIColor systemBackgroundColor];
    }
    
    if (self.messageCenterStyle.cellSeparatorColor) {
        self.messageTable.separatorColor = self.messageCenterStyle.cellSeparatorColor;
    } else if (@available(iOS 13.0, *)) {
        self.messageTable.separatorColor = [UIColor separatorColor];
    }
    
    self.messageTable.separatorStyle = self.messageCenterStyle.cellSeparatorStyle;
    
    if (!UIEdgeInsetsEqualToEdgeInsets(self.messageCenterStyle.cellSeparatorInset, UIEdgeInsetsZero)) {
        self.messageTable.separatorInset = self.messageCenterStyle.cellSeparatorInset;
    }
    
    if (self.messageCenterStyle.refreshTintColor) {
        self.refreshControl.tintColor = self.messageCenterStyle.refreshTintColor;
    }
    
    [self applyToolbarItemStyles];

    // apply styles to table cells
    [self.messageTable reloadData];
}

- (void)applyToolbarItemStyles {

    // Override any inherited tint color, to avoid potential clashes
    self.selectAllButtonItem.tintColor = (self.messageCenterStyle.selectAllButtonTitleColor) ? self.messageCenterStyle.selectAllButtonTitleColor : self.defaultTintColor;

    UIColor *red;
    if (@available(iOS 13.0, *)) {
        red = [UIColor systemRedColor];
    } else {
        red = [UIColor redColor];
    }

    self.deleteItem.tintColor = (self.messageCenterStyle.deleteButtonTitleColor) ? self.messageCenterStyle.deleteButtonTitleColor : red;

    self.markAsReadButtonItem.tintColor = (self.messageCenterStyle.markAsReadButtonTitleColor) ? self.messageCenterStyle.markAsReadButtonTitleColor : self.defaultTintColor;
}

- (void)refreshStateChanged:(UIRefreshControl *)sender {
    if (sender.refreshing) {
        self.refreshControlAnimating = YES;
        UA_WEAKIFY(self)
        void (^retrieveMessageCompletionBlock)(void) = ^(void){
            [CATransaction begin];
            [CATransaction setCompletionBlock: ^{
                UA_STRONGIFY(self)

                // refresh animation has finished
                self.refreshControlAnimating = NO;
                [self chooseMessageDisplayAndReload];
            }];
            [sender endRefreshing];
            [CATransaction commit];
        };

        [[UAMessageCenter shared].messageList retrieveMessageListWithSuccessBlock:retrieveMessageCompletionBlock
                                                                 withFailureBlock:retrieveMessageCompletionBlock];
    } else {
        self.refreshControlAnimating = NO;
    }
}

- (void)createToolbarItems {

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                   target:nil
                                                                                   action:nil];

    self.selectAllButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_select_all_messages")
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(selectAllButtonPressed:)];
    self.selectAllButtonItem.accessibilityHint = UAMessageCenterLocalizedString(@"ua_select_all_messages_description");

    self.deleteItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_delete_messages")
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(batchUpdateButtonPressed:)];
    self.deleteItem.accessibilityHint = UAMessageCenterLocalizedString(@"ua_delete_messages_description");

    self.markAsReadButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_mark_messages_read")
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self action:@selector(batchUpdateButtonPressed:)];
    self.markAsReadButtonItem.accessibilityHint = UAMessageCenterLocalizedString(@"ua_mark_messages_read_description");

    [self applyToolbarItemStyles];
    
    self.toolbarItems = @[self.selectAllButtonItem, flexibleSpace, self.deleteItem, flexibleSpace, self.markAsReadButtonItem];
}

- (void)reload {
    [self.messageTable reloadData];
    
    if (self.editing) {
        if (self.selectedMessageIDs.count > 0) {
            // re-select previously selected cells
            NSMutableArray *reSelectedMessageIDs = [[NSMutableArray alloc] init];
            for (UAInboxMessage *message in self.messages) {
                if ([self.selectedMessageIDs containsObject:message.messageID]) {
                    NSIndexPath *selectedIndexPath = [self indexPathForMessage:message];
                    if (selectedIndexPath) {
                        [self.messageTable selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
                    }
                    [reSelectedMessageIDs addObject:message.messageID];
                }
            }
            [self.messageTable scrollToNearestSelectedRowAtScrollPosition:UITableViewScrollPositionNone animated:YES];
            self.selectedMessageIDs = reSelectedMessageIDs;
        }
    } else {
        [self handlePreviouslySelectedIndexPathsAnimated:YES];
    }
    
    // If there are no messages, select nothing
    if (self.messages.count == 0) {
        [self.delegate didSelectMessageWithID:nil];
    }
}

- (void)setSelectedMessageID:(nullable NSString *)selectedMessageID {
    if ([selectedMessageID isEqual:_selectedMessageID]) {
        return;
    }

    _selectedMessageID = selectedMessageID;

    if (selectedMessageID) {
        UAInboxMessage *selectedMessage = [[UAMessageCenter shared].messageList messageForID:selectedMessageID];

        self.selectedIndexPath = [self indexPathForMessage:selectedMessage];

        [self.messageTable selectRowAtIndexPath:self.selectedIndexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        [self.messageTable scrollToNearestSelectedRowAtScrollPosition:UITableViewScrollPositionNone animated:YES];
    } else {
        [self.messageTable deselectRowAtIndexPath:self.selectedIndexPath animated:NO];
        self.selectedIndexPath = nil;
    }
}

- (void)setSelectedIndexPath:(nullable NSIndexPath *)selectedIndexPath {
    _selectedIndexPath = selectedIndexPath;
}

- (void)handlePreviouslySelectedIndexPathsAnimated:(BOOL)animated {
    // If a cell was previously selected and there are messages to display
    if ((self.selectedIndexPath) && (self.messages.count > 0)) {
        UAInboxMessage *selectedMessage = [[UAMessageCenter shared].messageList messageForID:self.selectedMessageID];
        NSIndexPath *indexPath = [self indexPathForMessage:selectedMessage];
        [self.messageTable selectRowAtIndexPath:indexPath animated:animated scrollPosition:UITableViewScrollPositionNone];
        [self.messageTable scrollToNearestSelectedRowAtScrollPosition:UITableViewScrollPositionNone animated:animated];
    }
}

- (nullable NSIndexPath *)validateIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return nil;
    }
    if (self.messages.count == 0) {
        return nil;
    }
    if (indexPath.row >= self.messages.count) {
        return [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:indexPath.section];
    }
    if (indexPath.row < 0) {
        return [NSIndexPath indexPathForRow:0 inSection:indexPath.section];
    }
    return indexPath;
}

- (nullable NSIndexPath *)indexPathForMessage:(UAInboxMessage *)message {
    if (!message) {
        return nil;
    }
    NSUInteger row = [self indexOfMessage:message];
    NSIndexPath *indexPath;
    if (row != NSNotFound) {
        indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    }
    return indexPath;
}

// Called when batch editing begins/ends
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];

    if (editing) {
        self.selectedMessageIDs = [NSMutableArray array];
    } else {
        self.selectedMessageIDs = nil;
    }

    [self.messageTable reloadData];

    // Set allowsMultipleSelectionDuringEditing to YES only while
    // editing. This allows multi-select AND swipe to delete.
    UITableView *strongMessageTable = self.messageTable;
    strongMessageTable.allowsMultipleSelectionDuringEditing = editing;

    [self.navigationController setToolbarHidden:!editing animated:animated];

    // wait until after animation has completed before selecting previously selected row
    if (!editing) {
        if (animated) {
            [CATransaction begin];

            UA_WEAKIFY(self);
            [CATransaction setCompletionBlock: ^{
                UA_STRONGIFY(self);

                // cancel animation has finished
                [self handlePreviouslySelectedIndexPathsAnimated:NO];
            }];
        }
    }
    [strongMessageTable setEditing:editing animated:animated];

    if (!editing) {
        if (animated) {
            [CATransaction commit];
        } else {
            [self handlePreviouslySelectedIndexPathsAnimated:NO];
        }
    }
}

- (void)refreshAfterBatchUpdate {
    // end editing
    self.cancelItem.enabled = YES;
    [self cancelButtonPressed:self];

    // force button update
    [self refreshBatchUpdateButtons];
}

/**
 * Returns the number of unread messages in the specified set of index paths for the current table view.
 */
- (NSUInteger)countOfUnreadMessagesInIndexPaths:(NSArray *)indexPaths {
    NSUInteger count = 0;
    for (NSIndexPath *path in indexPaths) {
        if ([self messageAtIndex:path.row].unread) {
            ++count;
        }
    }
    return count;
}

#pragma mark -
#pragma mark Button Action Methods

- (void)selectAllButtonPressed:(id)sender {

    UITableView *strongMessageTable = self.messageTable;
    NSInteger rows = [strongMessageTable numberOfRowsInSection:0];

    NSIndexPath *currentPath;
    if (strongMessageTable.indexPathsForSelectedRows.count == rows) {
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

    if ([UAMessageCenter shared].messageList.isBatchUpdating) {
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
    NSMutableArray *selectedMessages = [NSMutableArray array];
    
    for (NSString *messageID in self.selectedMessageIDs) {
        // Add message by ID
        UAInboxMessage *selectedMessage = [[UAMessageCenter shared].messageList messageForID:messageID];
        if (selectedMessage) {
            [selectedMessages addObject:selectedMessage];
        }
    }

    self.cancelItem.enabled = NO;

    UA_WEAKIFY(self);
    if (sender == self.markAsReadButtonItem) {
        [[UAMessageCenter shared].messageList markMessagesRead:selectedMessages completionHandler:^{
            UA_STRONGIFY(self)
            [self refreshAfterBatchUpdate];
        }];
    } else {
        [[UAMessageCenter shared].messageList markMessagesDeleted:selectedMessages completionHandler:^{
            UA_STRONGIFY(self)
            [self refreshAfterBatchUpdate];
        }];
    }
}

- (void)refreshBatchUpdateButtons {
    if (self.editing) {
        NSString *deleteStr = UAMessageCenterLocalizedString(@"ua_delete_messages");
        NSString *markReadStr = UAMessageCenterLocalizedString(@"ua_mark_messages_read");

        UITableView *strongMessageTable = self.messageTable;
        NSUInteger count = strongMessageTable.indexPathsForSelectedRows.count;
        if (!count) {
            self.deleteItem.title = deleteStr;
            self.markAsReadButtonItem.title = markReadStr;
            self.deleteItem.enabled = NO;
            self.markAsReadButtonItem.enabled = NO;

        } else {
            self.deleteItem.title = [NSString stringWithFormat:@"%@ (%lu)", deleteStr, (unsigned long)count];

            NSUInteger unreadCountInSelection = [self countOfUnreadMessagesInIndexPaths:strongMessageTable.indexPathsForSelectedRows];
            self.markAsReadButtonItem.title = [NSString stringWithFormat:@"%@ (%lu)", markReadStr, (unsigned long)unreadCountInSelection];

            if ([UAMessageCenter shared].messageList.isBatchUpdating) {
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

        if (strongMessageTable.indexPathsForSelectedRows.count < [strongMessageTable numberOfRowsInSection:0]) {
            self.selectAllButtonItem.title = UAMessageCenterLocalizedString(@"ua_select_all_messages");
            self.selectAllButtonItem.accessibilityHint = UAMessageCenterLocalizedString(@"ua_select_all_messages_description");

        } else {
            self.selectAllButtonItem.title = UAMessageCenterLocalizedString(@"ua_select_none_messages");
            self.selectAllButtonItem.accessibilityHint = UAMessageCenterLocalizedString(@"ua_select_none_messages_description");
        }
    }
}

#pragma mark -
#pragma mark Methods to manage copy of inbox message list

- (void)copyMessages {
    if (self.filter) {
        self.messages = [NSArray arrayWithArray:[[UAMessageCenter shared].messageList.messages filteredArrayUsingPredicate:self.filter]];
    } else {
        self.messages = [NSArray arrayWithArray:[UAMessageCenter shared].messageList.messages];
    }
}

- (nullable UAInboxMessage *)messageAtIndex:(NSUInteger)index {
    if (index < self.messages.count) {
        return [self.messages objectAtIndex:index];
    } else {
        return nil;
    }
}

- (NSUInteger)indexOfMessage:(UAInboxMessage *)messageToFind {
    if (!messageToFind) {
        return NSNotFound;
    }
    
    for (NSUInteger index = 0;index<self.messages.count;index++) {
        UAInboxMessage *message = [self messageAtIndex:index];
        if ([messageToFind.messageID isEqualToString:message.messageID]) {
            return index;
        }
    }
    
    return NSNotFound;
}

- (nullable UAInboxMessage *)messageForID:(NSString *)messageIDToFind {
    if (!messageIDToFind) {
        return nil;
    } else {
        for (UAInboxMessage *message in self.messages) {
            if ([messageIDToFind isEqualToString:message.messageID]) {
                return message;
            }
        }
        return nil;
    }
}

- (void)deleteMessageAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        //require an index path (for safety with literal below)
        return;
    }

    UAInboxMessage *message = [self messageAtIndex:indexPath.row];
    
    if (message) {
        UA_WEAKIFY(self);
       [[UAMessageCenter shared].messageList markMessagesDeleted:@[message] completionHandler:^{
           UA_STRONGIFY(self)
           [self refreshAfterBatchUpdate];
        }];
    }
}

- (UIImage *)placeholderIcon {
    if (self.messageCenterStyle.placeholderIcon) {
        return self.messageCenterStyle.placeholderIcon;
    }

    if (! _placeholderIcon) {
        _placeholderIcon =[UIImage imageNamed:@"UAMessageCenterPlaceholderIcon.png" inBundle:[UAMessageCenterResources bundle] compatibleWithTraitCollection:nil];
    }
    return _placeholderIcon;
}

#pragma mark -
#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *nibName = kUAMessageCenterListCellNibName;
    NSBundle *bundle = [UAMessageCenterResources bundle];

    UAMessageCenterListCell *cell = (UAMessageCenterListCell *)[tableView dequeueReusableCellWithIdentifier:nibName];

    if (!cell) {
        cell = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];
    }

    cell.messageCenterStyle = self.messageCenterStyle;
    UAInboxMessage *message = [self messageAtIndex:indexPath.row];

    [cell setData:message];

    if (self.editing) {
        cell.accessibilityHint = UAMessageCenterLocalizedString(@"ua_message_cell_editing_description");
    } else {
        cell.accessibilityHint = UAMessageCenterLocalizedString(@"ua_message_cell_description");
    }

    UIImageView *localImageView = cell.listIconView;

    if ([self.iconCache objectForKey:[self iconURLStringForMessage:message]]) {
        localImageView.image = [self.iconCache objectForKey:[self iconURLStringForMessage:message]];
    } else {
        [self retrieveIconForIndexPath:indexPath iconSize:localImageView.frame.size];

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
    if (UITableViewCellEditingStyleDelete == editingStyle) {
        [self deleteMessageAtIndexPath:indexPath];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.messages.count == 0) {
        [self displayEmptyMessage];
    } else {
        [self hideEmptyMessage];
    }
    return (NSInteger)self.messages.count;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        return UITableViewCellEditingStyleNone;
    } else {
        if (self.selectedIndexPath) {
            [self.messageTable selectRowAtIndexPath:self.selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
       return UITableViewCellEditingStyleDelete;
    }
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    if (self.selectedIndexPath) {
        [self.messageTable selectRowAtIndexPath:self.selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(nullable NSIndexPath *)indexPath {
    if (self.selectedIndexPath) {
        [self.messageTable selectRowAtIndexPath:self.selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
    self.navigationItem.rightBarButtonItem.enabled = YES;
}

#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    UAInboxMessage *message = [self messageAtIndex:indexPath.row];

    if (self.editing) {
        [self.selectedMessageIDs addObject:message.messageID];
        [self refreshBatchUpdateButtons];
    } else {
        self.selectedMessageID = message.messageID;
        self.selectedIndexPath = indexPath;

        if (message) {
            [self.delegate didSelectMessageWithID:message.messageID];
        } else {
            UA_LWARN(@"No message found at index path: %@", indexPath);
        }
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        UAInboxMessage *message = [self messageAtIndex:indexPath.row];
        [self.selectedMessageIDs removeObject:message.messageID];
        [self refreshBatchUpdateButtons];
    }
}

#pragma mark -
#pragma mark NSNotificationCenter callbacks

- (void)messageListUpdated {
    // copy the back-end list of messages as it can change from under the UI
    [self copyMessages];

    if (!self.refreshControlAnimating) {
        [self chooseMessageDisplayAndReload];
    }
}

- (void)chooseMessageDisplayAndReload {
    UAInboxMessage *messageToDisplay;

    // try to select the message that at the previously selected index
    if (self.selectedMessageID) {
        messageToDisplay = [self messageForID:self.selectedMessageID];
    }

    // if that message no longer exists, try to select the message now at the previously selected index
    if (!messageToDisplay && self.selectedIndexPath) {
        messageToDisplay = [self messageForID:[self messageAtIndex:[self validateIndexPath:self.selectedIndexPath].row].messageID];
        [self.delegate didSelectMessageWithID:messageToDisplay.messageID];
    }

    self.selectedMessageID = messageToDisplay.messageID;

    // If there's no message to display, select nothing
    if (!messageToDisplay) {
        [self.delegate didSelectMessageWithID:nil];
    }

    [self reload];
    [self refreshBatchUpdateButtons];
}

#pragma mark -
#pragma mark List Icon Loading (UIScrollViewDelegate)

// A tap on the status bar will force a scroll to the top
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    return YES;
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
 * Retrieves the list view icon for a given index path, if available.
 */
- (void)retrieveIconForIndexPath:(NSIndexPath *)indexPath iconSize:(CGSize)iconSize {

    UAInboxMessage *message = [self messageAtIndex:indexPath.row];

    NSString *iconListURLString = [self iconURLStringForMessage:message];

    if (!iconListURLString) {
        // Nothing to do here
        return;
    }

    // If the icon isn't already in the cache
    if (![self.iconCache objectForKey:iconListURLString]) {

        NSURL *iconListURL = [NSURL URLWithString:iconListURLString];

        // NOTE: All add/remove operations on the cache & in-progress set should be done
        // on the main thread. They'll be cleared below in a dispatch_async/main queue block.

        // Next, check to see if we're currently requesting the icon
        // Add the index path to the set of paths to update when a request is completed and then proceed if necessary
        NSMutableSet *currentRequestedIndexPaths = [self.currentIconURLRequests objectForKey:iconListURLString];
        if (currentRequestedIndexPaths.count) {
            [currentRequestedIndexPaths addObject:indexPath];
            // Wait for the in-flight request to finish
            return;
        } else {
            // No in-flight request. Add and continue.
            [self.currentIconURLRequests setValue:[NSMutableSet setWithObject:indexPath] forKey:iconListURLString];
        }

        UA_WEAKIFY(self)

        dispatch_async(self.iconFetchQueue, ^{
            UA_STRONGIFY(self)

            UA_LTRACE(@"Fetching RP Icon: %@", iconListURLString);

            // Note: this decodes the source image at full size
            NSData *iconImageData = [NSData dataWithContentsOfURL:iconListURL];
            UIImage *iconImage = [UIImage imageWithData:iconImageData];
            iconImage = [self scaleImage:iconImage toSize:iconSize];

           [UADispatcher.main dispatchAsync:^{
                // Recapture self for the duration of this block
                UA_STRONGIFY(self)

                // Place the icon image in the cache and reload the row
                if (iconImage) {

                    NSUInteger sizeInBytes = CGImageGetHeight(iconImage.CGImage) * CGImageGetBytesPerRow(iconImage.CGImage);

                    [self.iconCache setObject:iconImage forKey:iconListURLString];
                    UA_LTRACE(@"Added image to cache (%@) with size in bytes: %lu", iconListURL, (unsigned long)sizeInBytes);

                    // Update cells directly rather than forcing a reload (which deselects)
                    UAMessageCenterListCell *cell;
                    for (NSIndexPath *indexPath in (NSSet *)[self.currentIconURLRequests objectForKey:iconListURLString]) {
                        cell = (UAMessageCenterListCell *)[self.messageTable cellForRowAtIndexPath:indexPath];
                        cell.listIconView.image = iconImage;
                    }
                }
                
                // Clear the request marker
                [self.currentIconURLRequests removeObjectForKey:iconListURLString];
           }];
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

#pragma mark -

-(void)displayEmptyMessage {
    UILabel *emptyMessage = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    [emptyMessage setText:UAMessageCenterLocalizedString(@"ua_empty_message_list")];
    if (@available(iOS 13.0, *)) {
        [emptyMessage setTextColor:[UIColor labelColor]];
    } else {
        [emptyMessage setTextColor:[UIColor blackColor]];
    }
    emptyMessage.numberOfLines = 0;
    [emptyMessage setTextAlignment:NSTextAlignmentCenter];
    [emptyMessage sizeToFit];
    [self.messageTable setBackgroundView:emptyMessage];
    [self.messageTable setSeparatorStyle:UITableViewCellSeparatorStyleNone];
}

-(void)hideEmptyMessage {
    [self.messageTable setBackgroundView:nil];
    [self.messageTable setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
}

@end

NS_ASSUME_NONNULL_END
