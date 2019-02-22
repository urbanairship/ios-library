/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * An abstract class representing a the remote config payload for an individual module.
 */
@interface UARemoteConfig : NSObject

/**
 * UARemoteConfig class factory method.
 *
 * @param json A remote config JSON dictionary.
 */
+ (instancetype)configWithJSON:(NSDictionary *)json;

/**
 * Merges the contents of two remote configs. Used for reconciling differences between common and platform data.
 */
- (UARemoteConfig *)combineWithConfig:(UARemoteConfig *)config;

@end
