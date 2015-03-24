/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import "UADisplayInboxAction.h"
#import "UAActionArguments.h"
#import "UAInboxUtils.h"
#import "UAInboxPushHandler.h"
#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "UAirship.h"


@implementation UADisplayInboxAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    if (arguments.situation == UASituationBackgroundPush || arguments.situation == UASituationBackgroundInteractiveButton) {
        return NO;
    }

    return arguments.value == nil || [arguments.value isKindOfClass:[NSString class]];
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    NSString *messageID = [UAInboxUtils inboxMessageIDFromValue:arguments.value];
    UAInboxMessage *message = [[UAirship inbox].messageList messageForID:messageID];
    id<UAInboxPushHandlerDelegate> inboxDelegate = [UAirship inbox].pushHandler.delegate;

    if (message) {
        [inboxDelegate showInboxMessage:message];
    } else {
        [inboxDelegate showInbox];
    }

    completionHandler([UAActionResult emptyResult]);
}


@end
