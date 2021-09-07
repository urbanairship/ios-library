/* Copyright Airship and Contributors */

#import "UATagSelector+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

/**
 * Represents the type of the tag selector.
 */
typedef NS_ENUM(NSInteger, UATagSelectorType) {
    UATagSelectorTypeOR,
    UATagSelectorTypeAND,
    UATagSelectorTypeNOT,
    UATagSelectorTypeTag
};

NSString * const UATagSelectorTagJSONKey = @"tag";
NSString * const UATagSelectorANDJSONKey = @"and";
NSString * const UATagSelectorORJSONKey = @"or";
NSString * const UATagSelectorNOTJSONKey = @"not";
NSString * const UATagSelectorGroupKey = @"group";

NSString * const UATagSelectorErrorDomain = @"com.urbanairship.in_app_message_tag_selector";

@interface UATagSelector()

@property (nonatomic, assign) UATagSelectorType type;
@property (nonatomic, copy) NSString *tag;
@property (nonatomic, copy) NSArray<UATagSelector *> *selectors;
@property (nonatomic, copy) NSString *group;

@end

@implementation UATagSelector

- (instancetype)initWithType:(UATagSelectorType)type
                   selectors:(NSArray<UATagSelector *> *)selectors
                         tag:(NSString *)tag
                       group:(NSString *)group {

    if (self = [super init]) {
        self.type = type;

        if (selectors) {
            self.selectors = [NSArray arrayWithArray:selectors];
        } else {
            self.selectors = nil;
        }

        self.tag = tag;
        self.group = group;
    }

    return self;
}

+ (instancetype)and:(NSArray<UATagSelector *> *)selectors {
    return [[self alloc] initWithType:UATagSelectorTypeAND selectors:selectors tag:nil group:nil];
}

+ (instancetype)or:(NSArray<UATagSelector *> *)selectors {
    return [[self alloc] initWithType:UATagSelectorTypeOR selectors:selectors tag:nil group:nil];
}

+ (instancetype)not:(UATagSelector *)selector {
    return [[self alloc] initWithType:UATagSelectorTypeNOT selectors:@[selector] tag:nil group:nil];
}

+ (instancetype)tag:(NSString *)tag {
    return [[self alloc] initWithType:UATagSelectorTypeTag selectors:nil tag:tag group:nil];
}

+ (instancetype)tag:(NSString *)tag group:(NSString *)group {
    return [[self alloc] initWithType:UATagSelectorTypeTag selectors:nil tag:tag group:group];
}

+ (instancetype)selectorWithJSON:(NSDictionary *)json error:(NSError **)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Json must be a dictionary. Invalid value: %@", json]];
        }
        return nil;
    }
    
    id tag = json[UATagSelectorTagJSONKey];
    id group = json[UATagSelectorGroupKey];

    if (tag) {
        if ([tag isKindOfClass:[NSString class]]) {
            if (group) {
                if ([group isKindOfClass:[NSString class]]) {
                    return [self tag:tag group:group];
                } else {
                    if (error) {
                        *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"group\" type must be a string. Invalid value: %@", group]];
                    }
                    return nil;
                }
            } else {
                return [self tag:tag];
            }
        } else {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"tag\" type must be a string. Invalid value: %@", tag]];
            }
            return nil;
        }
    }
    
    id selectors = json[UATagSelectorORJSONKey];
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

    selectors = json[UATagSelectorANDJSONKey];
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
    
    id selector = json[UATagSelectorNOTJSONKey];
    if (selector) {
        if ([selector isKindOfClass:[NSDictionary class]]) {
            return [self not:[self selectorWithJSON:selector error:error]];
        } else {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"NOT\" type must be a single dictionary. Invalid value: %@", selectors]];
            }
            return nil;
        }
    }

    if (error) {
        *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Json did not contain a valid type - Invalid value: %@", json]];
    }
    return nil;
}

+ (NSError *)invalidJSONErrorWithMsg:(NSString *)msg {
    return [NSError errorWithDomain:UATagSelectorErrorDomain
                               code:UATagSelectorErrorCodeInvalidJSON
                           userInfo:@{NSLocalizedDescriptionKey:msg}];
}

