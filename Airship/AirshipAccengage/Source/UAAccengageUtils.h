/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Utility methods for the Accengage module
 */
@interface UAAccengageUtils : NSObject

/**
 * Decrypts data using AES 256.
 * @param data The data.
 * @param key The encryption key
 */
+ (NSData *)decryptData:(NSData *)data key:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
