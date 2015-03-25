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

#import "UAInAppMessageAction.h"
#import "UAInAppMessage.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAActionRegistry.h"
#import "UAInAppMessaging.h"
#import "UAInboxUtils.h"

@implementation UAInAppMessageAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    BOOL acceptsValue = [arguments.value isKindOfClass:[NSDictionary class]];

    // launching from push is not allowed
    BOOL acceptsSituation = arguments.situation != UASituationLaunchedFromPush;

    return acceptsValue && acceptsSituation;
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    if (arguments.situation == UASituationManualInvocation) {
        [self displayMessageWithArguments:arguments];
    } else {
        [self savePendingMessageWithArguments:arguments];
    }

    completionHandler([UAActionResult emptyResult]);
}


/**
 * Helper method to handle displaying the in-app message.
 * @param arguments The action arguments.
 */
- (void)displayMessageWithArguments:(UAActionArguments *)arguments {
    UAInAppMessage *message = [UAInAppMessage messageWithPayload:arguments.value];
    [[UAirship inAppMessaging] displayMessage:message];
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
    BOOL containsOpenInboxAction = message.onClick[kUADisplayInboxActionDefaultRegistryAlias] ||
        message.onClick[kUADisplayInboxActionDefaultRegistryName];

    if (inboxMessageID && !containsOpenInboxAction) {
        NSMutableDictionary *actions = [NSMutableDictionary dictionaryWithDictionary:message.onClick];
        actions[kUADisplayInboxActionDefaultRegistryAlias] = inboxMessageID;
        message.onClick = actions;
    }

    // Store it for later
    [UAirship inAppMessaging].pendingMessage = message;
}

@end
