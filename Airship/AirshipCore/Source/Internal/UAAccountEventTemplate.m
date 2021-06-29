/* Copyright Airship and Contributors */

#import "UAAccountEventTemplate.h"
#import "UAirship.h"
#import "UAAnalytics.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

#define kUAAccountEventTemplate @"account"
#define kUARegisteredAccountEvent @"registered_account"
#define kUALoggedInAccountEvent @"logged_in"
#define kUALoggedOutAccountEvent @"logged_out"
#define kUAAccountEventTemplateLifetimeValue @"ltv"
#define kUAAccountEventTemplateCategory @"category"
#define kUAAccountEventTemplateUserID @"user_id"
#define kUAAccountEventTemplateType @"type"

@interface UAAccountEventTemplate()
@property (nonatomic, copy) NSString *eventName;
@end

@implementation UAAccountEventTemplate

- (instancetype)initWithValue:(NSDecimalNumber *)eventValue eventName:(NSString *)eventName {
    self = [super init];
    if (self) {
        self.eventName = eventName;
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
    return [[self alloc] initWithValue:eventValue eventName:kUARegisteredAccountEvent];
}

+ (instancetype)loggedInTemplate {
    return [self loggedInTemplateWithValue:nil];
}

+ (instancetype)loggedInTemplateWithValueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self loggedInTemplateWithValue:decimalValue];
}

+ (instancetype)loggedInTemplateWithValue:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithValue:eventValue eventName:kUALoggedInAccountEvent];
}

+ (instancetype)loggedOutTemplate {
    return [self loggedOutTemplateWithValue:nil];
}

+ (instancetype)loggedOutTemplateWithValueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self loggedOutTemplateWithValue:decimalValue];
}

+ (instancetype)loggedOutTemplateWithValue:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithValue:eventValue eventName:kUALoggedOutAccountEvent];
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

    NSMutableDictionary *propertyDictionary = [NSMutableDictionary dictionary];
    
    if (self.eventValue) {
        [event setEventValue:self.eventValue];
        [propertyDictionary setValue:@YES forKey:kUAAccountEventTemplateLifetimeValue];
    } else {
        [propertyDictionary setValue:@NO forKey:kUAAccountEventTemplateLifetimeValue];
    }

    if (self.transactionID) {
        [event setTransactionID:self.transactionID];
    }

    if (self.category) {
        [propertyDictionary setValue:self.category forKey:kUAAccountEventTemplateCategory];
    }
    
    if (self.userID) {
        [propertyDictionary setValue:self.userID forKey:kUAAccountEventTemplateUserID];
    }
    
    if (self.type) {
        [propertyDictionary setValue:self.type forKey:kUAAccountEventTemplateType];
    }

    event.templateType = kUAAccountEventTemplate;
    
    event.properties = propertyDictionary;

    return event;
}

@end
