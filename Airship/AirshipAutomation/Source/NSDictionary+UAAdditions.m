/* Copyright Airship and Contributors */

#import "NSDictionary+UAAdditions+Internal.h"

@implementation NSDictionary (UAAdditions)

- (nullable NSNumber *)numberForKey:(NSString *)key defaultValue:(nullable NSNumber *)defaultValue {
    id value = [self valueForKey:key];
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    return defaultValue;
}

- (nullable NSString *)stringForKey:(NSString *)key defaultValue:(nullable NSString *)defaultValue {
    id value = [self valueForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    return defaultValue;
}

- (nullable NSDictionary *)dictionaryForKey:(NSString *)key defaultValue:(nullable NSDictionary *)defaultValue {
    id value = [self valueForKey:key];
    if ([value isKindOfClass:[NSDictionary class]]) {
        return value;
    }
    return defaultValue;
}

- (nullable NSArray *)arrayForKey:(NSString *)key defaultValue:(nullable NSArray *)defaultValue {
    id value = [self valueForKey:key];
    if ([value isKindOfClass:[NSArray class]]) {
        return value;
    }
    return defaultValue;
}

@end
