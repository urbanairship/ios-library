/* Copyright Airship and Contributors */

#import "UASearchEventTemplate.h"
#import "UACustomEvent+Internal.h"

#define kUASearchEventTemplate @"search"
#define kUASearchEventTemplateCategory @"category"
#define kUASearchEventTemplateQuery @"query"
#define kUASearchEventTemplateTotalResults @"total_results"
#define kUASearchEventTemplateIdentifier @"id"
#define kUASearchEventTemplateType @"type"
#define kUASearchEventTemplateLifetimeValue @"ltv"

@interface UASearchEventTemplate()
@property (nonatomic, copy) NSString *eventName;
@end

@implementation UASearchEventTemplate

- (instancetype)initWithValue:(NSDecimalNumber *)eventValue {
    self = [super init];
    if (self) {
        self.eventName = kUASearchEventTemplate;
        self.eventValue = eventValue;
    }

    return self;
}

+ (instancetype)template {
    return [self templateWithValue:nil];
}

+ (instancetype)templateWithValue:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithValue:eventValue];
}

- (UACustomEvent *)createEvent {
    UACustomEvent *event = [UACustomEvent eventWithName:self.eventName];

    NSMutableDictionary *propertyDictionary = [NSMutableDictionary dictionary];

    if (self.eventValue) {
        [event setEventValue:self.eventValue];
        [propertyDictionary setValue:@YES forKey:kUASearchEventTemplateLifetimeValue];
    } else {
        [propertyDictionary setValue:@NO forKey:kUASearchEventTemplateLifetimeValue];
    }
    
    if (self.identifier) {
        [propertyDictionary setValue:self.identifier forKey:kUASearchEventTemplateIdentifier];
    }

    if (self.category) {
        [propertyDictionary setValue:self.category forKey:kUASearchEventTemplateCategory];
    }

    if (self.query) {
        [propertyDictionary setValue:self.query forKey:kUASearchEventTemplateQuery];
    }
    
    if (self.type) {
        [propertyDictionary setValue:self.type forKey:kUASearchEventTemplateType];
    }

    if (self.totalResults) {
        [propertyDictionary setValue:@(self.totalResults) forKey:kUASearchEventTemplateTotalResults];
    }
    
    event.templateType = kUASearchEventTemplate;
    
    event.properties = propertyDictionary;

    return event;
}

@end
