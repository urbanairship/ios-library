/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@interface UARemoteConfig : NSObject

+ (instancetype)configWithJSON:(NSDictionary *)json;

- (UARemoteConfig *)combineWithConfig:(UARemoteConfig *)config;

@end
