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
#import "UAInAppMessageController.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAActionRegistry.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore.h"
#import "UAInAppDisplayEvent.h"
#import "UAAnalytics.h"

@interface UAInAppMessageAction ()
@property(nonatomic, strong) UAInAppMessageController *messageController;
@end

@implementation UAInAppMessageAction

NSString *const UALastDisplayedInAppMessageID = @"UALastDisplayedInAppMessageID";


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

    NSDictionary *launchNotification = [UAirship push].launchNotification;

    // If the pending payload ID does not match the launchNotification's send ID
    if ([message.identifier isEqualToString:launchNotification[@"_"]]) {
        UA_LINFO(@"The in-app message delivery push was directly launched for message: %@", message);
        [UAInAppMessage deletePendingMessagePayload:arguments.value];
        return;
    }

    // Check if the message is expired
    if (message.expiry && [[NSDate date] compare:message.expiry] == NSOrderedDescending) {
        UA_LINFO(@"In-app message is expired: %@", message);
        [UAInAppMessage deletePendingMessagePayload:arguments.value];
        return;
    }

    // If it's not currently displayed
    if ([message isEqualToMessage:self.messageController.message]) {
        UA_LDEBUG(@"In-app message already displayed: %@", message);
        return;
    }

    // Send a display event if its the first time we are displaying this IAM
    NSString *lastDisplayedIAM = [[UAirship shared].dataStore valueForKey:UALastDisplayedInAppMessageID];
    if (message.identifier && ![message.identifier isEqualToString:lastDisplayedIAM]) {
        UAInAppDisplayEvent *event = [UAInAppDisplayEvent eventWithMessage:message];
        [[UAirship shared].analytics addEvent:event];

        // Set the ID as the last displayed so we dont send duplicate display events
        [[UAirship shared].dataStore setValue:message.identifier forKey:UALastDisplayedInAppMessageID];
    }

    UA_LINFO(@"Displaying in-app message: %@", message);
    UAInAppMessageController *messageController = [[UAInAppMessageController alloc] initWithMessage:message dismissalBlock:^{
        // Delete the pending payload once it's dismissed
        [UAInAppMessage deletePendingMessagePayload:arguments.value];
    }];

    // Dismiss any existing message and show the new one
    [self.messageController dismiss];
    self.messageController = messageController;
    [messageController show];
}

/**
 * Helper method to handle saving the in-app message to display later.
 * @param arguments The action arguments.
 */
- (void)savePendingMessageWithArguments:(UAActionArguments *)arguments {
    // Set the send ID as the IAM unique identifier
    NSDictionary *apnsPayload = arguments.metadata[UAActionMetadataPushPayloadKey];
    NSMutableDictionary *messagePayload = [NSMutableDictionary dictionaryWithDictionary:arguments.value];
    if (apnsPayload[@"_"]) {
        messagePayload[@"identifier"] = apnsPayload[@"_"];
    }

    // Store it for later
    UA_LINFO(@"Storing in-app message to display on next foreground: %@.", messagePayload);
    [UAInAppMessage storePendingMessagePayload:messagePayload];
}

@end
