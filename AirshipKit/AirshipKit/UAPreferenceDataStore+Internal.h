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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Wrapper around NSUserDefaults that automatically applies a key prefix
 * to all entries.
 */
@interface UAPreferenceDataStore : NSObject

/**
 * Factory method for creating a preference data store with a key prefix.
 * @param keyPrefix The prefix to automatically apply to all keys.
 */
+ (instancetype)preferenceDataStoreWithKeyPrefix:(NSString *)keyPrefix;

/**
 * Migrates any values in NSUserDefaults that are not prefixed.
 * @param keys The keys to migrate.
 */
- (void)migrateUnprefixedKeys:(NSArray *)keys;

/**
 * Returns the object associated with the key.
 * @param key The preference key.
 */
- (id)objectForKey:(NSString *)key;

/**
 * Removes the value of the specified default key.
 * @param key The preference key.
 */
- (void)removeObjectForKey:(NSString *)key;

/**
 * Returns the string associated with the key.
 * @param key The preference key.
 */
- (nullable NSString *)stringForKey:(NSString *)key;

/**
 * Returns the array associated with the key.
 * @param key The preference key.
 */
- (nullable NSArray *)arrayForKey:(NSString *)key;

/**
 * Returns the dictionary associated with the key.
 * @param key The preference key.
 */
- (nullable NSDictionary *)dictionaryForKey:(NSString *)key;

/**
 * Returns the data associated with the key.
 * @param key The preference key.
 */
- (nullable NSData *)dataForKey:(NSString *)key;

/**
 * Returns the string array associated with the key.
 * @param key The preference key.
 */
- (nullable NSArray *)stringArrayForKey:(NSString *)key;

/**
 * Returns the integer associated with the key.
 * @param key The preference key.
 */
- (NSInteger)integerForKey:(NSString *)key;

/**
 * Returns the float associated with the key.
 * @param key The preference key.
 */
- (float)floatForKey:(NSString *)key;

/**
 * Returns the double associated with the key.
 * @param key The preference key.
 */
- (double)doubleForKey:(NSString *)key;

/**
 * Returns the BOOL associated with the key.
 * @param key The preference key.
 */
- (BOOL)boolForKey:(NSString *)key;

/**
 * Returns the URL associated with the key.
 * @param key The preference key.
 */
- (nullable NSURL *)URLForKey:(NSString *)key;

/**
 * Sets the value of the specified key.
 * @param value The preference value.
 * @param key The preference key.
 */
- (void)setInteger:(NSInteger)value forKey:(NSString *)key;

/**
 * Sets the value of the specified key.
 * @param value The preference value.
 * @param key The preference key.
 */
- (void)setFloat:(float)value forKey:(NSString *)key;

/**
 * Sets the value of the specified key.
 * @param value The preference value.
 * @param key The preference key.
 */
- (void)setDouble:(double)value forKey:(NSString *)key;

/**
 * Sets the value of the specified key.
 * @param value The preference value.
 * @param key The preference key.
 */
- (void)setBool:(BOOL)value forKey:(NSString *)key;

/**
 * Sets the value of the specified key.
 * @param url The preference value.
 * @param key The preference key.
 */
- (void)setURL:(nullable NSURL *)url forKey:(NSString *)key;

/**
 * Sets the value of the specified key.
 * @param value The preference value.
 * @param key The preference key.
 */
- (void)setObject:(nullable id)value forKey:(NSString *)key;

/**
 * Removes all the keys that start with the data store's key prefix.
 */
- (void)removeAll;

@end

NS_ASSUME_NONNULL_END
