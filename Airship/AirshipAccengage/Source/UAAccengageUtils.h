/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UAAccengageUtils : NSObject

+ (NSData *)decryptData:(NSData *)data key:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
