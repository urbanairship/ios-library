/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Convenience methods to parse values out of a dictionary.
 */
@interface NSDictionary (UAAdditions)

/**
 * Parses a number out of the dictionary.
 * @param key The key.
 * @param defaultValue The default value if the value does not exists or is not a number.
 * @return Either the value if it is a number, otherwise the default value.
 */
- (nullable NSNumber *)numberForKey:(NSString *)key defaultValue:(nullable NSNumber *)defaultValue;

/**
 * Parses a string out of the dictionary.
 * @param key The key.
 * @param defaultValue The default value if the value does not exists or is not a string.
 * @return Either the value if it is a string, otherwise the default value.
 */
- (nullable NSString *)stringForKey:(NSString *)key defaultValue:(nullable NSString *)defaultValue;

/**
 * Parses a dictionary out of the dictionary.
 * @param key The key.
 * @param defaultValue The default value if the value does not exists or is not a dictionary.
 * @return Either the value if it is a dictionary, otherwise the default value.
 */
- (nullable NSDictionary *)dictionaryForKey:(NSString *)key defaultValue:(nullable NSDictionary *)defaultValue;

/**
 * Parses a array out of the dictionary.
 * @param key The key.
 * @param defaultValue The default value if the value does not exists or is not a array.
 * @return Either the value if it is a array, otherwise the default value.
 */
- (nullable NSArray *)arrayForKey:(NSString *)key defaultValue:(nullable NSArray *)defaultValue;

@end

NS_ASSUME_NONNULL_END
