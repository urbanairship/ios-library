/* Copyright Airship and Contributors */

#import "UAScheduleTrigger+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
// JSON/NSSecureCoding Keys
NSString *const UAScheduleTriggerTypeKey = @"type";
NSString *const UAScheduleTriggerPredicateKey = @"predicate";
NSString *const UAScheduleTriggerGoalKey = @"goal";

// Trigger Names
NSString *const UAScheduleTriggerAppInitName = @"app_init";
NSString *const UAScheduleTriggerAppForegroundName = @"foreground";
NSString *const UAScheduleTriggerAppBackgroundName = @"background";
NSString *const UAScheduleTriggerRegionEnterName = @"region_enter";
NSString *const UAScheduleTriggerRegionExitName = @"region_exit";
NSString *const UAScheduleTriggerCustomEventCountName = @"custom_event_count";
NSString *const UAScheduleTriggerCustomEventValueName = @"custom_event_value";
NSString *const UAScheduleTriggerScreenName = @"screen";
NSString *const UAScheduleTriggerActiveSessionName = @"active_session";
NSString *const UAScheduleTriggerVersionName = @"version";

NSString * const UAScheduleTriggerErrorDomain = @"com.urbanairship.schedule_trigger";

@implementation UAScheduleTrigger

- (instancetype)initWithType:(UAScheduleTriggerType)type goal:(NSNumber *)goal predicate:(UAJSONPredicate *)predicate {
    self = [super init];
    if (self) {
        self.goal = goal;
        self.predicate = predicate;
        self.type = type;
    }

    return self;
}

+ (instancetype)triggerWithType:(UAScheduleTriggerType)type goal:(NSNumber *)goal predicate:(UAJSONPredicate *)predicate {
    return [[UAScheduleTrigger alloc] initWithType:type goal:goal predicate:predicate];
}

+ (instancetype)appInitTriggerWithCount:(NSUInteger)count {
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerAppInit goal:@(count) predicate:nil];
}

+ (instancetype)foregroundTriggerWithCount:(NSUInteger)count {
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerAppForeground goal:@(count) predicate:nil];
}

+ (instancetype)backgroundTriggerWithCount:(NSUInteger)count {
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerAppBackground goal:@(count) predicate:nil];
}

+ (instancetype)activeSessionTriggerWithCount:(NSUInteger)count {
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerActiveSession goal:@(count) predicate:nil];
}

+ (instancetype)regionEnterTriggerForRegionID:(NSString *)regionID count:(NSUInteger)count {
    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:regionID];
    UAJSONMatcher *jsonMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher scope:@[UARegionEvent.regionIDKey]];
    UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSONMatcher:jsonMatcher];

    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerRegionEnter
                                         goal:@(count)
                                    predicate:predicate];
}

+ (instancetype)regionExitTriggerForRegionID:(NSString *)regionID count:(NSUInteger)count {
    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:regionID];
    UAJSONMatcher *jsonMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher scope:@[UARegionEvent.regionIDKey]];
    UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSONMatcher:jsonMatcher];

    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerRegionExit
                                         goal:@(count)
                                    predicate:predicate];
}

+ (instancetype)screenTriggerForScreenName:(NSString *)screenName count:(NSUInteger)count {
    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:screenName];
    UAJSONMatcher *jsonMatcher = [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher];
    UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSONMatcher:jsonMatcher];

    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerScreen
                                         goal:@(count)
                                    predicate:predicate];
}

+ (instancetype)customEventTriggerWithPredicate:(UAJSONPredicate *)predicate count:(NSUInteger)count {
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerCustomEventCount
                                         goal:@(count)
                                    predicate:predicate];
}

+ (instancetype)customEventTriggerWithPredicate:(UAJSONPredicate *)predicate value:(NSNumber *)value {
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerCustomEventValue
                                         goal:value
                                    predicate:predicate];
}

+ (instancetype)versionTriggerWithConstraint:(NSString *)versionConstraint count:(NSUInteger)count {
    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWithVersionConstraint:versionConstraint];
    UAJSONMatcher *matcher = [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher scope:@[@"ios", @"version"]];
    UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSONMatcher:matcher];
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerVersion goal:@(count) predicate:predicate];
}

