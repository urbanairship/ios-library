/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UAVersionMatcher : NSObject

/**
 * The original versionConstraint used to create this matcher
 */
@property (nonatomic, strong, readonly) NSString *versionConstraint;

/**
 * Create a matcher for the supplied version contraint
 *
 * @param versionConstraint constraint that matches one of our supported patterns
 * @return matcher or nil if versionConstraint does not match any of the expected patterns
 */
+ (nullable instancetype)matcherWithVersionConstraint:(NSString *)versionConstraint;

///---------------------------------------------------------------------------------------
/// @name Version Matcher Evaluation
///---------------------------------------------------------------------------------------

/**
 * Evaluates the object with the matcher.
 *
 * @param object The object to evaluate.
 * @return `YES` if the matcher matches the object, otherwise `NO`.
 */
- (BOOL)evaluateObject:(nullable id)object;

///---------------------------------------------------------------------------------------
/// SDK-private extensions to UAVersionMatcher for unit testing
///---------------------------------------------------------------------------------------

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
