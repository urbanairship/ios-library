/* Copyright Airship and Contributors */

#import "UADefaultMessageCenterListViewController.h"
#import "UAMessageCenterListCell.h"
#import "UADefaultMessageCenterMessageViewController.h"
#import "UAInboxMessage.h"
#import "UAMessageCenter.h"
#import "UAInboxMessageList.h"
#import "UAMessageCenterLocalization.h"
#import "UAMessageCenterStyle.h"
#import "UAMessageCenterResources.h"

#import "UAAirshipMessageCenterCoreImport.h"

/*
 * List-view image controls: default image path and cache values
 */
#define kUAPlaceholderIconImage @"ua-inbox-icon-placeholder"
#define kUAIconImageCacheMaxCount 100
#define kUAIconImageCacheMaxByteCost (2 * 1024 * 1024) /* 2MB */
#define kUAMessageCenterListCellNibName @"UAMessageCenterListCell"

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
 * The currently selected index path.
 */
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

/**
 * The currently selected message.
 */
@property (nonatomic, strong) UAInboxMessage *selectedMessage;

/**
 * The an array of currently selected message IDs during editing.
 */
@property (nonatomic, strong) NSMutableArray<NSString *> *selectedMessageIDs;

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

/**
 * The message view's navigation controller to use for applying styles.
 */
@property (nonatomic, strong) UINavigationController *messageViewNavigationController;

/**
 * The previous navigation bar style. Used for resetting the bar style to the style set before message center display.
 * Note: 0 for default Bar style, 1 for black bar style.
 */
@property (nonatomic, strong, nullable) NSNumber *previousNavigationBarStyle;

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
    
    // if "Edit" has been localized, use it, otherwise use iOS's UIBarButtonSystemItemEdit
    if (UAMessageCenterLocalizedStringExists(@"ua_edit")) {
        self.editItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_edit")
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(editButtonPressed:)];
    } else {
        self.editItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                      target:self
                                                                      action:@selector(editButtonPressed:)];
    }
    
    self.cancelItem = [[UIBarButtonItem alloc]
                       initWithTitle:UAMessageCenterLocalizedString(@"ua_cancel")
                       style:UIBarButtonItemStyleDone
                       target:self
                       action:@selector(cancelButtonPressed:)];

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
    
    // create a messageViewController
    [self createMessageViewController];

    // watch for changes to the message list
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageListUpdated)
                                                 name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self restoreNavigationBarStyle];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationItem.backBarButtonItem = nil;

    [self setNavigationBarStyle];

    [self reload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.editing) {
        return;
    }

    if ([self.delegate shouldDeselectActiveCellWhenAppearing]) {
        self.selectedMessage = nil;
        self.selectedIndexPath = nil;
    }

    [self handlePreviouslySelectedIndexPathsAnimated:YES];
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

- (void)setStyle:(UAMessageCenterStyle *)style {
    _style = style;
    
    [self applyStyle];
}

- (void)applyStyle {
    if (self.style.editButtonTitleColor) {
        self.editItem.tintColor = self.style.editButtonTitleColor;
    }
    
    if (self.style.cancelButtonTitleColor) {
        self.cancelItem.tintColor = self.style.cancelButtonTitleColor;
    }
    
    if (self.style.listColor) {
        self.messageTable.backgroundColor = self.style.listColor;
        self.refreshControl.backgroundColor = self.style.listColor;
    } else if (@available(iOS 13.0, *)) {
        self.messageTable.backgroundColor = [UIColor systemBackgroundColor];
        self.refreshControl.backgroundColor = [UIColor systemBackgroundColor];
    }
    
    if (self.style.cellSeparatorColor) {
        self.messageTable.separatorColor = self.style.cellSeparatorColor;
    } else if (@available(iOS 13.0, *)) {
        self.messageTable.separatorColor = [UIColor separatorColor];
    }
    
    if (self.style.refreshTintColor) {
        self.refreshControl.tintColor = self.style.refreshTintColor;
    }
    
    [self applyToolbarItemStyles];
    
    [self applyMessageViewNavBarStyles];

    // apply styles to table cells
    [self.messageTable reloadData];
}

- (void)applyToolbarItemStyles {

    // Override any inherited tint color, to avoid potential clashes
    self.selectAllButtonItem.tintColor = (self.style.selectAllButtonTitleColor) ? self.style.selectAllButtonTitleColor : self.defaultTintColor;

    UIColor *red;
    if (@available(iOS 13.0, *)) {
        red = [UIColor systemRedColor];
    } else {
        red = [UIColor redColor];
    }

    self.deleteItem.tintColor = (self.style.deleteButtonTitleColor) ? self.style.deleteButtonTitleColor : red;

    self.markAsReadButtonItem.tintColor = (self.style.markAsReadButtonTitleColor) ? self.style.markAsReadButtonTitleColor : self.defaultTintColor;
}

