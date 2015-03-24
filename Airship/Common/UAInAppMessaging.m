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

#import "UAInAppMessaging.h"
#import "UAInAppMessage.h"
#import "UAPreferenceDataStore.h"
#import "UAActionRunner.h"
#import "UAInAppMessageController.h"
#import "UAPush.h"
#import "UAirship+Internal.h"
#import "UAInAppDisplayEvent.h"
#import "UAAnalytics.h"
#import "UAInAppResolutionEvent.h"

NSString *const UALastDisplayedInAppMessageID = @"UALastDisplayedInAppMessageID";

// User defaults key for storing and retrieving pending messages
#define kUAPendingInAppMessageDataStoreKey @"UAPendingInAppMessage"

// Number of seconds to delay before displaying an in-app message
#define kUAInAppMessagingDelayBeforeInAppMessageDisplay 0.4

@interface UAInAppMessaging ()
@property(nonatomic, strong) UAInAppMessageController *messageController;
@end

@implementation UAInAppMessaging

- (instancetype)init {
    self = [super init];
    if (self) {
        self.font = [UIFont boldSystemFontOfSize:12];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:[UIApplication sharedApplication]];
    }
    return self;
}

- (void)applicationDidBecomeActive {
    // the pending in-app message, if present
    NSDictionary *pendingMessagePayload = [[UAirship inAppMessaging] pendingMessagePayload];
    if (pendingMessagePayload) {
        UA_LDEBUG(@"Dispatching in-app message action for message: %@.", pendingMessagePayload);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kUAInAppMessagingDelayBeforeInAppMessageDisplay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UAActionRunner runActionWithName:kUAInAppMessageActionDefaultRegistryName
                                        value:pendingMessagePayload
                                    situation:UASituationManualInvocation];
        });
    }
}

- (NSDictionary *)pendingMessagePayload {
    NSDictionary *payload = [[UAirship shared].dataStore objectForKey:kUAPendingInAppMessageDataStoreKey];
    return payload;
}

- (void)storePendingMessage:(UAInAppMessage *)message {

    // Discard if it's not a banner
    if (message.displayType != UAInAppMessageDisplayTypeBanner) {
        UA_LDEBUG(@"In-app message is not a banner, discarding: %@", message);
        return;
    }

    if ([self pendingMessagePayload]) {
        UAInAppMessage *previousPendingMessage = [UAInAppMessage messageWithPayload:[self pendingMessagePayload]];

        UAInAppResolutionEvent *event = [UAInAppResolutionEvent replacedResolutionWithMessage:previousPendingMessage
                                                                                  replacement:message];
        [[UAirship shared].analytics addEvent:event];
    }

    UA_LINFO(@"Storing in-app message to display on next foreground: %@.", message);
    [[UAirship shared].dataStore setObject:message.payload forKey:kUAPendingInAppMessageDataStoreKey];

    // Call the delegate, if needed
    id<UAInAppMessagingDelegate> strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(pendingMessageAvailable:)]) {
        [strongDelegate pendingMessageAvailable:message];
    };
}

- (void)deletePendingMessagePayload {
    [[UAirship shared].dataStore removeObjectForKey:kUAPendingInAppMessageDataStoreKey];
}

- (void)deletePendingMessage:(UAInAppMessage *)message {
    if ([[self pendingMessagePayload] isEqualToDictionary:message.payload]) {
        [self deletePendingMessagePayload];
    }
}

- (void)displayMessage:(UAInAppMessage *)message {

    NSDictionary *launchNotification = [UAirship push].launchNotification;

    // Discard if it's not a banner
    if (message.displayType != UAInAppMessageDisplayTypeBanner) {
        UA_LDEBUG(@"In-app message is not a banner, discarding: %@", message);
        return;
    }

    // If the pending payload ID does not match the launchNotification's send ID
    if ([message.identifier isEqualToString:launchNotification[@"_"]]) {
        UA_LINFO(@"The in-app message delivery push was directly launched for message: %@", message);
        [self deletePendingMessage:message];

        UAInAppResolutionEvent *event = [UAInAppResolutionEvent directOpenResolutionWithMessage:message];
        [[UAirship shared].analytics addEvent:event];

        return;
    }

    // Check if the message is expired
    if (message.expiry && [[NSDate date] compare:message.expiry] == NSOrderedDescending) {
        UA_LINFO(@"In-app message is expired: %@", message);
        [[UAirship inAppMessaging] deletePendingMessage:message];

        UAInAppResolutionEvent *event = [UAInAppResolutionEvent expiredMessageResolutionWithMessage:message];
        [[UAirship shared].analytics addEvent:event];

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
        [[UAirship inAppMessaging] deletePendingMessage:message];
    }];

    // Call the delegate, if needed
    id<UAInAppMessagingDelegate> strongDelegate = self.delegate;
    if ([strongDelegate respondsToSelector:@selector(messageWillBeDisplayed:)]) {
        [strongDelegate messageWillBeDisplayed:message];
    };

    // Dismiss any existing message and show the new one
    [self.messageController dismiss];
    self.messageController = messageController;
    [messageController show];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
