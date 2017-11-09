/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UAVersionMatcher : NSObject

/**
 * Create a matcher for the supplied version contraint
 *
 * @param versionConstraint constraint that matches one of our supported patterns
 * @return matcher or nil if versionConstraint does not match any of the expected patterns
 */
+ (instancetype)matcherWithVersionConstraint:(NSString *)versionConstraint;

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

@end

NS_ASSUME_NONNULL_END
