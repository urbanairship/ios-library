/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageTagSelector.h"

/**
 * Represents the type of the tag selector.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageTagSelectorType) {
    UAInAppMessageTagSelectorTypeOR,
    UAInAppMessageTagSelectorTypeAND,
    UAInAppMessageTagSelectorTypeNOT,
    UAInAppMessageTagSelectorTypeTag
};

NSString * const UAInAppMessageTagSelectorTagJSONKey = @"tag";
NSString * const UAInAppMessageTagSelectorANDJSONKey = @"and";
NSString * const UAInAppMessageTagSelectorORJSONKey = @"or";
NSString * const UAInAppMessageTagSelectorNOTJSONKey = @"not";

NSString * const UAInAppMessageTagSelectorErrorDomain = @"com.urbanairship.in_app_message_tag_selector";

@interface UAInAppMessageTagSelector()

@property (nonatomic, assign) UAInAppMessageTagSelectorType type;
@property (nonatomic, strong) NSString *tag;
@property (nonatomic, strong) NSArray<UAInAppMessageTagSelector *> *selectors;

@end

@implementation UAInAppMessageTagSelector

- (instancetype)initWithType:(UAInAppMessageTagSelectorType)type selectors:(NSArray<UAInAppMessageTagSelector *> *)selectors tag:(NSString *)tag {
    if (self = [super init]) {
        self.type = type;
        if (selectors) {
            self.selectors = [NSArray arrayWithArray:selectors];
        } else {
            self.selectors = nil;
        }
        self.tag = tag;
    }
    return self;
}

+ (instancetype)and:(NSArray<UAInAppMessageTagSelector *> *)selectors {
    return [[self alloc] initWithType:UAInAppMessageTagSelectorTypeAND selectors:selectors tag:nil];
}

+ (instancetype)or:(NSArray<UAInAppMessageTagSelector *> *)selectors {
    return [[self alloc] initWithType:UAInAppMessageTagSelectorTypeOR selectors:selectors tag:nil];
}

+ (instancetype)not:(UAInAppMessageTagSelector *)selector {
    return [[self alloc] initWithType:UAInAppMessageTagSelectorTypeNOT selectors:@[selector] tag:nil];
}

+ (instancetype)tag:(NSString *)tag {
    return [[self alloc] initWithType:UAInAppMessageTagSelectorTypeTag selectors:nil tag:tag];
}

+ (instancetype)parseJson:(NSDictionary *)json error:(NSError **)error {
    if (!json) {
        return nil;
    }
    
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Json must be a dictionary. Invalid value: %@", json]];
        }
        return nil;
    }
    
    id tag = json[UAInAppMessageTagSelectorTagJSONKey];
    if (tag) {
        if ([tag isKindOfClass:[NSString class]]) {
            return [self tag:tag];
        } else {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"tag\" type must be a string. Invalid value: %@", tag]];
            }
            return nil;
        }
    }
    
    id selectors = json[UAInAppMessageTagSelectorORJSONKey];
    if (selectors) {
        if ([selectors isKindOfClass:[NSArray<NSDictionary *> class]]) {
            return [self or:[self parseSelectors:selectors error:error]];
        } else {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"OR\" type must be an array of dictionaries. Invalid value: %@", selectors]];
            }
            return nil;
        }
    }

    selectors = json[UAInAppMessageTagSelectorANDJSONKey];
    if (selectors) {
        if ([selectors isKindOfClass:[NSArray<NSDictionary *> class]]) {
            return [self and:[self parseSelectors:selectors error:error]];
        } else {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"AND\" type must be an array of dictionaries. Invalid value: %@", selectors]];
            }
            return nil;
        }
    }
    
    id selector = json[UAInAppMessageTagSelectorNOTJSONKey];
    if (selector) {
        if ([selector isKindOfClass:[NSDictionary class]]) {
            return [self not:[self parseJson:selector error:error]];
        } else {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"NOT\" type must be a single dictionary. Invalid value: %@", selectors]];
            }
            return nil;
        }
    }
    
    *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Json did not contain a valid type - Invalid value: %@", json]];
    return nil;
}

+ (NSError *)invalidJSONErrorWithMsg:(NSString *)msg {
    return [NSError errorWithDomain:UAInAppMessageTagSelectorErrorDomain
                               code:UAInAppMessageTagSelectorErrorCodeInvalidJSON
                           userInfo:@{NSLocalizedDescriptionKey:msg}];
}

+ (NSArray<UAInAppMessageTagSelector *> *)parseSelectors:(NSArray<NSDictionary *> *)jsonSelectors error:(NSError **)error {
    NSMutableArray<UAInAppMessageTagSelector *> *selectors = [NSMutableArray arrayWithCapacity:jsonSelectors.count];
    
    for (NSDictionary *jsonSelector in jsonSelectors) {
        UAInAppMessageTagSelector *selector = [self parseJson:jsonSelector error:error];
        if (selector) {
            [selectors addObject:selector];
        } else {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"JSON parsing of selector failed. Invalid value: %@", jsonSelector]];
            }
            return nil;
        }
    }
    
    return selectors;
}

- (NSDictionary *)toJsonValue {
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:1];
    
    switch (self.type) {
        case UAInAppMessageTagSelectorTypeTag:
            json[UAInAppMessageTagSelectorTagJSONKey] = self.tag;
            break;
            
        case UAInAppMessageTagSelectorTypeNOT:
            json[UAInAppMessageTagSelectorNOTJSONKey] = [self.selectors[0] toJsonValue];
            break;
            
        case UAInAppMessageTagSelectorTypeOR:
            json[UAInAppMessageTagSelectorORJSONKey] = [self selectorsToJsonValue];
            break;

        case UAInAppMessageTagSelectorTypeAND:
            json[UAInAppMessageTagSelectorANDJSONKey] = [self selectorsToJsonValue];
            break;

        default:
            break;
    }
    NSLog(@"json = %@",json);
    return json;
}

- (NSArray<NSDictionary *> *)selectorsToJsonValue {
    NSMutableArray<NSDictionary *> *selectorsAsJson = [NSMutableArray arrayWithCapacity:self.selectors.count];
    for (UAInAppMessageTagSelector *selector in self.selectors) {
        [selectorsAsJson addObject:[selector toJsonValue]];
    }
    return selectorsAsJson;
}

- (BOOL)apply:(NSArray<NSString *> *)tags {
    switch (self.type) {
        case UAInAppMessageTagSelectorTypeTag:
            return [tags containsObject:self.tag];
            
        case UAInAppMessageTagSelectorTypeNOT:
            return ![self.selectors[0] apply:tags];
            
        case UAInAppMessageTagSelectorTypeAND:
            for (UAInAppMessageTagSelector *selector in self.selectors) {
                if (![selector apply:tags]) {
                    return NO;
                }
            }
            return YES;
            
        case UAInAppMessageTagSelectorTypeOR:
            for (UAInAppMessageTagSelector *selector in self.selectors) {
                if ([selector apply:tags]) {
                    return YES;
                }
            }
            return NO;
            
        default:
            break;
    }
    return NO;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    
    if (![other isKindOfClass:[self class]]) {
        return NO;
    }
    
    return [self isEqualToTagSelector:(UAInAppMessageTagSelector *)other];
}

- (BOOL)isEqualToTagSelector:(nullable UAInAppMessageTagSelector *)tagSelector {
    if (self.type != tagSelector.type) {
        return NO;
    }
    if ((self.tag != tagSelector.tag) && ![self.tag isEqual:tagSelector.tag]) {
        return NO;
    }
    if ((self.selectors != tagSelector.selectors) && ![self.selectors isEqual:tagSelector.selectors]) {
        return NO;
    }
    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + self.type;
    result = 31 * result + [self.tag hash];
    result = 31 * result + [self.selectors hash];
    return result;
}

@end
