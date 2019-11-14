/* Copyright Airship and Contributors */

#import "UAInboxUtils.h"
#import "UAUtils.h"
#import "UAUserData.h"

#define kUARichPushMessageIDKey @"_uamid"

@implementation UAInboxUtils

+ (NSString *)inboxMessageIDFromNotification:(NSDictionary *)notification {
    // Get the inbox message ID, which can be sent as a one-element array or a string
    return [self inboxMessageIDFromValue:[notification objectForKey:kUARichPushMessageIDKey]];
}

+ (NSString *)inboxMessageIDFromValue:(id)values {
    id messageID = values;
    if ([messageID isKindOfClass:[NSArray class]]) {
        messageID = [(NSArray *)messageID firstObject];
    }

    return [messageID isKindOfClass:[NSString class]] ? messageID : nil;
}

+ (NSString *)userAuthHeaderString:(UAUserData *)userData {
    return [UAUtils authHeaderStringWithName:userData.username
                                    password:userData.password];
}

@end
