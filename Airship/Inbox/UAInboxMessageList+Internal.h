/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import "UAInboxMessageList.h"
#import "UAInboxAPIClient+Internal.h"

@class UAInboxDBManager;

NS_ASSUME_NONNULL_BEGIN

@interface UAInboxMessageList ()

@property (nonatomic, strong) UAInboxAPIClient *client;
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) UAInboxDBManager *inboxDBManager;

@property (atomic, assign) NSUInteger batchOperationCount;
@property (atomic, assign) NSUInteger retrieveOperationCount;
@property (nonatomic, strong) NSArray<UAInboxMessage *> *messages;
@property (nonatomic, strong) NSDictionary *messageIDMap;
@property (nonatomic, strong) NSDictionary *messageURLMap;

/**
 * Loads the inbox with the current saved messages.
 */
- (void)loadSavedMessages;

+ (instancetype)messageListWithUser:(UAUser *)user
                             client:(UAInboxAPIClient *)client
                             config:(UAConfig *)config;

@end

NS_ASSUME_NONNULL_END
