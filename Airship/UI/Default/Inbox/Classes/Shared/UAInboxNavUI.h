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

#import <Foundation/Foundation.h>

#import "UAViewUtils.h"
#import "UAInboxAlertHandler.h"
#import "UAInbox.h"

#import "UAInboxMessageListController.h"
#import "UAInboxMessageViewController.h"

#import "UAInboxPushHandler.h"

#ifndef UA_INBOX_TR
#define UA_INBOX_TR(key) [[UAInboxNavUI shared].localizationBundle localizedStringForKey:key value:@"" table:nil]
#endif

@class UAInboxAlertProtocol;

/**
 * This class is an alternative rich push UI impelementation.  When it is
 * designated as the [UAInbox uiClass], launching the inbox will cause it
 * to be displayed in either a navigation controller (in the iPhone UI idiom)
 * or a popover controller (in the iPad UI idiom).
 */
@interface UAInboxNavUI : NSObject <UAInboxUIProtocol, UAInboxPushHandlerDelegate, UIPopoverControllerDelegate> {
  @private
    NSBundle *localizationBundle;
	UAInboxAlertHandler *alertHandler;
    UIViewController *rootViewController;
    
    UIViewController *inboxParentController;
    UINavigationController *navigationController;
    UAInboxMessageViewController *messageViewController;
    UAInboxMessageListController *messageListController;
    
    UIPopoverController *popoverController;
    UIBarButtonItem *popoverButton;
    
    BOOL useOverlay;
    BOOL isVisible;
    
    CGSize popoverSize;
}

/**
 * Set this property to YES if the class should display in-app messages
 * using UAInboxOverlayController, and NO if it should navigate to the
 * inbox and display the message as though it had been selected.
 */
@property (nonatomic, assign) BOOL useOverlay;

/**
 * The size of the UIPopoverController's window.
 * Defaults to 320 x 1100.
 */
@property (nonatomic, assign) CGSize popoverSize;

@property (nonatomic, retain) UIBarButtonItem *popoverButton;

@property (nonatomic, retain) UIPopoverController *popoverController;

@property (nonatomic, retain) UIViewController *inboxParentController;

@property (nonatomic, retain) UINavigationController *navigationController;

@property (nonatomic, retain) UAInboxMessageViewController *messageViewController;
@property (nonatomic, retain) UAInboxMessageListController *messageListController;

@property (nonatomic, retain) NSBundle *localizationBundle;


SINGLETON_INTERFACE(UAInboxNavUI);

+ (void)quitInbox;
- (void)quitInbox;
- (void)newMessageArrived:(NSDictionary *)message;
+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)displayMessage:(UIViewController *)viewController message:(NSString*)messageID;
+ (void)setRuniPhoneTargetOniPad:(BOOL)value;
+ (void)land;
+ (void)loadLaunchMessage;

@end
