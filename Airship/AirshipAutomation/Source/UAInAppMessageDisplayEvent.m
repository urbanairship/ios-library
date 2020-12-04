/* Copyright Airship and Contributors */

#import "UAInAppMessageDisplayEvent+Internal.h"
#import "UAInAppMessageEventUtils+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NSString *const UAInAppMessageDisplayEventType = @"in_app_display";
NSString *const UAInAppMessageDisplayEventLocaleKey = @"locale";


@implementation UAInAppMessageDisplayEvent

- (instancetype)initWithMessageID:(NSString *)messageID message:(UAInAppMessage *)message campaigns:(NSDictionary *)campaigns {
    self = [super init];
    if (self) {
        NSMutableDictionary *mutableEventData = [UAInAppMessageEventUtils createDataWithMessageID:messageID
                                                                                          source:message.source
                                                                                        campaigns:campaigns];
        [mutableEventData setValue:message.renderedLocale forKey:UAInAppMessageDisplayEventLocaleKey];
        self.eventData = mutableEventData;
        return self;
    }
    return nil;
}

+ (instancetype)eventWithMessageID:(NSString *)messageID message:(UAInAppMessage *)message campaigns:(NSDictionary *)campaigns {
    return [[self alloc] initWithMessageID:messageID message:message campaigns:campaigns];
}

- (NSString *)eventType {
    return UAInAppMessageDisplayEventType;
}

- (NSDictionary *)data {
    return self.eventData;
}

@end
