/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageDisplayEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAInAppMessageEventUtils+Internal.h"

NSString *const UAInAppMessageDisplayEventType = @"in_app_display";

@implementation UAInAppMessageDisplayEvent

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];
    if (self) {
        self.data = [UAInAppMessageEventUtils createDataForMessage:message];
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

@end
