/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "UAIncomingInAppMessageAction.h"
#import "UAInAppMessage.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAActionRegistry.h"
#import "UAInAppMessaging.h"
#import "UAInboxUtils.h"
#import "UAirship.h"
#import "UAInAppResolutionEvent+Internal.h"
#import "UAAnalytics.h"

@implementation UAIncomingInAppMessageAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    switch (arguments.situation) {
        case UASituationBackgroundPush:
        case UASituationForegroundPush:
        case UASituationLaunchedFromPush:
        case UASituationBackgroundInteractiveButton:
        case UASituationForegroundInteractiveButton:
        case UASituationAutomation:
            return [arguments.value isKindOfClass:[NSDictionary class]];
        case UASituationManualInvocation:
        case UASituationWebViewInvocation:
            return NO;
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    switch (arguments.situation) {
        case UASituationBackgroundPush:
        case UASituationForegroundPush:
        case UASituationAutomation:
            // If the in-app message was received in the foreground or background
            // store it as pending
            [self savePendingMessageWithArguments:arguments];
            break;
        case UASituationLaunchedFromPush:
        case UASituationBackgroundInteractiveButton:
        case UASituationForegroundInteractiveButton:
            // The notification has been interacted by the user so
            // clear the pending message if it matches the one in the notification.
            [self clearPendingMessageWithArguments:arguments];
            break;
        default:
            UA_LDEBUG(@"Unexpected situation in arguments: %@", arguments);
            break;
    }

    completionHandler([UAActionResult emptyResult]);
}


/**
 * Helper method to dismiss the pending message if its ID matches the launch
 * notifications send ID.
 */
- (void)clearPendingMessageWithArguments:(UAActionArguments *)arguments {
    NSDictionary *apnsPayload = arguments.metadata[UAActionMetadataPushPayloadKey];
    NSString *sendId = apnsPayload[@"_"];

    UAInAppMessage *pending =  [UAirship inAppMessaging].pendingMessage;

    // Compare only the ID in case we amended the in-app message payload
    if (sendId.length && [sendId isEqualToString:pending.identifier]) {
        [UAirship inAppMessaging].pendingMessage = nil;

        UA_LINFO(@"The in-app message delivery push was directly launched for message: %@", pending);
        [[UAirship inAppMessaging] deletePendingMessage:pending];

        UAInAppResolutionEvent *event = [UAInAppResolutionEvent directOpenResolutionWithMessage:pending];
        [[UAirship shared].analytics addEvent:event];
    }
}

/**
 * Helper method to handle saving the in-app message to display later.
 * @param arguments The action arguments.
 */
- (void)savePendingMessageWithArguments:(UAActionArguments *)arguments {
    // Set the send ID as the IAM unique identifier
    NSDictionary *apnsPayload = arguments.metadata[UAActionMetadataPushPayloadKey];
    NSMutableDictionary *messagePayload = [NSMutableDictionary dictionaryWithDictionary:arguments.value];
    UAInAppMessage *message = [UAInAppMessage messageWithPayload:messagePayload];

    if (apnsPayload[@"_"]) {
        message.identifier = apnsPayload[@"_"];
    }

    NSString *inboxMessageID = [UAInboxUtils inboxMessageIDFromNotification:apnsPayload];
    if (inboxMessageID) {
        NSSet *inboxActionNames = [NSSet setWithArray:@[kUADisplayInboxActionDefaultRegistryAlias,
                                                        kUADisplayInboxActionDefaultRegistryName,
                                                        kUAOverlayInboxMessageActionDefaultRegistryAlias,
                                                        kUAOverlayInboxMessageActionDefaultRegistryName]];

        NSSet *actionNames = [NSSet setWithArray:message.onClick.allKeys];

        if (![actionNames intersectsSet:inboxActionNames]) {
            NSMutableDictionary *actions = [NSMutableDictionary dictionaryWithDictionary:message.onClick];
            actions[kUADisplayInboxActionDefaultRegistryAlias] = inboxMessageID;
            message.onClick = actions;
        }
    }

    // Store it for later
    [UAirship inAppMessaging].pendingMessage = message;
}

@end
