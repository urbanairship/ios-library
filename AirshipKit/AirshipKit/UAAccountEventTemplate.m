/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "UAAccountEventTemplate.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UACustomEvent+Internal.h"

#define kUAAccountEventTemplate @"account"
#define kUARegisteredAccountEvent @"registered_account"
#define kUAAccountEventTemplateLifetimeValue @"ltv"
#define kUAAccountEventTemplateCategory @"category"

@interface UAAccountEventTemplate()
@property (nonatomic, copy) NSString *eventName;
@end

@implementation UAAccountEventTemplate

- (instancetype)initWithValue:(NSDecimalNumber *)eventValue {
    self = [super init];
    if (self) {
        self.eventName = kUARegisteredAccountEvent;
        self.eventValue = eventValue;
    }

    return self;
}

+ (instancetype)registeredTemplate {
    return [self registeredTemplateWithValue:nil];
}

+ (instancetype)registeredTemplateWithValueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self registeredTemplateWithValue:decimalValue];
}

+ (instancetype)registeredTemplateWithValue:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithValue:eventValue];
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

- (UACustomEvent *)createEvent {
    UACustomEvent *event = [UACustomEvent eventWithName:self.eventName];

    if (self.eventValue) {
        [event setEventValue:self.eventValue];
        [event setBoolProperty:YES forKey:kUAAccountEventTemplateLifetimeValue];
    } else {
        [event setBoolProperty:NO forKey:kUAAccountEventTemplateLifetimeValue];
    }

    if (self.transactionID) {
        [event setTransactionID:self.transactionID];
    }

    if (self.category) {
        [event setStringProperty:self.category forKey:kUAAccountEventTemplateCategory];
    }

    event.templateType = kUAAccountEventTemplate;

    return event;
}

@end
