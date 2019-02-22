/* Copyright Urban Airship and Contributors */

#import "UAJSONMatcher.h"
#import "UAJSONValueMatcher+Internal.h"

@interface UAJSONMatcher()
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSArray *scope;
@property (nonatomic, strong) UAJSONValueMatcher *valueMatcher;
@property (nonatomic, copy) NSNumber *ignoreCase;
@end

NSString *const UAJSONMatcherKey = @"key";
NSString *const UAJSONMatcherScope = @"scope";
NSString *const UAJSONMatcherValue = @"value";
NSString *const UAJSONMatcherIgnoreCase = @"ignore_case";

NSString * const UAJSONMatcherErrorDomain = @"com.urbanairship.json_matcher";

@implementation UAJSONMatcher

- (instancetype)initWithValueMatcher:(UAJSONValueMatcher *)valueMatcher key:(NSString *)key scope:(NSArray<NSString *>*)scope ignoreCase:(NSNumber *)ignoreCase {
    self = [super init];
    if (self) {
        self.valueMatcher = valueMatcher;
        self.key = key;
        self.scope = scope;
        self.ignoreCase = ignoreCase;
    }

    return self;
}

- (NSDictionary *)payload {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setValue:self.valueMatcher.payload forKey:UAJSONMatcherValue];
    [payload setValue:self.key forKey:UAJSONMatcherKey];
    [payload setValue:self.scope forKey:UAJSONMatcherScope];
    [payload setValue:self.ignoreCase forKey:UAJSONMatcherIgnoreCase];
    return payload;
}

- (BOOL)evaluateObject:(id)value {
    if (self.ignoreCase) {
        return [self evaluateObject:value ignoreCase:[self.ignoreCase boolValue]];
    } else {
        return [self evaluateObject:value ignoreCase:NO];
    }
}

- (BOOL)evaluateObject:(id)value ignoreCase:(BOOL)ignoreCase {
    id object = value;
    
    NSMutableArray *paths = [NSMutableArray array];
    if (self.scope) {
        [paths addObjectsFromArray:self.scope];
    }

    if (self.key) {
        [paths addObject:self.key];
    }

    for (NSString *path in paths) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            object = nil;
            break;
        }

        object = object[path];
    }

    return [self.valueMatcher evaluateObject:object ignoreCase:ignoreCase];
}

+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher {
    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:nil scope:nil ignoreCase:nil];
}

+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher ignoreCase:(BOOL)ignoreCase {
    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:nil scope:nil ignoreCase:[NSNumber numberWithBool:ignoreCase]];
}

+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher key:(NSString *)key {
    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:key scope:nil ignoreCase:nil];
}

+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher key:(NSString *)key scope:(NSArray<NSString *>*)scope {
    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:key scope:scope ignoreCase:nil];
}

+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher scope:(NSArray<NSString *>*)scope {
    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:nil scope:scope ignoreCase:nil];
}

+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher scope:(NSArray<NSString *>*)scope ignoreCase:(BOOL)ignoreCase {
    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:nil scope:scope ignoreCase:[NSNumber numberWithBool:ignoreCase]];
}

+ (instancetype)matcherWithJSON:(id)json error:(NSError **)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAJSONMatcherErrorDomain
                                          code:UAJSONMatcherErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    NSDictionary *info = json;
  
    // Optional scope
    NSArray *scope;
    if (info[UAJSONMatcherScope]) {
        if ([info[UAJSONMatcherScope] isKindOfClass:[NSString class]]) {
            scope = @[info[UAJSONMatcherScope]];
        } else if ([info[UAJSONMatcherScope] isKindOfClass:[NSArray class]]) {
            NSMutableArray *mutableScope = [NSMutableArray array];
            for (id value in info[UAJSONMatcherScope]) {
                if (![value isKindOfClass:[NSString class]]) {
                    if (error) {
                        NSString *msg = [NSString stringWithFormat:@"Scope must be either an array of strings or a string. Invalid value: %@", value];
                        *error =  [NSError errorWithDomain:UAJSONMatcherErrorDomain
                                                      code:UAJSONMatcherErrorCodeInvalidJSON
                                                  userInfo:@{NSLocalizedDescriptionKey:msg}];
                    }

                    return nil;
                }

                [mutableScope addObject:value];
            }

            scope = [mutableScope copy];
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Scope must be either an array of strings or a string. Invalid value: %@", scope];
                *error =  [NSError errorWithDomain:UAJSONMatcherErrorDomain
                                              code:UAJSONMatcherErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }
    }

    // Optional key
    NSString *key;
    if (info[UAJSONMatcherKey]) {
        if (![info[UAJSONMatcherKey] isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Key must be a string. Invalid value: %@", key];
                *error =  [NSError errorWithDomain:UAJSONMatcherErrorDomain
                                              code:UAJSONMatcherErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }

        key = info[UAJSONMatcherKey];
    }

    // Optional case insensitivity
    NSNumber *ignoreCase;
    if (info[UAJSONMatcherIgnoreCase]) {
        if (![info[UAJSONMatcherIgnoreCase] isKindOfClass:[NSNumber class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Value for the \"%@\" key must be a boolean. Invalid value: %@", UAJSONMatcherIgnoreCase, info[UAJSONMatcherIgnoreCase]];
                *error =  [NSError errorWithDomain:UAJSONMatcherErrorDomain
                                              code:UAJSONMatcherErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            
            return nil;
        }
        
        ignoreCase = info[UAJSONMatcherIgnoreCase];
    }
    
    // Required value
    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWithJSON:info[UAJSONMatcherValue] error:error];
    if (!valueMatcher) {
        return nil;
    }
    
    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:key scope:scope ignoreCase:ignoreCase];
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    
    if (![other isKindOfClass:[self class]]) {
        return NO;
    }
    
    return [self isEqualToJSONMatcher:(UAJSONMatcher *)other];
}

- (BOOL)isEqualToJSONMatcher:(nullable UAJSONMatcher *)matcher {
    if (self.valueMatcher && (!matcher.valueMatcher || ![self.valueMatcher isEqual:matcher.valueMatcher])) {
        return NO;
    }
    if (self.key && (!matcher.key || ![self.key isEqual:matcher.key])) {
        return NO;
    }
    if (self.scope && (!matcher.scope || ![self.scope isEqual:matcher.scope])) {
        return NO;
    }
    if (self.ignoreCase && (!matcher.ignoreCase || ![self.ignoreCase isEqual:matcher.ignoreCase])) {
        return NO;
    }
    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.valueMatcher hash];
    result = 31 * result + [self.key hash];
    result = 31 * result + [self.scope hash];
    result = 31 * result + [self.ignoreCase hash];
    return result;
}


@end
