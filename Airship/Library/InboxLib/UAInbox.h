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

#import "UAGlobal.h"

@class UAInboxMessageList;
@class UAInboxPushHandler;

#define INBOX_UI_CLASS @"UAInboxUI"

UA_VERSION_INTERFACE(UAInboxVersion)

/**
 * All UIs should implement this protocol to interact with the UAInbox object.
 */
@protocol UAInboxUIProtocol
@required

/** 
 * Hide the inbox UI and perform any resource cleanup.
 */
+ (void)quitInbox;

/**
 * Open the Rich Push Inbox directly to the message associated with
 * the push notification that launched or foregrounded the application.
 */
+ (void)loadLaunchMessage;

/**
 * Display the inbox UI.
 *
 * @param viewController The parent view controller
 * @param animated YES to animate the transition
 */
+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated;

/**
 * Display the inbox UI and open a specific message.
 *
 * @param viewController The parent view controller
 * @param messageID The ID for the message to display
 */
+ (void)displayMessage:(UIViewController *)viewController message:(NSString*)messageID;

@end


/**
 * A standard protocol for accessing native Objective-C functionality from your
 * Rich Push messages.
 *
 * UAInboxDefaultJSDelegate is a reference implementation of this protocol.
 */
@protocol UAInboxJavaScriptDelegate <NSObject>

// Template implementation in UAInboxDefaultJSDelegate.m
- (NSString *)callbackArguments:(NSArray *)args withOptions:(NSDictionary *)options;

@end


/**
 * The main class for interacting with the Rich Push Inbox.
 *
 * This class bridges library functionaly and UI and is the main point of interaction.
 * Most implementations will only use functionality found in this class.
 */
@interface UAInbox : NSObject {

    UAInboxMessageList *messageList;
	UAInboxPushHandler *pushHandler;
	
    id<UAInboxJavaScriptDelegate> jsDelegate;
    
	NSURLCache *clientCache;
    NSURLCache *inboxCache;
}

SINGLETON_INTERFACE(UAInbox);

///---------------------------------------------------------------------------------------
/// @name Custom UI Specification
///---------------------------------------------------------------------------------------

/** Get the current UI class. Defaults to UAInboxUI. */
- (Class)uiClass;

/**
 * Set a custom UI class. Defaults to UAInboxUI.
 *
 * @param customUIClass The custom UI class. The class must implement the UAInboxUIProtocol.
 */
+ (void)useCustomUI:(Class)customUIClass;

/**
 * Hides the Rich Push Inbox UI and cleans up as necessary.
 *
 * Calls [UAInboxUIProtocol quitInbox] on the UI class.
 */
+ (void)quitInbox;

/**
 * Display the inbox UI.
 *
 * Calls [UAInboxUIProtocol displayInbox: animated:] on the UI class.
 *
 * @param viewController The parent view controller
 * @param animated YES to animate the transition
 */
+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated;

/**
 * Display the inbox UI and open a specific message.
 *
 * @param viewController The parent view controller
 * @param messageID The ID for the message to display
 *
 * Calls [UAInboxUIProtocol displayMessage: message:] on the UI class.
 */
+ (void)displayMessage:(UIViewController *)viewController message:(NSString*)messageID;

/**
 * Tear down and clean up any resources. This method should be called when the inbox is no
 * longer needed.
 */
+ (void)land;

// do away with this - it should be dictated by idiom
+ (void)setRuniPhoneTargetOniPad:(BOOL)value;

@property (nonatomic, assign) UAInboxMessageList *messageList;
@property (nonatomic, retain) UAInboxPushHandler *pushHandler;

/**
 * The Javascript delegate.
 * 
 * NOTE: this delegate is not retained.
 */
@property (nonatomic, assign) id<UAInboxJavaScriptDelegate> jsDelegate;

///---------------------------------------------------------------------------------------
/// @name URL Caches
///---------------------------------------------------------------------------------------

/**
 * The default URL Cache ([NSURLCache sharedURLCache]).
 * This is saved prior to switching the URL Cache to the inboxCache.
 */
@property(retain) NSURLCache *clientCache;

/**
 * An Inbox-specific URL cache used to cache the contents of 
 * Rich Push messages.
 */
@property(retain) NSURLCache *inboxCache;

@end
