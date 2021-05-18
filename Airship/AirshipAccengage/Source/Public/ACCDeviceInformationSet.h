/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ACCDeviceInformationSet : NSObject <NSSecureCoding>

/*!
 *  @brief Set a string parameter to the data
 *
 *  @param string The string parameter
 *  @param key The key of your string parameter
 */

- (void)setString:(NSString *)string forKey:(NSString *)key;

/*!
 *  @brief Set a number parameter to the data
 *
 *  @param number The number parameter
 *  @param key The key of your number parameter
 */

- (void)setNumber:(NSNumber *)number forKey:(NSString *)key;

/*!
 *  @brief Set a date parameter to the data
 *
 *  @param date The date parameter
 *  @param key The key of your date parameter
 */

- (void)setDate:(NSDate *)date forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
