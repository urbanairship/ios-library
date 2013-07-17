/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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


#import "UAInboxPushHandler.h"
#import "UAirship.h"

#import "UAInbox.h"
#import "UAInboxUtils.h"
#import "UAInboxMessageList.h"
#import "UAAnalytics.h"
#import "UAEvent.h"


@implementation UAInboxPushHandler

- (void)dealloc {
    self.viewingMessageID = nil;
    [super dealloc];
}

+ (BOOL)isApplicationActive {
    return ([UIApplication sharedApplication].applicationState == UIApplicationStateActive);
}

+ (void)handleNotification:(NSDictionary *)userInfo{
    
    [UAInboxUtils getRichPushMessageIDFromNotification:userInfo withAction:^(NSString *richPushId){
        UA_LDEBUG(@"Received push for rich message id %@", richPushId);
        [UAInbox shared].pushHandler.viewingMessageID = richPushId;

        //if the app is in the foreground, let the UI class decide how it
        //wants to respond to the incoming push
        if ([self isApplicationActive]) {
            [[UAInbox shared].pushHandler.delegate richPushNotificationArrived:userInfo];
        }

        //otherwise, load the message list
        else {
            //this will result in calling loadLaunchMessage on the UI class
            //once the request is complete
            [UAInbox shared].pushHandler.hasLaunchMessage = YES;
            [[UAInbox shared].pushHandler.delegate applicationLaunchedWithRichPushNotification:userInfo];
        }

        [[UAInbox shared].messageList retrieveMessageList];
    }];
}

- (void)messageListLoaded {

    //only take action if there's a new message
    if(self.viewingMessageID) {

        UAInboxMessage *message = [[UAInbox shared].messageList messageForID:self.viewingMessageID];

        //if the notification came in while the app was backgrounded, treat it as a launch message
        if (self.hasLaunchMessage) {
            [self.delegate launchRichPushMessageAvailable:message];
            self.hasLaunchMessage = NO;
        }

        //otherwise, have the UI class display it
        else {
            [self.delegate richPushMessageAvailable:message];
        }

        self.viewingMessageID = nil;
    }
}
@end