/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import "UAIncomingRichPushAction.h"
#import "UAInboxPushHandler+Internal.h"
#import "UAInbox.h"
#import "UAInboxUtils.h"
#import "UAInboxMessageList.h"

@implementation UAIncomingRichPushAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    switch (arguments.situation) {
        case UASituationLaunchedFromPush:
        case UASituationForegroundPush:
            return ([arguments.metadata objectForKey:UAActionMetadataPushPayloadKey]
                    && [UAInboxUtils getRichPushMessageIDFromValue:arguments.value]);
        default:
            return NO;
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments
                  actionName:(NSString *)actionName
           completionHandler:(UAActionCompletionHandler)completionHandler {

    NSDictionary *pushPayload = [arguments.metadata objectForKey:UAActionMetadataPushPayloadKey];
    
    
    UAInboxPushHandler *handler = [UAInbox shared].pushHandler;

    NSString *richPushID = [UAInboxUtils getRichPushMessageIDFromValue:arguments.value];

    UA_LDEBUG(@"Received push for rich message id %@", richPushID);
    handler.viewingMessageID = richPushID;

    id<UAInboxPushHandlerDelegate> strongDelegate = handler.delegate;

    switch (arguments.situation) {
        case UASituationForegroundPush:
            [strongDelegate richPushNotificationArrived:pushPayload];
            break;
        case UASituationLaunchedFromPush:
            handler.hasLaunchMessage = YES;
            [strongDelegate applicationLaunchedWithRichPushNotification:pushPayload];
            break;
        default:
            break;
    }

    [[UAInbox shared].messageList retrieveMessageListWithSuccessBlock:^{
        [handler messageListLoadSucceeded];
        completionHandler([UAActionResult resultWithValue:richPushID withFetchResult:UAActionFetchResultNewData]);
    } withFailureBlock:^{
        completionHandler([UAActionResult resultWithValue:richPushID withFetchResult:UAActionFetchResultFailed]);
    }];
}



@end