- (void)restoreNavigationBarStyle {
    // Restore the previous style to the containing navigation controller
    if (self.style && self.style.navigationBarStyle && self.previousNavigationBarStyle) {
        self.navigationController.navigationBar.barStyle = (UIBarStyle)[self.previousNavigationBarStyle intValue];
    }

    self.previousNavigationBarStyle = nil;
}

// Note: This method should only be called once in viewWillAppear or it may not fuction as expected
- (void)setNavigationBarStyle {
    if (self.style && self.style.navigationBarStyle) {
        // Save the previous style of containing navigation controller, and set specified style
        if (!self.previousNavigationBarStyle) {
            // Only set once to prevent overwriting from multiple calls
            self.previousNavigationBarStyle = @(self.navigationController.navigationBar.barStyle);
        }

        self.navigationController.navigationBar.barStyle = (UIBarStyle)self.style.navigationBarStyle;
        self.messageViewNavigationController.navigationBar.barStyle = (UIBarStyle)self.style.navigationBarStyle;
    }
}

- (void)applyMessageViewNavBarStyles {
    // apply styles to the message view's navigation bar
    if (self.style.navigationBarColor) {
        self.messageViewNavigationController.navigationBar.barTintColor = self.style.navigationBarColor;
    }

    if (self.style.tintColor) {
        self.messageViewNavigationController.navigationBar.tintColor = self.style.tintColor;
    }
    
    // Only apply opaque property if a style is set
    if (self.style) {
        self.messageViewNavigationController.navigationBar.translucent = !self.style.navigationBarOpaque;
    }

    NSMutableDictionary *titleAttributes = [NSMutableDictionary dictionary];
    
    if (self.style.titleColor) {
        titleAttributes[NSForegroundColorAttributeName] = self.style.titleColor;
    }
    
    if (self.style.titleFont) {
        titleAttributes[NSFontAttributeName] = self.style.titleFont;
    }

    if (titleAttributes.count) {
        self.messageViewNavigationController.navigationBar.titleTextAttributes = titleAttributes;
    }
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

    self.selectAllButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_select_all")
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(selectAllButtonPressed:)];

    self.deleteItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_delete")
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(batchUpdateButtonPressed:)];

    self.markAsReadButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_mark_read")
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self action:@selector(batchUpdateButtonPressed:)];

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
        [self handlePreviouslySelectedIndexPathsAnimated:NO];
    }
    
    // Hide message view if necessary
    if ((self.messages.count == 0) && (self.messageViewController == self.navigationController.visibleViewController)) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)handlePreviouslySelectedIndexPathsAnimated:(BOOL)animated {
    // If a cell was previously selected and there are messages to display
    if ((self.selectedMessage || self.selectedIndexPath) && (self.messages.count > 0)) {
        // find the index path for the message that is currently displayed
        NSIndexPath *indexPathOfCurrentlyDisplayedMessage = [self indexPathForMessage:self.messageViewController.message];
        if (indexPathOfCurrentlyDisplayedMessage) {
            // if the currently displayed message is still in the inbox list, select it
            self.selectedIndexPath = indexPathOfCurrentlyDisplayedMessage;
            self.selectedMessage = self.messageViewController.message;
        } else {
            // find the index path for the message that was selected
            NSIndexPath *indexPathofSelectedMessage = [self indexPathForMessage:self.selectedMessage];
            if (indexPathofSelectedMessage) {
                // if the selected message is still in the inbox list, select it
                self.selectedIndexPath = indexPathofSelectedMessage;
            } else {
                self.selectedIndexPath = [self validateIndexPath:self.selectedIndexPath];
                if (self.selectedIndexPath) {
                    self.selectedMessage = [self messageAtIndex:self.selectedIndexPath.row];
                } else {
                    self.selectedMessage = nil;
                }
            }
        }
        if (self.selectedIndexPath) {
            // make sure the row we want selected is selected
            self.selectedIndexPath = [self validateIndexPath:self.selectedIndexPath];
            if (!self.editing) {
                [self.messageTable selectRowAtIndexPath:self.selectedIndexPath animated:animated scrollPosition:UITableViewScrollPositionNone];
                [self.messageTable scrollToNearestSelectedRowAtScrollPosition:UITableViewScrollPositionNone animated:YES];
            }
        } else {
            // if we want no row selected, de-select row if there is one already selected
            [self deselectCurrentlySelectedIndexPathAnimated:animated];
        }
    } else {
        [self deselectCurrentlySelectedIndexPathAnimated:animated];
        self.selectedMessage = nil;
        self.selectedIndexPath = nil;
    }
}

