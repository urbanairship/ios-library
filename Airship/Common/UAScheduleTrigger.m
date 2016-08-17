/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAScheduleTrigger+Internal.h"

@implementation UAScheduleTrigger

- (instancetype)initWithType:(UAScheduleTriggerType)type goal:(NSNumber *)goal predicateFormat:(NSString *)predicateFormat {
    self = [super self];
    if (self) {
        self.goal = goal;
        self.predicateFormat = predicateFormat;
        self.type = type;
    }

    return self;
}

+ (instancetype)triggerWithType:(UAScheduleTriggerType)type goal:(NSNumber *)goal predicateFormat:(NSString *)predicateFormat {
    return [[UAScheduleTrigger alloc] initWithType:type goal:goal predicateFormat:predicateFormat];
}

+ (instancetype)foregroundTriggerWithCount:(NSUInteger)count {
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerAppForeground goal:@(count) predicateFormat:nil];
}

+ (instancetype)backgroundTriggerWithCount:(NSUInteger)count {
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerAppBackground goal:@(count) predicateFormat:nil];
}

+ (instancetype)regionEnterTriggerForRegionID:(NSString *)regionID count:(NSUInteger)count {
    NSString *predicateString = [NSString stringWithFormat:@"regionID == \"%@\"", regionID];
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerRegionEnter
                                         goal:@(count)
                              predicateFormat:predicateString];
}

+ (instancetype)regionExitTriggerForRegionID:(NSString *)regionID count:(NSUInteger)count {
    NSString *predicateString = [NSString stringWithFormat:@"regionID == \"%@\"", regionID];
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerRegionExit
                                         goal:@(count)
                              predicateFormat:predicateString];
}

+ (instancetype)screenTriggerForScreenName:(NSString *)screenName count:(NSUInteger)count {
    NSString *predicateString = [NSString stringWithFormat:@"SELF == \"%@\"", screenName];
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerScreen
                                         goal:@(count)
                              predicateFormat:predicateString];
}

+ (instancetype)customEventTriggerWithPredicateFormat:(NSString *)predicateFormat count:(NSUInteger)count {
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerCustomEventCount
                                         goal:@(count)
                              predicateFormat:predicateFormat];
}

+ (instancetype)customEventTriggerWithPredicateFormat:(NSString *)predicateFormat value:(NSNumber *)value {
    return [UAScheduleTrigger triggerWithType:UAScheduleTriggerCustomEventValue
                                         goal:value
                              predicateFormat:predicateFormat];
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

    if (self.predicateFormat != trigger.predicateFormat && ![self.predicateFormat isEqualToString:trigger.predicateFormat]) {
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
    result = 31 * result + [self.predicateFormat hash];
    return result;
}

@end
