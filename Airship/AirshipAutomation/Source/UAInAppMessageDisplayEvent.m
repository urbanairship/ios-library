/* Copyright Airship and Contributors */

#import "UAEvent.h"
#import "UAInAppMessageDisplayEvent+Internal.h"
#import "UAInAppMessageEventUtils+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NSString *const UAInAppMessageDisplayEventType = @"in_app_display";
NSString *const UAInAppMessageDisplayEventLocaleKey = @"locale";


@implementation UAInAppMessageDisplayEvent

- (instancetype)initWithMessageID:(NSString *)messageID message:(UAInAppMessage *)message {
    self = [super init];
    if (self) {
        NSMutableDictionary *mutableEventData = [UAInAppMessageEventUtils createDataWithMessageID:messageID
                                                                                          message:message];
        [mutableEventData setValue:message.renderedLocale forKey:UAInAppMessageDisplayEventLocaleKey];
        self.eventData = mutableEventData;
        return self;
    }
    return nil;
}

+ (instancetype)eventWithMessageID:(NSString *)messageID message:(UAInAppMessage *)message {
    return [[self alloc] initWithMessageID:messageID message:message];
}

- (NSString *)eventType {
    return UAInAppMessageDisplayEventType;
}

- (NSDictionary *)data {
    return self.eventData;
}

@end
