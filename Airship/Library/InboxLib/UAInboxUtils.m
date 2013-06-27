
#import "UAInboxUtils.h"

#define kUARichPushMessageIDKey @"_uamid"

@implementation UAInboxUtils

+ (void)getRichPushMessageIDFromNotification:(NSDictionary *)notification withAction:(UAInboxMessageIDBlock)actionBlock {

    // Get the rich push ID, which can be sent as a one-element array or a string
    NSString *richPushId = nil;
    NSObject *richPushValue = [notification objectForKey:kUARichPushMessageIDKey];
    if ([richPushValue isKindOfClass:[NSArray class]]) {
        NSArray *richPushIds = (NSArray *)richPushValue;
        if (richPushIds.count > 0) {
            richPushId = [richPushIds objectAtIndex:0];
        }
    } else if ([richPushValue isKindOfClass:[NSString class]]) {
        richPushId = (NSString *)richPushValue;
    }

    if (richPushId) {
        actionBlock(richPushId);
    }
}

@end
