/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import "UACustomEvent+Internal.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAInboxMessage.h"
#import "NSJSONSerialization+UAAdditions.h"

@interface UACustomEvent()
@property(nonatomic, strong) NSMutableDictionary *properties;
@end

@implementation UACustomEvent

const NSUInteger UACustomEventCharacterLimit = 255;
const NSUInteger UACustomEventMaxPropertiesCount = 20;

- (NSString *)eventType {
    return @"custom_event";
}

- (instancetype)initWithName:(NSString *)eventName withValue:(NSDecimalNumber *)eventValue {
    self = [super init];
    if (self) {
        self.eventName = eventName;
        self.eventValue = eventValue;
        self.properties = [NSMutableDictionary dictionary];
    }

    return self;
}

+ (instancetype)eventWithName:(NSString *)eventName {
    return [self eventWithName:eventName value:nil];
}

+ (instancetype)eventWithName:(NSString *)eventName valueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self eventWithName:eventName value:decimalValue];
}

+ (instancetype)eventWithName:(NSString *)eventName value:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithName:eventName withValue:eventValue];
}

- (void)setBoolProperty:(BOOL)value forKey:(NSString *)key {
    [self.properties setValue:@(value) forKey:key];
}

- (void)setStringProperty:(NSString *)value forKey:(NSString *)key {
    [self.properties setValue:[value copy] forKey:key];
}

- (void)setNumberProperty:(NSNumber *)value forKey:(NSString *)key {
    [self.properties setValue:[value copy] forKey:key];
}

- (void)setStringArrayProperty:(NSArray *)value forKey:(NSString *)key {
    [self.properties setValue:[value copy] forKey:key];
}

- (void)setEventValue:(NSDecimalNumber *)eventValue {
    if (!eventValue) {
        _eventValue = nil;
    } else {
        if ([eventValue isKindOfClass:[NSDecimalNumber class]]) {
            _eventValue = eventValue;
        } else {
            _eventValue = [NSDecimalNumber decimalNumberWithDecimal:[eventValue decimalValue]];
        }
    }
}


- (BOOL)isValid {
    BOOL isValid = YES;

    if (!self.eventName.length || self.eventName.length > UACustomEventCharacterLimit) {
        UA_LERR(@"Event name must be between 1 and %lu characters.", (unsigned long)UACustomEventCharacterLimit);
        isValid = NO;
    }

    if (self.interactionType.length > UACustomEventCharacterLimit) {
        UA_LERR(@"Event interaction type is larger than %lu characters.", (unsigned long)UACustomEventCharacterLimit);
        isValid = NO;
    }

    if (self.interactionID.length > UACustomEventCharacterLimit) {
        UA_LERR(@"Event interaction ID is larger than %lu characters.", (unsigned long)UACustomEventCharacterLimit);
        isValid = NO;
    }

    if (self.transactionID.length > UACustomEventCharacterLimit) {
        UA_LERR(@"Event transaction ID is larger than %lu characters.", (unsigned long)UACustomEventCharacterLimit);
        isValid = NO;
    }

    if (self.eventValue) {
        if ([self.eventValue isEqualToNumber:[NSDecimalNumber notANumber]]) {\
            UA_LERR(@"Event value is not a number.");
            isValid = NO;
        } else if ([self.eventValue compare:@(INT32_MAX)] > 0) {
            UA_LERR(@"Event value %@ is larger than 2^31-1.", self.eventValue);
            isValid = NO;
        } else if ([self.eventValue compare:@(INT32_MIN)] < 0) {
            UA_LERR(@"Event value %@ is smaller than -2^31.", self.eventValue);
            isValid = NO;
        }
    }

    if (self.properties.count > UACustomEventMaxPropertiesCount) {
        UA_LERR(@"Event contains more than %lu properties.", (unsigned long)UACustomEventMaxPropertiesCount);
        isValid = NO;
    }

    for (id key in self.properties) {
        id value = [self.properties valueForKey:key];
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray *array = (NSArray *)value;
            if (array.count > UACustomEventMaxPropertiesCount) {
                UA_LERR(@"Array property %@ exceeds more than %lu entries.", key, (unsigned long)UACustomEventMaxPropertiesCount);
                isValid = NO;
            }

            // Arrays can only contains Strings
            for (id arrayProperty in array) {
                if (![arrayProperty isKindOfClass:[NSString class]]) {
                    isValid = NO;
                    UA_LERR(@"Array property %@ contains an invalid object: %@", key, arrayProperty);
                    continue;
                }

                if (((NSString *)arrayProperty).length > UACustomEventCharacterLimit) {
                    UA_LERR(@"Array property %@ contains a String that is larger than %lu characters.", key, (unsigned long)UACustomEventCharacterLimit);
                    isValid = NO;
                }
            }
        } else if ([value isKindOfClass:[NSString class]]) {
            NSString *stringProperty = (NSString *)value;
            if (stringProperty.length > UACustomEventCharacterLimit) {
                UA_LERR(@"Property %@ is larger than %lu characters.", key, (unsigned long)UACustomEventCharacterLimit);
                isValid = NO;
            }
        } else if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber *numberProperty = (NSNumber *)value;
            if ([numberProperty isEqualToNumber:[NSDecimalNumber notANumber]]) {
                UA_LERR(@"Property %@ contains an invalid number.", key);
                isValid = NO;
            }
        } else {
            UA_LERR(@"Property %@ contains an invalid object: %@", key, value);
            isValid = NO;
        }
    }

    return isValid;
}


- (void)setInteractionFromMessage:(UAInboxMessage *)message {
    if (message) {
        self.interactionID = message.messageID;
        self.interactionType = kUAInteractionMCRAP;
    }
}

- (NSDictionary *)data {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    // Event name
    [dictionary setValue:self.eventName forKey:@"event_name"];

    // Conversion Send ID
    NSString *sendID = self.conversionSendID ?:[UAirship shared].analytics.conversionSendID;
    [dictionary setValue:sendID forKey:@"conversion_send_id"];

    // Interaction
    [dictionary setValue:self.interactionID forKey:@"interaction_id"];
    [dictionary setValue:self.interactionType forKey:@"interaction_type"];

    // Transaction ID
    [dictionary setValue:self.transactionID forKey:@"transaction_id"];

    // Event value
    if (self.eventValue) {

        // Move the decimal position over 6 positions
        NSDecimalNumber *number = [self.eventValue decimalNumberByMultiplyingByPowerOf10:6];

        /*
         We use long long value here because on a 32 bit machine int and long
         have the same range. We clamp eventValue to [-2^31, 2^31-1] so we know
         for sure that the value multiplied by 10^6 (~2^20) will have an approximate
         range of [-2^51, 2^51-1] so it will always fit into the range warp9
         is expecting [-2^63, 2^63-1].
         */
        [dictionary setValue:@([number longLongValue]) forKey:@"event_value"];
    }

    NSMutableDictionary *stringifiedProperties = [NSMutableDictionary dictionary];

    for (id key in self.properties) {
        id value = [self.properties valueForKey:key];

        if ([value isKindOfClass:[NSArray class]]) {
            [stringifiedProperties setValue:value forKey:key];
        } else {
            NSString *stringifiedValue = [NSJSONSerialization stringWithObject:value acceptingFragments:YES error:nil];
            [stringifiedProperties setValue:stringifiedValue forKey:key];
        }
    }

    if (stringifiedProperties.count) {
        [dictionary setValue:stringifiedProperties forKey:@"properties"];
    }
    
    return [dictionary mutableCopy];
}

@end
