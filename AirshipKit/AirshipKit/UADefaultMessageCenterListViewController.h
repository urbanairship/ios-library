/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import <UIKit/UIKit.h>

@class UAInboxMessage;
@class UADefaultMessageCenterStyle;

/**
 * Default implementation of a list-style Message Center UI.
 */
@interface UADefaultMessageCenterListViewController : UIViewController <UITableViewDelegate, UITableViewDataSource,
    UIScrollViewDelegate, UISplitViewControllerDelegate>

/**
 * The style to apply to the list.
 */
@property (nonatomic, strong) UADefaultMessageCenterStyle *style;

/**
 * An optional predicate for filtering messages.
 */
@property (nonatomic, strong) NSPredicate *filter;

/**
 * Block that will be invoked when a message view controller receives a closeWindow message
 * from the webView.
 */
@property (nonatomic, copy) void (^closeBlock)(BOOL animated);

/**
 * Displays a new message, either by updating the currently displayed message or
 * by navigating to a new one.
 *
 * @param message The message to load.
 */
- (void)displayMessage:(UAInboxMessage *)message;

@end
