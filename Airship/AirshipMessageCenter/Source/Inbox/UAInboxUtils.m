/* Copyright Airship and Contributors */

#import "UAInboxUtils.h"
#import "UAUserData.h"

#import "UAAirshipMessageCenterCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
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
