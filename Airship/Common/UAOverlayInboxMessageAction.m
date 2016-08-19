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

#import "UAOverlayInboxMessageAction.h"
#import "UAActionArguments.h"
#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UAInboxUtils.h"
#import "UALandingPageOverlayController.h"

#define kUAOverlayInboxMessageActionMessageIDPlaceHolder @"auto"

NSString * const UAOverlayInboxMessageActionErrorDomain = @"UAOverlayInboxMessageActionError";

@implementation UAOverlayInboxMessageAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    switch (arguments.situation) {
        case UASituationManualInvocation:
        case UASituationWebViewInvocation:
        case UASituationLaunchedFromPush:
        case UASituationForegroundInteractiveButton:
        case UASituationForegroundPush:
        case UASituationAutomation:
            if (![arguments.value isKindOfClass:[NSString class]]) {
                return NO;
            }

            if ([[arguments.value lowercaseString] isEqualToString:kUAOverlayInboxMessageActionMessageIDPlaceHolder]) {
                return arguments.metadata[UAActionMetadataPushPayloadKey] ||
                arguments.metadata[UAActionMetadataInboxMessageKey];
            }
            
            return YES;
        case UASituationBackgroundPush:
        case UASituationBackgroundInteractiveButton:
            return NO;
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    [self fetchMessage:arguments.value arguments:arguments completionHandler:^(UAInboxMessage *message, UAActionFetchResult result) {
        if (message) {
            // Fall back to landing page controller
            [UALandingPageOverlayController showMessage:message];
            completionHandler([UAActionResult resultWithValue:nil withFetchResult:result]);
        } else {
            NSError *error = [NSError errorWithDomain:UAOverlayInboxMessageActionErrorDomain
                                                 code:UAOverlayInboxMessageActionErrorCodeMessageUnavailable
                                             userInfo:@{NSLocalizedDescriptionKey:@"Message unavailable"}];

            completionHandler([UAActionResult resultWithError:error withFetchResult:result]);
        }

    }];
}

/**
 * Fetches the specified message. If the messageID is "auto", either
 * the UAActionMetadataInboxMessageKey will be returned or the ID of the message
 * will be taken from the UAActionMetadataPushPayloadKey. If the message is not
 * available in the message list, the list will be refreshed.
 * 
 * Note: A copy of this method exists in UADisplayInboxAction
 * 
 * @param messageID The message ID.
 * @param arguments The action arguments.
 * @param completionHandler Completion handler to call when the operation is complete.
 */
- (void)fetchMessage:(NSString *)messageID
           arguments:(UAActionArguments *)arguments
   completionHandler:(void (^)(UAInboxMessage *, UAActionFetchResult))completionHandler {

    if (messageID == nil) {
        completionHandler(nil, UAActionFetchResultNoData);
        return;
    }

    if ([[messageID lowercaseString] isEqualToString:kUAOverlayInboxMessageActionMessageIDPlaceHolder]) {
        // If we have InboxMessage metadata show the message
        if (arguments.metadata[UAActionMetadataInboxMessageKey]) {
            UAInboxMessage *message = arguments.metadata[UAActionMetadataInboxMessageKey];
            completionHandler(message, UAActionFetchResultNoData);
            return;
        }

        // Try getting the message ID from the push notification
        NSDictionary *notification = arguments.metadata[UAActionMetadataPushPayloadKey];
        messageID = [UAInboxUtils inboxMessageIDFromNotification:notification];
    }

    UAInboxMessage *message = [[UAirship inbox].messageList messageForID:messageID];
    if (message) {
        completionHandler(message, UAActionFetchResultNoData);
        return;
    }

    // Refresh the list to see if the message is available
    [[UAirship inbox].messageList retrieveMessageListWithSuccessBlock:^{
        completionHandler([[UAirship inbox].messageList messageForID:messageID], UAActionFetchResultNewData);
    } withFailureBlock:^{
        completionHandler(nil, UAActionFetchResultFailed);
    }];
}

@end
