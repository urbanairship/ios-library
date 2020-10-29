/* Copyright Airship and Contributors */

#import "UARetailEventTemplate.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UACustomEvent+Internal.h"

#define kUARetailEventTemplate @"retail"
#define kUABrowsedProductEvent @"browsed"
#define kUAAddedToCartEvent @"added_to_cart"
#define kUAStarredProductEvent @"starred_product"
#define kUASharedProductEvent @"shared_product"
#define kUAPurchasedEvent @"purchased"
#define kUAWishlistEvent @"wishlist"
#define kUARetailEventTemplateLifetimeValue @"ltv"
#define kUARetailEventTemplateIdentifier @"id"
#define kUARetailEventTemplateCategory @"category"
#define kUARetailEventTemplateDescription @"description"
#define kUARetailEventTemplateBrand @"brand"
#define kUARetailEventTemplateNewItem @"new_item"
#define kUARetailEventTemplateSource @"source"
#define kUARetailEventTemplateMedium @"medium"
#define kUARetailEventTemplateWishlistName @"wishlist_name"
#define kUARetailEventTemplateWishlistID @"wishlist_id"

@interface UARetailEventTemplate()
@property (nonatomic, copy) NSString *eventName;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSString *medium;
@property (nonatomic, copy) NSString *wishlistName;
@property (nonatomic, copy) NSString *wishlistID;
@property (nonatomic, assign) BOOL newItemSet;
@end

@implementation UARetailEventTemplate

- (instancetype)initWithName:(NSString *)name
                   withValue:(NSDecimalNumber *)eventValue
                  withSource:(NSString *)source
                  withMedium:(NSString *)medium
            withWishlistName:(NSString *)wishlistName
              withWishlistID:(NSString *)wishlistID {
    self = [super init];
    if (self) {
        self.eventName = name;
        self.eventValue = eventValue;
        self.source = source;
        self.medium = medium;
        self.wishlistName = wishlistName;
        self.wishlistID = wishlistID;
    }

    return self;
}

+ (instancetype)browsedTemplate {
    return [self browsedTemplateWithValue:nil];
}

+ (instancetype)browsedTemplateWithValueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self browsedTemplateWithValue:decimalValue];
}

+ (instancetype)browsedTemplateWithValue:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithName:kUABrowsedProductEvent
                            withValue:eventValue
                           withSource:nil
                           withMedium:nil
                     withWishlistName:nil
                       withWishlistID:nil];
}

+ (instancetype)addedToCartTemplate {
    return [self addedToCartTemplateWithValue:nil];
}

+ (instancetype)addedToCartTemplateWithValueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self addedToCartTemplateWithValue:decimalValue];
}

+ (instancetype)addedToCartTemplateWithValue:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithName:kUAAddedToCartEvent
                            withValue:eventValue
                           withSource:nil
                           withMedium:nil
                     withWishlistName:nil
                       withWishlistID:nil];
}

+ (instancetype)starredProductTemplate {
    return [self starredProductTemplateWithValue:nil];
}

+ (instancetype)starredProductTemplateWithValueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self starredProductTemplateWithValue:decimalValue];
}

+ (instancetype)starredProductTemplateWithValue:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithName:kUAStarredProductEvent
                            withValue:eventValue
                           withSource:nil
                           withMedium:nil
                     withWishlistName:nil
                       withWishlistID:nil];
}

+ (instancetype)purchasedTemplate {
    return [self purchasedTemplateWithValue:nil];
}

+ (instancetype)purchasedTemplateWithValueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self purchasedTemplateWithValue:decimalValue];
}

+ (instancetype)purchasedTemplateWithValue:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithName:kUAPurchasedEvent
                            withValue:eventValue
                           withSource:nil
                           withMedium:nil
                     withWishlistName:nil
                       withWishlistID:nil];
}

+ (instancetype)sharedProductTemplate {
    return [self sharedProductTemplateWithValue:nil];
}

+ (instancetype)sharedProductTemplateWithValueFromString:(NSString *)eventValue {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [self sharedProductTemplateWithValue:decimalValue];
}