- (void)deselectCurrentlySelectedIndexPathAnimated:(BOOL)animated {
    NSIndexPath *selectedIndexPath = [self.messageTable indexPathForSelectedRow];
    if (selectedIndexPath) {
        [self.messageTable deselectRowAtIndexPath:selectedIndexPath animated:animated];
    }
}

- (NSIndexPath *)validateIndexPath:(NSIndexPath *)indexPath {
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

- (NSIndexPath *)indexPathForMessage:(UAInboxMessage *)message {
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
    [self cancelButtonPressed:nil];

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

- (void)displayMessage:(UAInboxMessage *)message {
    if (message.isExpired) {
        UA_LDEBUG(@"Message expired");
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_content_error")
                                                                       message:UAMessageCenterLocalizedString(@"ua_mc_no_longer_available")
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                              }];

        [alert addAction:defaultAction];

        [self presentViewController:alert animated:YES completion:nil];

        message = nil;
    }

    self.selectedMessage = message;

    if (!message && !self.messageViewController) {
        // if we have no message, only continue on if we already have a messageViewController so it can
        // be updated. No reason to create a new one for a nil message.
        return;
    }

    [self.messageViewController loadMessageForID:message.messageID onlyIfChanged:YES];

    if (message) {
        // only display the message if there is a message to display
        [self displayMessageViewController];
    }
}

- (void)displayMessageForID:(NSString *)messageID {
    // See if the message is available on the device
    UAInboxMessage *message = [[UAMessageCenter shared].messageList messageForID:messageID];

    if (message) {
        [self displayMessage:message];
        return;
    }

    // message is not available in the device's inbox
    self.selectedIndexPath = nil;

    [self.messageViewController loadMessageForID:messageID onlyIfChanged:NO];

    self.selectedMessage = self.messageViewController.message;

    [self displayMessageViewController];
}

- (void)createMessageViewController {

    if (!self.messageViewController) {
        self.messageViewController = [[UADefaultMessageCenterMessageViewController alloc] initWithNibName:@"UAMessageCenterMessageViewController"
                                                                                            bundle:[UAMessageCenterResources bundle]];
        self.messageViewController.delegate = self;
    }

    // Pass on the close block to the message view controller if present, for compatibility with deprecated message view protocol
    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    if (self.closeBlock) {
        UA_WEAKIFY(self);
        void (^closeBlock)(BOOL) = ^(BOOL animated){
            UA_STRONGIFY(self)

            if (!self) {
                return;
            }

            // Call the close block if present
            if (self.closeBlock) {
                self.closeBlock(animated);
            } else {
                // Fallback to displaying the inbox
                [self.navigationController popViewControllerAnimated:animated];
            }
        };

        self.messageViewController.closeBlock = closeBlock;
    }
    #pragma GCC diagnostic pop
}

