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

@class UAInboxMessage;

/**
 * The UAInboxMessageListObserver protocol declares methods that
 * are implemented by observers of a UAInboxMessageList object.
 *
 * An observer is notified when messages are modified, loaded or
 * fail to load or update.
 */
@protocol UAInboxMessageListObserver <NSObject>

@optional

/**
 * Tells an observer when a message list reload or update 
 * is initiated.
 */
- (void)messageListWillLoad;

/**
 * Tells an observer when the message list has successfully loaded
 * the latest information from Urban Airship's servers.
 */
- (void)messageListLoaded;

/**
 * TODO: deprecate/rename -- it's only called when a user update fails,
 * and a message is never passed along.
 */
- (void)inboxError:(NSString*)message;

/**
 * Tells the observer that a request for inbox messages failed.
 */
- (void)inboxLoadFailed;

/**
 * Tells the observer when a message or group of messages has been updated.
 * 
 * TODO: wrap the option in an NSValue, as the observer calls notifyObserver withObject
 * 
 @ @param option A UABatchUpdateCommand indicating the type 
 * of update performed. 
 */
- (void)messagesDidUpdateWithOption:(id)option;

/**
 * Tells the observer that a message has been marked as read.
 *
 * @param message The message marked as read
 */
- (void)singleMessageMarkAsReadFinished:(UAInboxMessage *)message;

/**
 * Tells the observer that a mark-as-read request failed.
 *
 * @param message The message that failed to update
 */
- (void)singleMessageMarkAsReadFailed:(UAInboxMessage *)message;

/**
 * TODO: unused -- necessary?
 */
- (void)newMessageArrived:(id)message delegate:(id)delegate;

@end