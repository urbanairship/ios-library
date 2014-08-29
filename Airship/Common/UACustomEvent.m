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

#import "UACustomEvent+Internal.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAInboxMessage.h"

@implementation UACustomEvent

- (NSString *)eventType {
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
    return [self eventWithName:eventName value:nil];
}

+ (instancetype)eventWithName:(NSString *)eventName valueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self eventWithName:eventName value:decimalValue];
}

+ (instancetype)eventWithName:(NSString *)eventName value:(NSDecimalNumber *)eventValue {
    UACustomEvent *event = [[self alloc] initWithName:eventName withValue:eventValue];
    return event;
}

- (NSUInteger)estimatedSize {
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

- (void)setInteractionID:(NSString *)interactionID {
    if (interactionID.length > kUACustomEventCharacterLimit) {
        UA_LERR(@"Event interaction ID is larger than %d characters.", kUACustomEventCharacterLimit);
    } else {
        _interactionID = [interactionID copy];
    }
}

- (void)setInteractionType:(NSString *)interactionType {
    if (interactionType.length > kUACustomEventCharacterLimit) {
        UA_LERR(@"Event interaction type is larger than %d characters.", kUACustomEventCharacterLimit);
    } else {
        _interactionType = [interactionType copy];
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
    if ([eventValue isEqualToNumber:[NSDecimalNumber notANumber]]) {
        return;
    }

    if (!eventValue) {
        _eventValue = nil;
    } else if ([eventValue compare:@(INT32_MAX)] > 0) {
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
    NSString *sendId = self.conversionSendId ?:[UAirship shared].analytics.conversionSendId;
    [dictionary setValue:sendId forKey:@"conversion_send_id"];

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

    return [dictionary mutableCopy];
}

@end
