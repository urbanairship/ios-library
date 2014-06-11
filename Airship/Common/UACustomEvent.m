/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import "UACustomEvent.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAInboxMessage.h"

@implementation UACustomEvent

#define kUACustomEventCharacterLimit 255
#define kUACustomEventSize 800

- (NSString *)getType {
    return @"custom_event";
}

- (instancetype)initWithName:(NSString *)eventName withValue:(NSDecimalNumber *)eventValue {
    self = [super init];
    if (self) {
        self.eventName = eventName;
        self.eventValue = eventValue;
    }

    return self;
}

+ (instancetype)eventWithName:(NSString *)eventName {
    return [[UACustomEvent alloc] initWithName:eventName withValue:nil];
}

+ (instancetype)eventWithName:(NSString *)eventName valueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = [NSDecimalNumber decimalNumberWithString:eventValue];
    return [[UACustomEvent alloc] initWithName:eventName withValue:decimalValue];
}

+ (instancetype)eventWithName:(NSString *)eventName value:(NSDecimalNumber *)eventValue {
    return [[UACustomEvent alloc] initWithName:eventName withValue:eventValue];
}

- (void)gatherIndividualData:(NSDictionary *)context {
    // Event name
    [self addDataWithValue:self.eventName forKey:@"event_name"];

    // Attribution
    if (!self.attributionType && !self.attributionID) {
        NSString *conversionID = [[UAirship shared].analytics.session objectForKey:@"launched_from_push_id"];
        if (conversionID) {
            [self addDataWithValue:kUAAttributionHardOpen forKey:@"attribution_type"];
            [self addDataWithValue:conversionID forKey:@"attribution_id"];
        }
    } else {
        [self addDataWithValue:self.attributionID forKey:@"attribution_id"];
        [self addDataWithValue:self.attributionType forKey:@"attribution_type"];
    }

    // Transaction ID
    [self addDataWithValue:self.transactionID forKey:@"transaction_id"];

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
        [self addDataWithValue:@([number longLongValue]) forKey:@"event_value"];
    }
}

- (NSUInteger)getEstimatedSize {
    return kUACustomEventSize;
}

- (BOOL)isValid {
    return self.eventName.length > 0;
}

- (void)setEventName:(NSString *)eventName {
    if (eventName.length > kUACustomEventCharacterLimit) {
        UA_LERR(@"Event name is larger than %d characters.", kUACustomEventCharacterLimit);
    } else {
        _eventName = [eventName copy];
    }
}

- (void)setAttributionID:(NSString *)attributionID {
    if (attributionID.length > kUACustomEventCharacterLimit) {
        UA_LERR(@"Event attribution ID is larger than %d characters.", kUACustomEventCharacterLimit);
    } else {
        _attributionID = [attributionID copy];
    }
}

- (void)setAttributionType:(NSString *)attributionType {
    if (attributionType.length > kUACustomEventCharacterLimit) {
        UA_LERR(@"Event attribution type is larger than %d characters.", kUACustomEventCharacterLimit);
    } else {
        _attributionType = [attributionType copy];
    }
}

- (void)setTransactionID:(NSString *)transactionID {
    if (transactionID.length > kUACustomEventCharacterLimit) {
        UA_LERR(@"Event transaction ID is larger than %d characters.", kUACustomEventCharacterLimit);
    } else {
        _transactionID = [transactionID copy];
    }
}

- (void)setEventValue:(NSDecimalNumber *)eventValue {
    if ([eventValue compare:@(INT32_MAX)] > 0) {
        UA_LERR(@"Event value %@ is larger than 2^31-1", self.eventValue);
    } else if ([eventValue compare:@(INT32_MIN)] < 0) {
        UA_LERR(@"Event value %@ is smaller than -2^31", self.eventValue);
    } else {
        if ([eventValue isKindOfClass:[NSDecimalNumber class]]) {
            _eventValue = eventValue;
        } else {
            _eventValue = [NSDecimalNumber decimalNumberWithDecimal:[eventValue decimalValue]];
        }
    }
}

- (void)setAttributionFromMessage:(UAInboxMessage *)message {
    if (message) {
        self.attributionID = message.messageID;
        self.attributionType = kUAAttributionMCRAP;
    }
}

@end
