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

#import "UAJSONMatcher.h"
#import "UAJSONValueMatcher.h"

@interface UAJSONMatcher()
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSArray *scope;
@property (nonatomic, strong) UAJSONValueMatcher *valueMatcher;
@end

NSString *const UAJSONMatcherKey = @"key";
NSString *const UAJSONMatcherScope = @"scope";
NSString *const UAJSONMatcherValue = @"value";

NSString * const UAJSONMatcherErrorDomain = @"com.urbanairship.json_matcher";

@implementation UAJSONMatcher

- (instancetype)initWithValueMatcher:(UAJSONValueMatcher *)valueMatcher key:(NSString *)key scope:(NSArray<NSString *>*)scope {
    self = [super self];
    if (self) {
        self.valueMatcher = valueMatcher;
        self.key = key;
        self.scope = scope;
    }

    return self;
}

- (NSDictionary *)payload {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setValue:self.valueMatcher.payload forKey:UAJSONMatcherValue];
    [payload setValue:self.key forKey:UAJSONMatcherKey];
    [payload setValue:self.scope forKey:UAJSONMatcherScope];
    return payload;
}

- (BOOL)evaluateObject:(id)value {
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

    return [self.valueMatcher evaluateObject:object];
}

+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher {
    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:nil scope:nil];
}

+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher key:(NSString *)key {
    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:key scope:nil];
}

+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher key:(NSString *)key scope:(NSArray<NSString *>*)scope {
    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:key scope:scope];
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
    NSSet *keySet = [NSSet setWithArray:info.allKeys];
    NSSet *allowedKeys = [NSSet setWithArray:@[UAJSONMatcherValue, UAJSONMatcherKey, UAJSONMatcherScope]];

    if (![keySet isSubsetOfSet:allowedKeys]) {
        if (error) {
            NSMutableSet *invalid = [NSMutableSet setWithSet:keySet];
            [invalid minusSet:allowedKeys];

            NSString *msg = [NSString stringWithFormat:@"Invalid keys: %@", invalid];
            *error =  [NSError errorWithDomain:UAJSONMatcherErrorDomain
                                          code:UAJSONMatcherErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

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

    // Required value
    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWithJSON:info[UAJSONMatcherValue] error:error];
    if (!valueMatcher) {
        return nil;
    }

    return [[UAJSONMatcher alloc] initWithValueMatcher:valueMatcher key:key scope:scope];
}

@end
