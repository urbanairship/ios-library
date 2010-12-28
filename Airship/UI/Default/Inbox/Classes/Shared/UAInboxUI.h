/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.

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
#import "UAInboxMessageViewController.h"
#import "UAInboxMessageListController.h"
#import "UAInboxNavigationController.h"
#import "UAInboxMessageListControllerPad.h"
#import "UAInboxMessageViewControllerPad.h"
#import "UAViewUtils.h"
#import "UAInboxAlertHandler.h"

#define UA_INBOX_TR(key) [[UAInboxUI shared].localizationBundle localizedStringForKey:key value:@"" table:nil]

typedef enum {
    NORMAL_QUIT,
    DEVICE_TOKEN_ERROR,
    USER_ERROR,
} QuitReason;

@class UAInboxMessageViewController;
@class UAInboxAlertProtocol;

@interface UAInboxUI : NSObject <UAInboxUIProtocol> {
    UIViewController *rootViewController;
    UAInboxMessageViewController* messageViewController;
    UAInboxMessageListController* messageListController;
    NSBundle *localizationBundle;
    BOOL isVisible;
    BOOL isiPad;
    NSString *messageListTitle;
    UIWindow *uaWindow;
	UAInboxAlertHandler *alertHandler;
	UIViewController *inboxParentController;
}

@property (nonatomic, retain) UIViewController* rootViewController;
@property (nonatomic, retain) UAInboxMessageListController* messageListController;
@property (nonatomic, retain) UAInboxMessageViewController* messageViewController;
@property (nonatomic, retain) UIViewController* inboxParentController;
@property (nonatomic, retain) NSBundle *localizationBundle;
@property (assign) BOOL isVisible, isiPad;
@property (nonatomic, retain) NSString *messageListTitle;
@property (nonatomic, retain) UIWindow *uaWindow;

SINGLETON_INTERFACE(UAInboxUI);

+ (void)quitInbox;
- (void)quitInbox:(QuitReason)reason;
+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)displayMessage:(UIViewController *)viewController message:(NSString*)messageID;
+ (void)setRuniPhoneTargetOniPad:(BOOL)value;
+ (void)land;
+ (void)loadLaunchMessage;

@end