+ (NSArray<UATagSelector *> *)parseSelectors:(NSArray<NSDictionary *> *)jsonSelectors error:(NSError **)error {
    NSMutableArray<UATagSelector *> *selectors = [NSMutableArray arrayWithCapacity:jsonSelectors.count];
    
    for (NSDictionary *jsonSelector in jsonSelectors) {
        UATagSelector *selector = [self selectorWithJSON:jsonSelector error:error];
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

- (NSDictionary *)toJSON {
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:1];
    
    switch (self.type) {
        case UATagSelectorTypeTag:
            [json setValue:self.tag forKey:UATagSelectorTagJSONKey];
            [json setValue:self.group forKey:UATagSelectorGroupKey];
            break;
            
        case UATagSelectorTypeNOT:
            [json setValue:[self.selectors firstObject].toJSON forKey:UATagSelectorNOTJSONKey];
            break;
            
        case UATagSelectorTypeOR:
            [json setValue:[self selectorsToJSON] forKey:UATagSelectorORJSONKey];
            break;

        case UATagSelectorTypeAND:
            [json setValue:[self selectorsToJSON] forKey:UATagSelectorANDJSONKey];
            break;

        default:
            break;
    }
    
    return json;
}

- (NSArray<NSDictionary *> *)selectorsToJSON {
    NSMutableArray<NSDictionary *> *selectorsAsJson = [NSMutableArray arrayWithCapacity:self.selectors.count];
    for (UATagSelector *selector in self.selectors) {
        [selectorsAsJson addObject:[selector toJSON]];
    }
    return selectorsAsJson;
}

- (BOOL)apply:(NSArray<NSString *> *)tags tagGroups:(UATagGroups *)tagGroups  {
    switch (self.type) {
        case UATagSelectorTypeTag:
            if (self.group) {
                NSSet *groupTags = tagGroups.tags[self.group];
                return [groupTags containsObject:self.tag];
            }

            return [tags containsObject:self.tag];
            
        case UATagSelectorTypeNOT:
            return ![self.selectors[0] apply:tags tagGroups:tagGroups];
            
        case UATagSelectorTypeAND:
            for (UATagSelector *selector in self.selectors) {
                if (![selector apply:tags tagGroups:tagGroups]) {
                    return NO;
                }
            }
            return YES;
            
        case UATagSelectorTypeOR:
            for (UATagSelector *selector in self.selectors) {
                if ([selector apply:tags tagGroups:tagGroups]) {
                    return YES;
                }
            }
            return NO;
            
        default:
            break;
    }

    return NO;
}

- (BOOL)apply:(NSArray<NSString *> *)tags {
    return [self apply:tags tagGroups:nil];
}

- (BOOL)containsTagGroups {
    if (self.tag && self.group) {
        return YES;
    }

    for (UATagSelector *selector in self.selectors) {
        if ([selector containsTagGroups]) {
            return YES;
        }
    }

    return NO;
}

- (UATagGroups *)tagGroups {
    if (self.group && self.tag) {
        return [UATagGroups tagGroupsWithTags:@{self.group : @[self.tag]}];
    } else {
        UATagGroups *tagGroups = [UATagGroups tagGroupsWithTags:@{}];

        for (UATagSelector *selector in self.selectors) {
            tagGroups = [tagGroups merge:selector.tagGroups];
        }

        return tagGroups;
    }
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    
    if (![other isKindOfClass:[self class]]) {
        return NO;
    }
    
    return [self isEqualToTagSelector:(UATagSelector *)other];
}

- (BOOL)isEqualToTagSelector:(nullable UATagSelector *)tagSelector {
    if (self.type != tagSelector.type) {
        return NO;
    }

    if ((self.tag != tagSelector.tag) && ![self.tag isEqual:tagSelector.tag]) {
        return NO;
    }

    if ((self.group != tagSelector.group) && ![self.group isEqualToString:tagSelector.group]) {
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
    result = 31 * result + [self.group hash];
    result = 31 * result + [self.selectors hash];

    return result;
}

- (NSString *)debugDescription {
    return [UAJSONUtils stringWithObject:[self toJSON]];
}

@end
