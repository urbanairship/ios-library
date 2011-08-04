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

#import "UAInboxMessageViewControllerPad.h"
#import "UAInboxUI.h"

/*
@implementation UAInboxMessageViewControllerPad
@synthesize toolbar;
@synthesize landscapeToolbarItems;
@synthesize titleLabel;
@synthesize trashButton;

- (void)dealloc {
    [segmentNavItem release];
    [titleLabel release];
    [landscapeToolbarItems release];
    [toolbar release];
    [trashButton release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.landscapeToolbarItems = toolbar.items;
    // can not find the correct tint color for toolbar button item, also it does not have gradient effect
    //messageNav.tintColor = [UIColor colorWithHue:203/360.0 saturation:16/100.0 brightness:57/100.0 alpha:1];
    segmentNavItem = [[UIBarButtonItem alloc] initWithCustomView:messageNav];
}

- (void)viewDidUnload {
    self.landscapeToolbarItems = nil;
    [segmentNavItem release];
    segmentNavItem = nil;
}

// For split view controller
- (void)viewWillAppear:(BOOL)animated {
    // if inbox is displayed by other means, then adjust orientation before shown
    if ([UAInboxUI shared].uaWindow == nil) {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        ((UAInboxMessageListControllerPad *)[UAInboxUI shared].messageListController).firstRotate = UIInterfaceOrientationIsLandscape(orientation);
        [[self performSelector:@selector(splitViewController)] willRotateToInterfaceOrientation:orientation duration:0];
        [[self performSelector:@selector(splitViewController)] didRotateFromInterfaceOrientation:orientation];
    }

    [UAInboxUI shared].isVisible = YES;
    ((UAInboxMessageListControllerPad *)[UAInboxUI shared].messageListController).firstRotate = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [UAInboxUI shared].isVisible = NO;
}

- (void)refreshHeader {
    int index = [[UAInbox shared].messageList indexOfMessage:self.message];
    
    if (index >=0 && index < [[UAInbox shared].messageList messageCount]
        && ![UAInboxMessageList shared].isBatchUpdating && ![UAInboxUI shared].messageListController.editing) {
        self.trashButton.enabled = YES;
    } else {
        self.trashButton.enabled = NO;
    }

    [super refreshHeader];
}

- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    titleLabel.text = title;
}

- (IBAction)deleteButtonPressed:(id)sender {
    NSInteger index = [[UAInbox shared].messageList indexOfMessage:message];
    if (index == NSNotFound) {
        UALOG(@"message description=%@ is not found.", [message description]);
        return;
    }
    [[UAInboxUI shared].messageListController deleteMessageAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
}

- (void)loadMessageAtIndex:(int)index {
    [super loadMessageAtIndex:index];
    [[UAInboxUI shared].messageListController refreshBatchUpdateButtons];
}


#pragma mark -
#pragma mark Managing the popover bar button

- (void)showRootPopoverButtonItem:(UIBarButtonItem *)barButtonItem {
    // To portrait
    NSMutableArray *items = [NSMutableArray array];

    UIBarButtonItem *doneItem = [UAInboxUI shared].messageListController.doneItem;
    BOOL doneItemEnabled = doneItem.enabled;
    if (doneItem) {
        // workaround: need to set doneItem's property to default
        // before moving from navigation bar to tool bar
        doneItem.enabled = YES;
        [items addObject:doneItem];
    }

    [items addObject:barButtonItem];
    [items addObject:segmentNavItem];
    [items addObjectsFromArray:landscapeToolbarItems];
    toolbar.items = items;

    if (doneItem) {
        // workaround: need to reset doneItem's property
        // after moving from navigation bar to tool bar
        doneItem.style = UIBarButtonItemStyleDone;
        doneItem.enabled = doneItemEnabled;
    }
}

- (void)invalidateRootPopoverButtonItem:(UIBarButtonItem *)barButtonItem {
    // To landscape
    toolbar.items = landscapeToolbarItems;
}

@end */
