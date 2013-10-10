
#import "UAInboxUtils.h"


@implementation UAInboxUtils

+ (NSString *)getRichPushMessageIDFromNotification:(NSDictionary *)notification {
    // Get the rich push ID, which can be sent as a one-element array or a string
    return [self getRichPushMessageIDFromValue:[notification objectForKey:kUARichPushMessageIDKey]];
}

+ (NSString *)getRichPushMessageIDFromValue:(id)richPushValue {
    id richPushID = richPushValue;
    if ([richPushID isKindOfClass:[NSArray class]]) {
        richPushID = [(NSArray *)richPushID firstObject];
    }

    return [richPushID isKindOfClass:[NSString class]] ? richPushID : nil;
}

@end
