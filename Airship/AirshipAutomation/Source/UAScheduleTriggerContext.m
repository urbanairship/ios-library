/* Copyright Airship and Contributors */

#import "UAScheduleTriggerContext+Internal.h"
#import "UAScheduleTrigger+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

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

    if (self.event != triggerContext.event && ![self.event isEqual:triggerContext.event]) {
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
    if (self.event) {
        NSString *eventJSON = [UAJSONUtils stringWithObject:self.event options: NSJSONWritingFragmentsAllowed error:nil];
        [coder encodeObject:eventJSON forKey:UAScheduleTriggerContextEventKey];
    }
    [coder encodeObject:self.trigger forKey:UAScheduleTriggerContextTriggerKey];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];

    if (self) {

        id eventJSON = [coder decodeObjectOfClass:[NSString class] forKey:UAScheduleTriggerContextEventKey];
        if (eventJSON) {
            self.event = [UAJSONUtils objectWithString:eventJSON
                                               options:NSJSONReadingMutableContainers | NSJSONReadingAllowFragments
                                                 error:nil];
        }

        self.trigger = [coder decodeObjectOfClass:[UAScheduleTrigger class]
                                           forKey:UAScheduleTriggerContextTriggerKey];
    }

    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
