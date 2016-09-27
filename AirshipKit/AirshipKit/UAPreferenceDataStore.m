/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import "UAPreferenceDataStore+Internal.h"

@interface UAPreferenceDataStore()
@property (nonatomic, strong) NSUserDefaults *defaults;
@property (nonatomic, copy) NSString *keyPrefix;
@end


@implementation UAPreferenceDataStore

+ (instancetype)preferenceDataStoreWithKeyPrefix:(NSString *)keyPrefix {
    UAPreferenceDataStore *dataStore = [[UAPreferenceDataStore alloc] init];
    dataStore.defaults = [NSUserDefaults standardUserDefaults];
    dataStore.keyPrefix = keyPrefix;
    return dataStore;
}

- (NSString *)prefixKey:(NSString *)key {
    return [self.keyPrefix stringByAppendingString:key];
}

- (id)valueForKey:(NSString *)key {
    return [self.defaults valueForKey:[self prefixKey:key]];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    [self.defaults setValue:value forKey:[self prefixKey:key]];
}

- (void)removeObjectForKey:(NSString *)key {
    [self.defaults removeObjectForKey:[self prefixKey:key]];
}

- (id)objectForKey:(NSString *)key {
    return [self.defaults objectForKey:[self prefixKey:key]];
}

- (NSString *)stringForKey:(NSString *)key {
    return [self.defaults stringForKey:[self prefixKey:key]];
}

- (NSArray *)arrayForKey:(NSString *)key {
    return [self.defaults arrayForKey:[self prefixKey:key]];
}

- (NSDictionary *)dictionaryForKey:(NSString *)key {
    return [self.defaults dictionaryForKey:[self prefixKey:key]];
}

- (NSData *)dataForKey:(NSString *)key {
    return [self.defaults dataForKey:[self prefixKey:key]];
}

- (NSArray *)stringArrayForKey:(NSString *)key {
    return [self.defaults stringArrayForKey:[self prefixKey:key]];
}

- (NSInteger)integerForKey:(NSString *)key {
    return [self.defaults integerForKey:[self prefixKey:key]];
}

- (float)floatForKey:(NSString *)key {
    return [self.defaults floatForKey:[self prefixKey:key]];
}

- (double)doubleForKey:(NSString *)key {
    return [self.defaults doubleForKey:[self prefixKey:key]];
}

- (BOOL)boolForKey:(NSString *)key {
    return [self.defaults boolForKey:[self prefixKey:key]];
}

- (NSURL *)URLForKey:(NSString *)key {
    return [self.defaults URLForKey:[self prefixKey:key]];
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    [self.defaults setInteger:value forKey:[self prefixKey:key]];
}

- (void)setFloat:(float)value forKey:(NSString *)key {
    [self.defaults setFloat:value forKey:[self prefixKey:key]];
}

- (void)setDouble:(double)value forKey:(NSString *)key {
    [self.defaults setDouble:value forKey:[self prefixKey:key]];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    [self.defaults setBool:value forKey:[self prefixKey:key]];
}

- (void)setURL:(NSURL *)value forKey:(NSString *)key {
    [self.defaults setURL:value forKey:[self prefixKey:key]];
}

- (void)setObject:(id)value forKey:(NSString *)key {
    [self.defaults setObject:value forKey:[self prefixKey:key]];
}

- (void)migrateUnprefixedKeys:(NSArray *)keys {
    
    for (NSString *key in keys) {
        id value = [self.defaults objectForKey:key];
        if (value) {
            [self.defaults setValue:value forKey:[self prefixKey:key]];
            [self.defaults removeObjectForKey:key];
        }
    }
}

- (void)removeAll {
    for (NSString *key in [[self.defaults dictionaryRepresentation] allKeys]) {
        if ([key hasPrefix:self.keyPrefix]) {
            [self.defaults removeObjectForKey:key];
        }
    }
}

@end
