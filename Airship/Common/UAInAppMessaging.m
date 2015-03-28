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

#import "UAInAppMessaging+Internal.h"
#import "UAInAppMessage.h"
#import "UAPreferenceDataStore.h"
#import "UAActionRunner.h"
#import "UAInAppMessageController.h"
#import "UAInAppDisplayEvent.h"
#import "UAAnalytics.h"
#import "UAInAppResolutionEvent.h"

NSString *const UALastDisplayedInAppMessageID = @"UALastDisplayedInAppMessageID";

// Number of seconds to delay before displaying an in-app message
#define kUAInAppMessagingDelayBeforeInAppMessageDisplay 3.0

@interface UAInAppMessaging ()
@property(nonatomic, strong) UAInAppMessageController *messageController;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UAAnalytics *analytics;
@property(nonatomic, strong) NSTimer *autoDisplayTimer;
@end

@implementation UAInAppMessaging

- (instancetype)initWithAnalytics:(UAAnalytics *)analytics
                        dataStore:(UAPreferenceDataStore *)dataStore {

    self = [super init];
    if (self) {
        self.font = [UIFont boldSystemFontOfSize:12];
        self.dataStore = dataStore;
        self.analytics = analytics;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:[UIApplication sharedApplication]];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];
    }

    return self;
}

+ (instancetype)inAppMessagingWithAnalytics:(UAAnalytics *)analytics
                                  dataStore:(UAPreferenceDataStore *)dataStore {

    return [[UAInAppMessaging alloc] initWithAnalytics:analytics
                                             dataStore:dataStore];
}

- (void)invalidateAutoDisplayTimer {
    // if we've already got a valid timer, invalidate it first
    if (self.autoDisplayTimer.isValid) {
        [self.autoDisplayTimer invalidate];
    }
    self.autoDisplayTimer = nil;
}

- (void)scheduleAutoDisplayTimer {
    [self invalidateAutoDisplayTimer];

    self.autoDisplayTimer = [NSTimer timerWithTimeInterval:kUAInAppMessagingDelayBeforeInAppMessageDisplay
                                                  target:self
                                                selector:@selector(displayPendingMessage)
                                                userInfo:nil
                                                 repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.autoDisplayTimer forMode:NSDefaultRunLoopMode];
}

- (void)applicationDidBecomeActive {
    if (self.isAutoDisplayEnabled) {
        [self scheduleAutoDisplayTimer];
    }
}

- (void)applicationDidEnterBackground {
    [self invalidateAutoDisplayTimer];
}

- (UAInAppMessage *)pendingMessage {
    NSDictionary *pendingMessagePayload = [self.dataStore objectForKey:kUAPendingInAppMessageDataStoreKey];
    if (pendingMessagePayload) {
        return [UAInAppMessage messageWithPayload:pendingMessagePayload];;
    }
    return nil;
}

- (void)setPendingMessage:(UAInAppMessage *)message {
    if (!message) {
        [self.dataStore setObject:message.payload forKey:kUAPendingInAppMessageDataStoreKey];
        return;
    }

    // Discard if it's not a banner
    if (message.displayType != UAInAppMessageDisplayTypeBanner) {
        UA_LDEBUG(@"In-app message is not a banner, discarding: %@", message);
        return;
    }

    UAInAppMessage *previousMessage = self.pendingMessage;

    if (previousMessage) {
        UAInAppResolutionEvent *event = [UAInAppResolutionEvent replacedResolutionWithMessage:previousMessage
                                                                                  replacement:message];
        [self.analytics addEvent:event];
    }

    UA_LINFO(@"Storing in-app message to display on next foreground: %@.", message);
    [self.dataStore setObject:message.payload forKey:kUAPendingInAppMessageDataStoreKey];

    // Call the delegate, if needed
    id<UAInAppMessagingDelegate> strongDelegate = self.messagingDelegate;
    if ([strongDelegate respondsToSelector:@selector(pendingMessageAvailable:)]) {
        [strongDelegate pendingMessageAvailable:message];
    };
}

- (BOOL)isAutoDisplayEnabled {
    if (![self.dataStore objectForKey:kUAAutoDisplayInAppMessageDataStoreKey]) {
        return YES;
    }

    return [self.dataStore boolForKey:kUAAutoDisplayInAppMessageDataStoreKey];
}

- (void)setAutoDisplayEnabled:(BOOL)autoDisplayEnabled {
    [self.dataStore setBool:autoDisplayEnabled forKey:kUAAutoDisplayInAppMessageDataStoreKey];
}

- (void)deletePendingMessage:(UAInAppMessage *)message {
    if ([self.pendingMessage isEqualToMessage:message]) {
        self.pendingMessage = nil;
    }
}

- (void)displayPendingMessage {
    [self displayMessage:self.pendingMessage];
}

- (void)displayMessage:(UAInAppMessage *)message {
    if (!message) {
        return;
    }

    // Discard if it's not a banner
    if (message.displayType != UAInAppMessageDisplayTypeBanner) {
        UA_LDEBUG(@"In-app message is not a banner, discarding: %@", message);
        return;
    }

    // Check if the message is expired
    if (message.expiry && [[NSDate date] compare:message.expiry] == NSOrderedDescending) {
        UA_LINFO(@"In-app message is expired: %@", message);
        [self deletePendingMessage:message];

        UAInAppResolutionEvent *event = [UAInAppResolutionEvent expiredMessageResolutionWithMessage:message];
        [self.analytics addEvent:event];

        return;
    }

    // If it's not currently displayed
    if ([message isEqualToMessage:self.messageController.message]) {
        UA_LDEBUG(@"In-app message already displayed: %@", message);
        return;
    }

    // Send a display event if its the first time we are displaying this IAM
    NSString *lastDisplayedIAM = [self.dataStore valueForKey:UALastDisplayedInAppMessageID];
    if (message.identifier && ![message.identifier isEqualToString:lastDisplayedIAM]) {
        UAInAppDisplayEvent *event = [UAInAppDisplayEvent eventWithMessage:message];
        [self.analytics addEvent:event];

        // Set the ID as the last displayed so we dont send duplicate display events
        [self.dataStore setValue:message.identifier forKey:UALastDisplayedInAppMessageID];
    }

    UA_LINFO(@"Displaying in-app message: %@", message);

    UAInAppMessageController *controller;
    controller = [UAInAppMessageController controllerWithMessage:message
                                                        delegate:self.messageControllerDelegate
                                                  dismissalBlock:^{
                                                      // Delete the pending payload once it's dismissed
                                                      [self deletePendingMessage:message];
                                                  }];

    // Call the delegate, if needed
    id<UAInAppMessagingDelegate> strongDelegate = self.messagingDelegate;
    if ([strongDelegate respondsToSelector:@selector(messageWillBeDisplayed:)]) {
        [strongDelegate messageWillBeDisplayed:message];
    };

    // Dismiss any existing message and show the new one
    [self.messageController dismiss];
    self.messageController = controller;
    [controller show];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
