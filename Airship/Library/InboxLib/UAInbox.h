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

#import "UAirship.h"
#import "UAGlobal.h"
#import "UA_Base64.h"
#import "UAInboxMessageList.h"
#import "UAInboxPushHandler.h"
#import "UAInboxAlertProtocol.h"

#define INBOX_UI_CLASS @"UAInboxUI"

UA_VERSION_INTERFACE(UAInboxVersion)

@protocol UAInboxUIProtocol
@required
+ (void)quitInbox;
+ (void)loadLaunchMessage;
+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)displayMessage:(UIViewController *)viewController message:(NSString*)messageID;
+ (id<UAInboxAlertProtocol>)getAlertHandler;
@end


@protocol UAInboxJavaScriptDelegate <NSObject>

// Template implementation in UAInboxDefaultJSDelegate.m
- (NSString *)callbackArguments:(NSArray *)args withOptions:(NSDictionary *)options;

@end


@interface UAInbox : NSObject {

    UAInboxMessageList *activeInbox;
	UAInboxPushHandler *pushHandler;
	
    id<UAInboxJavaScriptDelegate> jsDelegate;
	
    
	NSURLCache *clientCache, *inboxCache;
}

SINGLETON_INTERFACE(UAInbox);

- (Class)uiClass;
+ (void)useCustomUI:(Class)customUIClass;
+ (void)quitInbox;
+ (void)setInbox:(UAInboxMessageList *)inbox;
+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)displayInboxOnLoad:(UAInboxMessageList *)inbox;
+ (void)displayMessage:(UIViewController *)viewController message:(NSString*)messageID;
+ (void)land;
+ (void)addAuthToWebRequest:(NSMutableURLRequest*)requestObj;
+ (void)setRuniPhoneTargetOniPad:(BOOL)value;

@property (nonatomic, assign) UAInboxMessageList *activeInbox;
@property (nonatomic, retain) UAInboxPushHandler *pushHandler;
@property (nonatomic, assign) id<UAInboxJavaScriptDelegate> jsDelegate;
@property(retain) NSURLCache *clientCache, *inboxCache;

@end
