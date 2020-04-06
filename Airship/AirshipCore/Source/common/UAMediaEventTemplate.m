/* Copyright Airship and Contributors */

#import "UAMediaEventTemplate.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UACustomEvent+Internal.h"

#define kUAMediaEventTemplate @"media"
#define kUABrowsedContentEvent @"browsed_content"
#define kUAConsumedContentEvent @"consumed_content"
#define kUAStarredContentEvent @"starred_content"
#define kUASharedContentEvent @"shared_content"
#define kUAMediaEventTemplateLifetimeValue @"ltv"
#define kUAMediaEventTemplateIdentifier @"id"
#define kUAMediaEventTemplateCategory @"category"
#define kUAMediaEventTemplateDescription @"description"
#define kUAMediaEventTemplateType @"type"
#define kUAMediaEventTemplateFeature @"feature"
#define kUAMediaEventTemplateAuthor @"author"
#define kUAMediaEventTemplatePublishedDate @"published_date"
#define kUAMediaEventTemplateSource @"source"
#define kUAMediaEventTemplateMedium @"medium"

@interface UAMediaEventTemplate()
@property (nonatomic, copy) NSString *eventName;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSString *medium;
@property (nonatomic, strong) NSDecimalNumber *eventValue;
@property (nonatomic, assign) BOOL featureSet;
@end

@implementation UAMediaEventTemplate

- (instancetype)initWithName:(NSString *)name
                   withValue:(NSDecimalNumber *)eventValue
                  withSource:(NSString *)source
                  withMedium:(NSString *)medium {
    self = [super init];
    if (self) {
        self.eventName = name;
        self.eventValue = eventValue;
        self.source = source;
        self.medium = medium;
    }

    return self;
}

+ (instancetype)browsedTemplate {
    return [[self alloc] initWithName:kUABrowsedContentEvent
                            withValue:nil
                           withSource:nil
                           withMedium:nil];
}

+ (instancetype)starredTemplate {
    return [[self alloc] initWithName:kUAStarredContentEvent
                            withValue:nil
                           withSource:nil
                           withMedium:nil];
}

+ (instancetype)sharedTemplateWithSource:(NSString *)source
                                  withMedium:(NSString *)medium {
    return [[self alloc] initWithName:kUASharedContentEvent
                            withValue:nil
                           withSource:source
                           withMedium:medium];
}

+ (instancetype)sharedTemplate {
    return [self sharedTemplateWithSource:nil withMedium:nil];
}

+ (instancetype)consumedTemplate {
    return [self consumedTemplateWithValue:nil];
}

+ (instancetype)consumedTemplateWithValueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self consumedTemplateWithValue:decimalValue];
}

+ (instancetype)consumedTemplateWithValue:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithName:kUAConsumedContentEvent
                            withValue:eventValue
                           withSource:nil
                           withMedium:nil];
}

- (void)setIsFeature:(BOOL)isFeature {
    self.featureSet = YES;
    _isFeature = isFeature;
}

- (UACustomEvent *)createEvent {
    UACustomEvent *event = [UACustomEvent eventWithName:self.eventName];

    NSMutableDictionary *propertyDictionary = [NSMutableDictionary dictionary];
    
    if (self.eventValue) {
        [event setEventValue:self.eventValue];
        [propertyDictionary setValue:@YES forKey:kUAMediaEventTemplateLifetimeValue];
    } else {
        [propertyDictionary setValue:@NO forKey:kUAMediaEventTemplateLifetimeValue];
    }

    if (self.identifier) {
        [propertyDictionary setValue:self.identifier forKey:kUAMediaEventTemplateIdentifier];
    }

    if (self.category) {
        [propertyDictionary setValue:self.category forKey:kUAMediaEventTemplateCategory];
    }

    if (self.eventDescription) {
        [propertyDictionary setValue:self.eventDescription forKey:kUAMediaEventTemplateDescription];
    }

    if (self.type) {
        [propertyDictionary setValue:self.type forKey:kUAMediaEventTemplateType];
    }

    if (self.featureSet) {
        [propertyDictionary setValue:@(self.isFeature) forKey:kUAMediaEventTemplateFeature];
    }

    if (self.author) {
        [propertyDictionary setValue:self.author forKey:kUAMediaEventTemplateAuthor];
    }

    if (self.publishedDate) {
        [propertyDictionary setValue:self.publishedDate forKey:kUAMediaEventTemplatePublishedDate];
    }

    if (self.source) {
        [propertyDictionary setValue:self.source forKey:kUAMediaEventTemplateSource];
    }

    if (self.medium) {
        [propertyDictionary setValue:self.medium forKey:kUAMediaEventTemplateMedium];
    }

    event.templateType = kUAMediaEventTemplate;
    event.properties = propertyDictionary;
    return event;
}

@end
