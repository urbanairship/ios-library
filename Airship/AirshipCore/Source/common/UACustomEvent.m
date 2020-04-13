/* Copyright Airship and Contributors */

#import "UACustomEvent+Internal.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "NSJSONSerialization+UAAdditions.h"

@implementation UACustomEvent

NSString * const UAInteractionMCRAP = @"ua_mcrap";
const NSUInteger UACustomEventCharacterLimit = 255;
const NSUInteger UACustomEventMaxPropertiesCount = 100;
const NSUInteger UACustomEventMaxPropertyCollectionSize = 20;
const NSUInteger UACustomEventMaxPropertiesSize = 65536;

// Public data keys
NSString *const UACustomEventNameKey = @"event_name";
NSString *const UACustomEventValueKey = @"event_value";
NSString *const UACustomEventPropertiesKey = @"properties";
NSString *const UACustomEventTransactionIDKey = @"transaction_id";
NSString *const UACustomEventInteractionIDKey = @"interaction_id";
NSString *const UACustomEventInteractionTypeKey = @"interaction_type";

// Private data keys
NSString *const UACustomEventConversionMetadataKey = @"conversion_metadata";
NSString *const UACustomEventConversionSendIDKey = @"conversion_send_id";
NSString *const UACustomEventTemplateTypeKey = @"template_type";

- (NSString *)eventType {
    return @"enhanced_custom_event";
}

- (instancetype)initWithName:(NSString *)eventName withValue:(NSDecimalNumber *)eventValue {
    self = [super init];
    if (self) {
        self.eventName = eventName;
        self.eventValue = eventValue;
        self.properties = [NSDictionary dictionary];
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
    NSMutableDictionary *mutableProperties = self.properties.mutableCopy;
    [mutableProperties setValue:@(value) forKey:key];
    self.properties = mutableProperties.copy;
}

- (void)setStringProperty:(NSString *)value forKey:(NSString *)key {
    NSMutableDictionary *mutableProperties = self.properties.mutableCopy;
    [mutableProperties setValue:[value copy] forKey:key];
    self.properties = mutableProperties.copy;
}

- (void)setNumberProperty:(NSNumber *)value forKey:(NSString *)key {
    NSMutableDictionary *mutableProperties = self.properties.mutableCopy;
    [mutableProperties setValue:[value copy] forKey:key];
    self.properties = mutableProperties.copy;
}

- (void)setStringArrayProperty:(NSArray *)value forKey:(NSString *)key {
    NSMutableDictionary *mutableProperties = self.properties.mutableCopy;
    [mutableProperties setValue:[value copy] forKey:key];
    self.properties = mutableProperties.copy;
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

    if (self.templateType.length > UACustomEventCharacterLimit) {
        UA_LERR(@"Event template type is larger than %lu characters.", (unsigned long)UACustomEventCharacterLimit);
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
    
    NSError *error;
    NSData *propertyData = [NSJSONSerialization dataWithJSONObject:self.properties options:0 error:&error];
  
    if (error) {
        UA_LERR(@"Event properties serialization error %@", error);
        isValid = NO;
    } else if (propertyData.length > UACustomEventMaxPropertiesSize) {
        UA_LERR(@"Event properties (%lu bytes) are larger than the maximum size of %lu bytes.", (unsigned long) propertyData.length, (unsigned long)UACustomEventMaxPropertiesSize);
        isValid = NO;
    }

    return isValid;
}

- (void)setInteractionFromMessageCenterMessage:(NSString *)messageID {
    self.interactionID = messageID;
    self.interactionType = UAInteractionMCRAP;
}

- (NSDictionary *)data {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    // Event name
    [dictionary setValue:self.eventName forKey:UACustomEventNameKey];

    // Conversion Send ID
    NSString *sendID = self.conversionSendID ?:[UAirship analytics].conversionSendID;
    [dictionary setValue:sendID forKey:UACustomEventConversionSendIDKey];

    // Conversion Send Metadata
    NSString *sendMetadata = self.conversionPushMetadata ?:[UAirship analytics].conversionPushMetadata;
    [dictionary setValue:sendMetadata forKey:UACustomEventConversionMetadataKey];

    // Interaction
    [dictionary setValue:self.interactionID forKey:UACustomEventInteractionIDKey];
    [dictionary setValue:self.interactionType forKey:UACustomEventInteractionTypeKey];

    // Transaction ID
    [dictionary setValue:self.transactionID forKey:UACustomEventTransactionIDKey];

    // Template type
    [dictionary setValue:self.templateType forKey:UACustomEventTemplateTypeKey];

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
        [dictionary setValue:@([number longLongValue]) forKey:UACustomEventValueKey];
    }

    // Properties
    
    [dictionary setValue:self.properties forKey:UACustomEventPropertiesKey];

    return dictionary.copy;
}

- (NSDictionary *)payload {
    /*
     * We are unable to use the event.data for automation because we modify some
     * values to be stringified versions before we store the event to be sent to
     * warp9. Instead we are going to recreate the event data with the unmodified
     * values.
     */
    NSDictionary *eventData = [NSMutableDictionary dictionary];
    [eventData setValue:self.eventName forKey:UACustomEventNameKey];
    [eventData setValue:self.interactionID forKey:UACustomEventInteractionIDKey];
    [eventData setValue:self.interactionType forKey:UACustomEventInteractionTypeKey];
    [eventData setValue:self.transactionID forKey:UACustomEventTransactionIDKey];
    [eventData setValue:self.eventValue forKey:UACustomEventValueKey];
    [eventData setValue:self.properties forKey:UACustomEventPropertiesKey];

    return eventData;
}

- (void)track {
    [[UAirship analytics] addEvent:self];
}

@end