+ (instancetype)sharedProductTemplateWithValue:(NSDecimalNumber *)eventValue {
    return [[self alloc] initWithName:kUASharedProductEvent
                            withValue:eventValue
                           withSource:nil
                           withMedium:nil
                     withWishlistName:nil
                       withWishlistID:nil];
}

+ (instancetype)sharedProductTemplateWithSource:(NSString *)source
                                  withMedium:(NSString *)medium {
    return [[self alloc] initWithName:kUASharedProductEvent
                            withValue:nil
                           withSource:source
                           withMedium:medium
                     withWishlistName:nil
                       withWishlistID:nil];
}

+ (instancetype)sharedProductTemplateWithValueFromString:(NSString *)eventValue
                                           withSource:(NSString *)source
                                           withMedium:(NSString *)medium {
    NSDecimalNumber *decimalValue = eventValue ? [NSDecimalNumber decimalNumberWithString:eventValue] : nil;
    return [[self alloc] initWithName:kUASharedProductEvent
                            withValue:decimalValue
                           withSource:source
                           withMedium:medium
                     withWishlistName:nil
                       withWishlistID:nil];
}

+ (instancetype)sharedProductTemplateWithValue:(NSDecimalNumber *)eventValue
                                 withSource:(NSString *)source
                                 withMedium:(NSString *)medium {
    return [[self alloc] initWithName:kUASharedProductEvent
                            withValue:eventValue
                           withSource:source
                           withMedium:medium
                     withWishlistName:nil
                       withWishlistID:nil];
}

+ (instancetype)wishlistTemplate {
    return [[self alloc] initWithName:kUAWishlistEvent
                            withValue:nil
                           withSource:nil
                           withMedium:nil
                     withWishlistName:nil
                       withWishlistID:nil];
}

+ (instancetype)wishlistTemplateWithName:(NSString *)name wishlistID:(NSString *)wishlistID {
    return [[self alloc] initWithName:kUAWishlistEvent
                            withValue:nil
                           withSource:nil
                           withMedium:nil
                     withWishlistName:name
                       withWishlistID:wishlistID];
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

- (void)setIsNewItem:(BOOL)isNewItem {
    self.newItemSet = YES;
    _isNewItem = isNewItem;
}

- (UACustomEvent *)createEvent {
    UACustomEvent *event = [UACustomEvent eventWithName:self.eventName];

    NSMutableDictionary *propertyDictionary = [NSMutableDictionary dictionary];
    
    if (self.eventValue) {
        [event setEventValue:self.eventValue];
    }

    if (self.eventValue && [self.eventName isEqualToString:kUAPurchasedEvent]) {
        [propertyDictionary setValue:@YES forKey:kUARetailEventTemplateLifetimeValue];
    } else {
       [propertyDictionary setValue:@NO forKey:kUARetailEventTemplateLifetimeValue];
    }

    if (self.transactionID) {
        [event setTransactionID:self.transactionID];
    }

    if (self.identifier) {
        [propertyDictionary setValue:self.identifier forKey:kUARetailEventTemplateIdentifier];
    }

    if (self.category) {
        [propertyDictionary setValue:self.category forKey:kUARetailEventTemplateCategory];
    }

    if (self.eventDescription) {
        [propertyDictionary setValue:self.eventDescription forKey:kUARetailEventTemplateDescription];
    }

    if (self.brand) {
        [propertyDictionary setValue:self.brand forKey:kUARetailEventTemplateBrand];
    }

    if (self.newItemSet) {
        [propertyDictionary setValue:@(self.isNewItem) forKey:kUARetailEventTemplateNewItem];
    }
    if (self.source) {
        [propertyDictionary setValue:self.source forKey:kUARetailEventTemplateSource];
    }

    if (self.medium) {
        [propertyDictionary setValue:self.medium forKey:kUARetailEventTemplateMedium];
    }
    
    if (self.wishlistID) {
        [propertyDictionary setValue:self.wishlistID forKey:kUARetailEventTemplateWishlistID];
    }
    
    if (self.wishlistName) {
        [propertyDictionary setValue:self.wishlistName forKey:kUARetailEventTemplateWishlistName];
    }

    event.templateType = kUARetailEventTemplate;
    event.properties = propertyDictionary;
    
    return event;
}

@end
