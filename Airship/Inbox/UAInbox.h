/*
Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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
@class UAInboxAPIClient;


/**
 * A standard protocol for accessing native Objective-C functionality from your
 * Rich Push messages.
 *
 * UAInboxDefaultJSDelegate is a reference implementation of this protocol.
 *
 * @deprecated As of version 3.2. Replaced with UAJavaScriptDelegate.
 */
__attribute__((deprecated("As of version 3.2")))
@protocol UAInboxJavaScriptDelegate <NSObject>

/**
 * Delegates must implement this method. Implementations take an array of string arguments
 * and a dictionary of key-value pairs (all strings), process them, and return a string
 * containing Javascript that will be evaluated in a message's UIWebView.
 *
 * To pass information to the delegate from a message, insert links with a "ua" scheme,
 * args in the path and key-value option pairs in the query string. The host
 * portion of the URL is ignored.
 * 
 * The basic URL format:
 * ua://callback/<args>?<key/value options>
 *
 * For example, to pass in three args (arg1, arg2 and arg3) and three key-value
 * options {option1:one, option2:two, option3:three}:
 * ua://callback/arg1/arg2/arg3?option1=one&amp;option2=two&amp;option3=three
 *
 * The default implementation is UAInboxDefaultJSDelegate. It is designed to work with
 * the UACallback.js file that ships with the sample project.
 *
 * @param args Array of js delegate arguments
 * @param options Dictionary of js delegate options
 * @return Callback string indicating success or failure
 */ 
- (NSString *)callbackArguments:(NSArray *)args withOptions:(NSDictionary *)options;

@end


/**
 * The main class for interacting with the Rich Push Inbox.
 *
 * This class bridges library functionality with the UI and is the main point of interaction.
 * Most implementations will only use functionality found in this class.
 */
@interface UAInbox : NSObject

SINGLETON_INTERFACE(UAInbox);

/**
 * Tear down and clean up any resources. This method should be called when the inbox is no
 * longer needed.
 */
+ (void)land;

/**
 * The list of Rich Push Inbox messages.
 */
@property (nonatomic, strong) UAInboxMessageList *messageList;

/**
 * Handles incoming rich push messages.
 */
@property (nonatomic, strong) UAInboxPushHandler *pushHandler;

/**
 * The Inbox API Client
 */
@property (nonatomic, readonly, strong) UAInboxAPIClient *client;


/**
 * The user-configurable JavaScript delegate, implementing
 * the deprecated UAInboxJavaScriptDelegate protocol.
 * 
 * NOTE: this delegate is not retained.
 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@property (nonatomic, weak) id<UAInboxJavaScriptDelegate> jsDelegate;
#pragma clang diagnostic pop

@end
