

#import <Foundation/Foundation.h>

@class UAConfig;

@interface UAWhitelist : NSObject

+ (instancetype)whitelistWithConfig:(UAConfig *)config;

- (BOOL)addEntry:(NSString *)patternString;
- (BOOL)isWhitelisted:(NSURL *)url;

@end
