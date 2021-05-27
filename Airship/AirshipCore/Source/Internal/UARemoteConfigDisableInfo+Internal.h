/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAJSONPredicate.h"
#import "UARemoteConfigDisableInfo+Internal.h"
#import "UAVersionMatcher.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Defines disable info delivered in a remote config.
 */
@interface UARemoteConfigDisableInfo : NSObject

/**
 * Optional modules names to disable.
 */
@property (nonatomic, copy, readonly) NSArray<NSString *> *disableModuleNames;

/**
 * Optional Remote data refresh interval.
 */
@property (nonatomic, strong, readonly, nullable) NSNumber *remoteDataRefreshInterval;

/**
 * Optional predicate to apply the app version object.
 */
@property (nonatomic, strong, readonly, nullable) UAJSONPredicate *appVersionConstraint;

/**
 * Optional sdk version matchers.
 */
@property (nonatomic, copy, readonly) NSArray<UAVersionMatcher *> *sdkVersionConstraints;

/**
 * Factory method to create a disable info.
 * @param disableModuleNames The names of modules to disable.
 * @param sdkVersionConstraints The names of modules to disable.
 * @param appVersionConstraint The names of modules to disable.
 * @param remoteDataRefreshInterval The new remote data refresh interval.
 * @return The disable info instance.
 */
+ (instancetype)disableInfoWithModuleNames:(NSArray<NSString *> *)disableModuleNames
                     sdkVersionConstraints:(NSArray<UAVersionMatcher *> *)sdkVersionConstraints
                      appVersionConstraint:(nullable UAJSONPredicate *)appVersionConstraint
                 remoteDataRefreshInterval:(nullable NSNumber *)remoteDataRefreshInterval;

/**
 * Parses a disable info from a JSON object.
 * @param JSON The json.
 * @return The disable info, or nil if one could not be parsed.
 */
+ (nullable instancetype)disableInfoWithJSON:(id)JSON;

@end

NS_ASSUME_NONNULL_END