- (void)displayMessageViewController {
    // if message view is not already displaying, get it displayed
    if (self.messageViewController != self.navigationController.visibleViewController) {
        if (!self.messageViewNavigationController) {
            self.messageViewNavigationController = [[UINavigationController alloc] initWithRootViewController:self.messageViewController];
            
            [self applyMessageViewNavBarStyles];

            // note: not sure why this is necessary but the navigation controller isn't sized properly otherwise
            [self.messageViewNavigationController.view layoutSubviews];
        }
        [self showDetailViewController:self.messageViewNavigationController sender:self];
    }
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
        NSString *deleteStr = UAMessageCenterLocalizedString(@"ua_delete");
        NSString *markReadStr = UAMessageCenterLocalizedString(@"ua_mark_read");

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
            self.selectAllButtonItem.title = UAMessageCenterLocalizedString(@"ua_select_all");
        } else {
            self.selectAllButtonItem.title = UAMessageCenterLocalizedString(@"ua_select_none");
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

- (UAInboxMessage *)messageAtIndex:(NSUInteger)index {
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

- (UAInboxMessage *)messageForID:(NSString *)messageIDToFind {
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
    if (self.style.placeholderIcon) {
        return self.style.placeholderIcon;
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

    cell.style = self.style;
    UAInboxMessage *message = [self messageAtIndex:indexPath.row];
    [cell setData:message];

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

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath {
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
        self.selectedMessage = message;
        self.selectedIndexPath = indexPath;

        [self displayMessage:message];
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
    if (self.messageViewController.message) {
        // Default is to show the message that was already displayed
        UAInboxMessage *messageToDisplay = [self messageForID:self.messageViewController.message.messageID];

        // if the previously displayed message no longer exists, try to show the message that was previously selected
        if (!messageToDisplay && self.selectedMessage) {
            messageToDisplay = [self messageForID:self.selectedMessage.messageID];
        }

        // if that message no longer exists, try to show the message now at the previously selected index
        if (!messageToDisplay && self.selectedIndexPath) {
            messageToDisplay = [self messageForID:[self messageAtIndex:[self validateIndexPath:self.selectedIndexPath].row].messageID];
        }

        [self.messageViewController loadMessageForID:messageToDisplay.messageID onlyIfChanged:YES];

        self.selectedMessage = messageToDisplay;

        if (!messageToDisplay) {
            if (self.messageViewController == self.navigationController.visibleViewController) {
                [self.navigationController popViewControllerAnimated:YES];
            }
        }
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

#pragma mark - Message View Delegate

- (void)displayNoLongerAvailableAlertOnOK:(void (^)(void))okCompletion {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_content_error")
                                                                   message:UAMessageCenterLocalizedString(@"ua_mc_no_longer_available")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (okCompletion) {
                                                                  okCompletion();
                                                              }
                                                          }];

    [alert addAction:defaultAction];

    [self presentViewController:alert animated:YES completion:nil];

}

- (void)displayFailedToLoadAlertOnOK:(void (^)(void))okCompletion onRetry:(void (^)(void))retryCompletion {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_connection_error")
                                                                   message:UAMessageCenterLocalizedString(@"ua_mc_failed_to_load")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (okCompletion) {
                                                                  okCompletion();
                                                              }
                                                          }];

    [alert addAction:defaultAction];

    if (retryCompletion) {
        UIAlertAction *retryAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_retry_button")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
                                                                if (retryCompletion) {
                                                                    retryCompletion();
                                                                }
                                                            }];

        [alert addAction:retryAction];
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetUIState {
    [self.messageTable deselectRowAtIndexPath:self.selectedIndexPath animated:NO];
    self.selectedMessage = nil;
    self.selectedIndexPath = nil;

    // Hide message view if necessary
    if (self.messageViewController == self.navigationController.visibleViewController) {
        [self.navigationController popViewControllerAnimated:YES];
    }

    // refresh message list
    [[UAMessageCenter shared].messageList retrieveMessageListWithSuccessBlock:nil
                                                             withFailureBlock:nil];
}

- (void)messageLoadStarted:(NSString *)messageID {
    UA_LTRACE(@"message load started: %@", messageID);
}

- (void)messageLoadSucceeded:(NSString *)messageID {
    UA_LTRACE(@"message load succeeded: %@", messageID);
}

- (void)messageLoadFailed:(NSString *)messageID error:(NSError *)error {
    UA_LTRACE(@"message load failed: %@", messageID);

    void (^retry)(void) = ^{
        UA_WEAKIFY(self);
        [self displayFailedToLoadAlertOnOK:nil onRetry:^{
            UA_STRONGIFY(self);
            [self displayMessageForID:messageID];
        }];
    };

    void (^handleFailed)(void) = ^{
        UA_WEAKIFY(self);
        [self displayFailedToLoadAlertOnOK:^{
            UA_STRONGIFY(self);
            [self.messageViewController showMessageScreen];
        } onRetry:nil];
    };

    void (^handleExpired)(void) = ^{
        UA_WEAKIFY(self);
        [self displayNoLongerAvailableAlertOnOK:^{
            UA_STRONGIFY(self)
            [self.messageViewController showMessageScreen];
        }];
    };

    if ([error.domain isEqualToString:UAMessageCenterMessageLoadErrorDomain]) {
        if (error.code == UAMessageCenterMessageLoadErrorCodeFailureStatus) {
            // Encountered a failure status code
            NSUInteger status = [error.userInfo[UAMessageCenterMessageLoadErrorHTTPStatusKey] unsignedIntValue];

            if (status >= 500) {
                retry();
            } else if (status == 410) {
                // Gone: message has been permanently deleted from the backend.
                handleExpired();
            } else {
                handleFailed();
            }
        } else if (error.code == UAMessageCenterMessageLoadErrorCodeMessageExpired) {
            handleExpired();
        } else {
            retry();
        }
    }
    // Other/transport related errors
    retry();

    // Reset releated UI state
    [self resetUIState];
}

- (void)messageClosed:(NSString *)messageID {
    UA_LTRACE(@"message closed: %@", messageID);
    [self.navigationController popViewControllerAnimated:YES];
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

           [[UADispatcher mainDispatcher] dispatchAsync:^{
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

@end
