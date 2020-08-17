/* Copyright Airship and Contributors */

#import "UAScheduleTriggerContext+Internal.h"
#import "UAScheduleTrigger+Internal.h"

static NSString *const UAScheduleTriggerContextTriggerKey = @"trigger";
static NSString *const UAScheduleTriggerContextEventKey = @"event";

@interface UAScheduleTriggerContext()
@property(nonatomic, strong) UAScheduleTrigger *trigger;
@property(nonatomic, strong) id event;
@end

@implementation UAScheduleTriggerContext

- (instancetype)initWithTrigger:(UAScheduleTrigger *)trigger
                          event:(id)event {
    self = [super init];
    if (self) {
        self.trigger = trigger;
        self.event = event;
    }

    return self;
}

+ (instancetype)triggerContextWithTrigger:(UAScheduleTrigger *)trigger event:(id)event {
    return [[UAScheduleTriggerContext alloc] initWithTrigger:trigger event:event];
}

- (BOOL)isEqualToTriggerContext:(UAScheduleTriggerContext *)triggerContext {
    if (!triggerContext) {
        return NO;
    }

    if (![self.trigger isEqualToTrigger:triggerContext.trigger]) {
        return NO;
    }

    if (![self.event isEqual:triggerContext.event]) {
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

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.event forKey:UAScheduleTriggerContextEventKey];
    [coder encodeObject:self.trigger forKey:UAScheduleTriggerContextTriggerKey];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];

    if (self) {
        self.event = [coder decodeObjectForKey:UAScheduleTriggerContextEventKey];
        self.trigger = [coder decodeObjectForKey:UAScheduleTriggerContextTriggerKey];
    }

    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