+ (nullable instancetype)triggerWithJSON:(id)json error:(NSError **)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAScheduleTriggerErrorDomain
                                          code:UAScheduleTriggerErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    UAScheduleTriggerType triggerType;

    id triggerTypeContents = json[UAScheduleTriggerTypeKey];
    if (![triggerTypeContents isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Trigger type must be a string."];
            *error =  [NSError errorWithDomain:UAScheduleTriggerErrorDomain
                                          code:UAScheduleTriggerErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return nil;
    }

    NSString *triggerTypeString = [triggerTypeContents lowercaseString];
    
    if ([UAScheduleTriggerAppForegroundName isEqualToString:triggerTypeString]) {
        triggerType = UAScheduleTriggerAppForeground;
    } else if ([UAScheduleTriggerAppBackgroundName isEqualToString:triggerTypeString]) {
        triggerType = UAScheduleTriggerAppBackground;
    } else if ([UAScheduleTriggerRegionEnterName isEqualToString:triggerTypeString]) {
        triggerType = UAScheduleTriggerRegionEnter;
    } else if ([UAScheduleTriggerRegionExitName isEqualToString:triggerTypeString]) {
        triggerType = UAScheduleTriggerRegionExit;
    } else if ([UAScheduleTriggerCustomEventCountName isEqualToString:triggerTypeString]) {
        triggerType = UAScheduleTriggerCustomEventCount;
    } else if ([UAScheduleTriggerCustomEventValueName isEqualToString:triggerTypeString]) {
        triggerType = UAScheduleTriggerCustomEventValue;
    } else if ([UAScheduleTriggerScreenName isEqualToString:triggerTypeString]) {
        triggerType = UAScheduleTriggerScreen;
    } else if ([UAScheduleTriggerAppInitName isEqualToString:triggerTypeString]) {
        triggerType = UAScheduleTriggerAppInit;
    } else if ([UAScheduleTriggerActiveSessionName isEqualToString:triggerTypeString]) {
        triggerType = UAScheduleTriggerActiveSession;
    } else if ([UAScheduleTriggerVersionName isEqualToString:triggerTypeString]) {
        triggerType = UAScheduleTriggerVersion;
    } else {

        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Invalid trigger type: %@", triggerTypeString];
            *error =  [NSError errorWithDomain:UAScheduleTriggerErrorDomain
                                          code:UAScheduleTriggerErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    NSNumber *goal;
    if ([json[UAScheduleTriggerGoalKey] isKindOfClass:[NSNumber class]]) {
        goal = json[UAScheduleTriggerGoalKey];
    }

    if (!goal || [goal doubleValue] <= 0) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Goal must be defined and greater than 0. Invalid value: %@", goal];
            *error =  [NSError errorWithDomain:UAScheduleTriggerErrorDomain
                                          code:UAScheduleTriggerErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    UAJSONPredicate *predicate;
    if (json[UAScheduleTriggerPredicateKey]) {
        predicate = [[UAJSONPredicate alloc] initWithJSON:json[UAScheduleTriggerPredicateKey] error:error];
        if (!predicate) {
            return nil;
        }
    }

    return [UAScheduleTrigger triggerWithType:triggerType goal:goal predicate:predicate];
}


- (BOOL)isEqualToTrigger:(UAScheduleTrigger *)trigger {
    if (!trigger) {
        return NO;
    }

    if (self.type != trigger.type) {
        return NO;
    }

    if (![self.goal isEqualToNumber:trigger.goal]) {
        return NO;
    }

    if (self.predicate != trigger.predicate && ![self.predicate.payload isEqualToDictionary:trigger.predicate.payload]) {
        return NO;
    }

    return YES;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAScheduleTrigger class]]) {
        return NO;
    }

    return [self isEqualToTrigger:(UAScheduleTrigger *)object];
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + self.type;
    result = 31 * result + [self.goal hash];
    result = 31 * result + [self.predicate hash];
    return result;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@(self.type) forKey:UAScheduleTriggerTypeKey];
    [coder encodeObject:self.goal forKey:UAScheduleTriggerGoalKey];
    if (self.predicate.payload) {
        [coder encodeObject:[UAJSONUtils stringWithObject:self.predicate.payload] forKey:UAScheduleTriggerPredicateKey];
    }
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];

    if (self) {
        self.type = [[coder decodeObjectOfClass:[NSNumber class] forKey:UAScheduleTriggerTypeKey] integerValue];
        self.goal = [coder decodeObjectOfClass:[NSNumber class] forKey:UAScheduleTriggerGoalKey];

        id predicateJSON = [coder decodeObjectOfClass:[NSString class] forKey:UAScheduleTriggerPredicateKey];
        if (predicateJSON) {
            self.predicate = [[UAJSONPredicate alloc] initWithJSON:[UAJSONUtils objectWithString:predicateJSON]
                                                          error:nil];
        }
    }

    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAScheduleTrigger{type=%@, goal=%@, predicate=%@}",
            self.typeName, self.goal, self.predicate];
}

- (NSString *)typeName {
    switch (self.type) {
        case UAScheduleTriggerAppForeground:
            return UAScheduleTriggerAppForegroundName;

        case UAScheduleTriggerAppBackground:
            return UAScheduleTriggerAppBackgroundName;

        case UAScheduleTriggerRegionEnter:
            return UAScheduleTriggerRegionEnterName;

        case UAScheduleTriggerRegionExit:
            return UAScheduleTriggerRegionExitName;

        case UAScheduleTriggerCustomEventCount:
            return UAScheduleTriggerCustomEventCountName;

        case UAScheduleTriggerCustomEventValue:
            return UAScheduleTriggerCustomEventValueName;

        case UAScheduleTriggerScreen:
            return UAScheduleTriggerScreenName;

        case UAScheduleTriggerAppInit:
            return UAScheduleTriggerAppInitName;

        case UAScheduleTriggerActiveSession:
            return UAScheduleTriggerActiveSessionName;

        case UAScheduleTriggerVersion:
            return UAScheduleTriggerVersionName;

        default:
            return @"";
    }
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
