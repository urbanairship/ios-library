/* Copyright Airship and Contributors */

#import "UAMessageCenterAction.h"
#import "UAActionArguments.h"
#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UAInboxUtils.h"
#import "UAMessageCenter.h"
#import "UADispatcher+Internal.h"

#define kUAMessageCenterActionMessageIDPlaceHolder @"auto"

@implementation UAMessageCenterAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    switch (arguments.situation) {
        case UASituationManualInvocation:
        case UASituationWebViewInvocation:
        case UASituationLaunchedFromPush:
        case UASituationForegroundInteractiveButton:
        case UASituationAutomation:
            return YES;
        case UASituationBackgroundPush:
        case UASituationForegroundPush:
        case UASituationBackgroundInteractiveButton:
            return NO;
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    // Parse the message ID
    NSString *messageID = [UAMessageCenterAction parseMessageIDFromArgs:arguments];

    [[UADispatcher mainDispatcher] dispatchAsync:^{
        id<UAInboxDelegate> inboxDelegate = [UAirship inbox].delegate;

        if (!messageID) {
            if ([inboxDelegate respondsToSelector:@selector(showInbox)]) {
                [inboxDelegate showInbox];
            } else {
                [[UAirship messageCenter] display];
            }
        } else {
            if ([inboxDelegate respondsToSelector:@selector(showMessageForID:)]) {
                [inboxDelegate showMessageForID:messageID];
            } else {
                [[UAirship messageCenter] displayMessageForID:messageID];
            }
        }

        completionHandler([UAActionResult emptyResult]);
    }];
}


+ (NSString *)parseMessageIDFromArgs:(UAActionArguments *)arguments {
    NSString *messageID = [UAInboxUtils inboxMessageIDFromValue:arguments.value];

    if ([kUAMessageCenterActionMessageIDPlaceHolder caseInsensitiveCompare:messageID] == NSOrderedSame) {
        if (arguments.metadata[UAActionMetadataInboxMessageIDKey]) {
            messageID = arguments.metadata[UAActionMetadataInboxMessageIDKey];
        } else {
            // Try getting the message ID from the push notification
            NSDictionary *notification = arguments.metadata[UAActionMetadataPushPayloadKey];
            messageID = [UAInboxUtils inboxMessageIDFromNotification:notification];
        }
    }

    if (messageID.length) {
        return messageID;
    }

    return nil;
}

@end
