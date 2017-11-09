/* Copyright 2017 Urban Airship and Contributors */

#import "UAVersionMatcher.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAVersionMatcher for unit testing
 */
@interface UAVersionMatcher()

/**
 * Check if versionConstraint matches the "exact version" pattern
 *
 * @param versionConstraint constraint string
 * @return `YES` if versionConstraint matches the "exact version" pattern
 */
+ (BOOL)isExactVersion:(NSString *)versionConstraint;

/**
 * Check if versionConstraint matches the "sub version" pattern
 *
 * @param versionConstraint constraint string
 * @return `YES` if versionConstraint matches the "sub version" pattern
 */
+ (BOOL)isSubVersion:(NSString *)versionConstraint;

/**
 * Check if versionConstraint matches the "version range" pattern
 *
 * @param versionConstraint constraint string
 * @return `YES` if versionConstraint matches the "version range" pattern
 */
+ (BOOL)isVersionRange:(NSString *)versionConstraint;

@end

NS_ASSUME_NONNULL_END
