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


#import <UIKit/UIKit.h>
#import "UAInboxMessageListObserver.h"
#import "UABarButtonSegmentedControl.h"

@interface UAInboxMessageListController : UIViewController <UITableViewDelegate, UITableViewDataSource, UAInboxMessageListObserver> {
    IBOutlet UITableView *messageTable;
    
    IBOutlet UIView *loadingView;
    IBOutlet UIActivityIndicatorView *activity;
    IBOutlet UILabel *loadingLabel;
    IBOutlet UILabel *noMessagesLabel;

    // navigation badge
    IBOutlet UITabBar *tabbar;
    IBOutlet UITabBarItem *tabbarItem;
    UIView *badgeView;

    NSMutableSet *selectedIndexPathsForEditing;
    UABarButtonSegmentedControl *deleteItem;
    UIBarButtonItem *moveItem;
    UIBarButtonItem *editItem;
    UIBarButtonItem *cancelItem;

    NSString *cellReusableId;
    NSString *cellNibName;
}

@property (nonatomic, retain) UITableView *messageTable;

@property (nonatomic, retain) UIView *loadingView;
@property (nonatomic, retain) UIActivityIndicatorView *activity;
@property (nonatomic, retain) UILabel *loadingLabel;
@property (nonatomic, retain) UILabel *noMessagesLabel;

@property (nonatomic, retain) UITabBarItem *tabbarItem;
@property (nonatomic, retain) UITabBar *tabbar;

- (void)updateNavigationBadge;      // indicate title and unread count
- (void)refreshBatchUpdateButtons;  // indicate edit mode view
- (void)deleteMessageAtIndexPath:(NSIndexPath *)indexPath;

// Private Method
- (void)createToolbarItems;
- (void)createNavigationBadge;
- (void)editButtonPressed:(id)sender;
- (void)cancelButtonPressed:(id)sender;
- (void)didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

@end
