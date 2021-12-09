/* Copyright Airship and Contributors */

#import "UAInAppMessageDisplayEvent+Internal.h"
#import "UAInAppMessageEventUtils+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NSString *const UAInAppMessageDisplayEventType = @"in_app_display";
NSString *const UAInAppMessageDisplayEventLocaleKey = @"locale";

@interface UAInAppMessageDisplayEvent()
@property(nonatomic, copy) NSDictionary *eventData;
@end

@implementation UAInAppMessageDisplayEvent

- (instancetype)initWithMessageID:(NSString *)messageID message:(UAInAppMessage *)message campaigns:(NSDictionary *)campaigns reportingContext:(NSDictionary *)reportingContext {
    self = [super init];
    if (self) {
        NSMutableDictionary *mutableEventData = [UAInAppMessageEventUtils createDataWithMessageID:messageID
                                                                                          source:message.source
                                                                                        campaigns:campaigns context:reportingContext];
        [mutableEventData setValue:message.renderedLocale forKey:UAInAppMessageDisplayEventLocaleKey];
        self.eventData = mutableEventData;
        return self;
    }
    return nil;
}

+ (instancetype)eventWithMessageID:(NSString *)messageID
                           message:(UAInAppMessage *)message
                         campaigns:(NSDictionary *)campaigns
                  reportingContext:(NSDictionary *)reportingContext {
    return [[self alloc] initWithMessageID:messageID message:message campaigns:campaigns reportingContext:reportingContext];
}

- (NSString *)eventType {
    return UAInAppMessageDisplayEventType;
}

- (NSDictionary *)data {
    return self.eventData;
}

- (UAEventPriority)priority {
    return UAEventPriorityNormal;
}

@end
