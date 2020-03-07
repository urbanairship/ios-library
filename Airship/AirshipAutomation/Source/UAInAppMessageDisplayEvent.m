/* Copyright Airship and Contributors */

#import "UAEvent+Internal.h"
#import "UAInAppMessageDisplayEvent+Internal.h"
#import "UAInAppMessageEventUtils+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NSString *const UAInAppMessageDisplayEventType = @"in_app_display";
NSString *const UAInAppMessageDisplayEventLocaleKey = @"locale";


@interface UAInAppMessageDisplayEvent()
@property (nonatomic, strong) NSMutableDictionary *eventData;
@end


@implementation UAInAppMessageDisplayEvent

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];
    if (self) {
        self.eventData = [UAInAppMessageEventUtils createDataForMessage:message];
        [self.eventData setValue:message.renderedLocale forKey:UAInAppMessageDisplayEventLocaleKey];

        return self;
    }
    return nil;
}

+ (instancetype)eventWithMessage:(UAInAppMessage *)message {
    return [[self alloc] initWithMessage:message];
}

- (NSString *)eventType {
    return UAInAppMessageDisplayEventType;
}

- (NSDictionary *)data {
    return self.eventData;
}

@end
