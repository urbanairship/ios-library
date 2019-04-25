/* Copyright Airship and Contributors */

#import "UAOverlayInboxMessageAction+Internal.h"
#import "UAActionArguments.h"
#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UAInboxUtils.h"
#import "UALandingPageAction+Internal.h"
#import "UAMessageCenter.h"
#import "UAConfig.h"
#import "UAUtils.h"

NSString * const UAOverlayInboxMessageActionMessageIDPlaceHolder  = @"auto";
NSString * const UAMessageURLKey = @"url";
NSString * const UAOverlayInboxMessageActionErrorDomain = @"UAOverlayInboxMessageActionError";

@implementation UAOverlayInboxMessageAction

// Parses the messageID url and prepends the correct message scheme if it's not already prepended
- (NSURL *)parseURLFromArguments:(UAActionArguments *)arguments {
    NSString *messageID;

    id value = arguments.value;

    if (value == nil) {
        return nil;
    }

    if ([value isKindOfClass:[NSString class]]) {
        messageID = arguments.value;
    }

    if ([value isKindOfClass:[NSDictionary class]]) {
        id urlValue = [arguments.value valueForKey:UAMessageURLKey];

        if (urlValue && [urlValue isKindOfClass:[NSString class]]) {
            messageID = urlValue;
        }
    }

    if ([messageID isEqualToString:@""]) {
        return nil;
    }

    if ([[messageID lowercaseString] isEqualToString:UAOverlayInboxMessageActionMessageIDPlaceHolder]) {
        if (arguments.metadata && arguments.metadata[UAActionMetadataInboxMessageKey]) {
            UAInboxMessage *message = arguments.metadata[UAActionMetadataInboxMessageKey];
            messageID = message.messageID;
        } else if (arguments.metadata && arguments.metadata[UAActionMetadataPushPayloadKey]) {
            NSDictionary *notification = arguments.metadata[UAActionMetadataPushPayloadKey];
            messageID = [UAInboxUtils inboxMessageIDFromNotification:notification];
        } else {
            return nil;
        }
    }

    if ([messageID.lowercaseString hasPrefix:[NSString stringWithFormat:@"%@:", UAMessageDataScheme]]) {
        return [NSURL URLWithString:messageID];
    }

    return [NSURL URLWithString:[NSString stringWithFormat:@"%@:%@", UAMessageDataScheme, messageID]];
}

@end
