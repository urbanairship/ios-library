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

#import "UAInboxMessageListControllerPad.h"
#import "UAInbox.h"
#import "UAInboxUI.h"

@implementation UAInboxMessageListControllerPad

@synthesize popoverController;
@synthesize rootPopoverButtonItem;
@synthesize firstRotate;

- (void)dealloc {
    [popoverController release];
    [rootPopoverButtonItem release];

    [super dealloc];
}

- (id)init {
    if (self = [super init]) {
        hasLoaded = NO;
        return self;
    }
    return nil;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 30200

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

// For batch update/delete
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [self.navigationController setToolbarHidden:!editing
                                       animated:![self.popoverController isPopoverVisible]];

    [super setEditing:editing animated:animated];
    [self refreshBatchUpdateButtons];
}

-(IBAction)done:(id)sender {
    [self.popoverController dismissPopoverAnimated:YES];
    [super done:sender];
}

- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[UAInboxUI shared].messageViewController loadMessageAtIndex:indexPath.row];
    [self.popoverController dismissPopoverAnimated:YES];
}

- (void)updateNavigationBadge {
    [super updateNavigationBadge];
    [[UAInboxUI shared].messageListController refreshBatchUpdateButtons];
}

#pragma mark -
#pragma mark UAInboxMessageListObserver

- (void)messageListLoaded {
    [super messageListLoaded];

    if (!hasLoaded) {
        // TODO:
        // Two cases: UAInbox launched from enclosing app, and launched directly by push notification. 
        // Here only load first message when first launched from enclosing app.
        [[UAInboxUI shared].messageViewController loadMessageAtIndex:0];
        hasLoaded = YES;
    }
}


#pragma mark -
#pragma mark Split View Controller Delegate

- (void)splitViewController:(UISplitViewController*)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem*)barButtonItem forPopoverController:(UIPopoverController*)pc {

    // Keep references to the popover controller and the popover button, and tell the detail view controller to show the button.
    barButtonItem.title = self.title;
    self.popoverController = pc;
    self.rootPopoverButtonItem = barButtonItem;
    barButtonItem.target = self;
    barButtonItem.action = @selector(popoverButtonPressed:);
    [self invalidateDoneButtonItem];
    [(UAInboxMessageViewControllerPad *)[UAInboxUI shared].messageViewController showRootPopoverButtonItem:rootPopoverButtonItem];
    firstRotate = NO;
}

- (void)splitViewController:(UISplitViewController*)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {

    // Nil out references to the popover controller and the popover button, and tell the detail view controller to hide the button.
    [(UAInboxMessageViewControllerPad *)[UAInboxUI shared].messageViewController invalidateRootPopoverButtonItem:rootPopoverButtonItem];
    [self showDoneButtonItem];
    self.popoverController = nil;
    self.rootPopoverButtonItem = nil;
    firstRotate = NO;
}

#pragma mark -
#pragma mark Button Action Methods

- (void)refreshBatchUpdateButtons {
    [super refreshBatchUpdateButtons];
    [[UAInboxUI shared].messageViewController refreshHeader];
}

#pragma mark Popover Button Action

- (void)popoverButtonPressed:(id)sender {
    if ([popoverController isPopoverVisible]) {
        [popoverController dismissPopoverAnimated:YES];
    } else {
        [popoverController presentPopoverFromBarButtonItem:sender
                                  permittedArrowDirections:UIPopoverArrowDirectionAny
                                                  animated:YES];
    }
}

#pragma mark -

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    // Workaround: delegate does not work for first rotation from portrait to landscape
    if (firstRotate) {
        [self splitViewController:nil willShowViewController:nil invalidatingBarButtonItem:nil];
    }
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

#endif

#pragma mark -

- (void)showDoneButtonItem {
	self.navigationItem.leftBarButtonItem = doneItem;
}

- (void)invalidateDoneButtonItem {
    self.navigationItem.leftBarButtonItem = nil;
}

@end
