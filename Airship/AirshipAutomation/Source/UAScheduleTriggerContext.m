/* Copyright Airship and Contributors */

#import "UAScheduleTriggerContext+Internal.h"
#import "UAScheduleTrigger+Internal.h"
#import "UACustomEvent.h"

// JSON Keys
NSString *const UAScheduleTriggerContextTriggerKey = @"trigger";
NSString *const UAScheduleTriggerContextEventKey = @"event";

NSString * const UAScheduleTriggerContextErrorDomain = @"com.urbanairship.schedule_trigger_context";

@implementation UAScheduleTriggerContext

- (instancetype)initWithTrigger:(UAScheduleTrigger *)trigger event:(NSDictionary *)event {
    self = [super init];
    if (self) {
        self.trigger = trigger;
        self.event = event;
    }

    return self;
}

+ (instancetype)triggerContextWithTrigger:(UAScheduleTrigger *)trigger event:(NSDictionary *)event {
    return [[UAScheduleTriggerContext alloc] initWithTrigger:trigger event:event];
}

- (BOOL)isEqualToTriggerContext:(UAScheduleTriggerContext *)triggerContext {
    if (!triggerContext) {
        return NO;
    }

    if (![self.trigger isEqualToTrigger:triggerContext.trigger]) {
        return NO;
    }

    if (![self.event isEqualToDictionary:triggerContext.event]) {
        return NO;
    }

    return YES;
}
 
#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAScheduleTriggerContext class]]) {
        return NO;
    }

    return [self isEqualToTriggerContext:(UAScheduleTriggerContext *)object];
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.trigger hash];
    result = 31 * result + [self.event hash];
    return result;
}

@end
