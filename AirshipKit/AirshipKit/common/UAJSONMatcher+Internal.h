/* Copyright Urban Airship and Contributors */

#import "UAJSONMatcher.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAJSONMatcher
 */
@interface UAJSONMatcher ()

///---------------------------------------------------------------------------------------
/// @name JSON Matcher Internal Methods
///---------------------------------------------------------------------------------------

/**
* Factory method to create a JSON matcher.
*
* @param valueMatcher Matcher to apply to the value.
* @param ignoreCase {@code YES} to ignore case when checking String values, {@code NO} to check case.
* Strings contained in arrays and dictionaries also follow this rule.
* @return A JSON matcher.
*/
+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher ignoreCase:(BOOL)ignoreCase;

/**
* Factory method to create a JSON matcher.
 *
 * @param valueMatcher Matcher to apply to the value.
 * @param scope Used to path into the object before evaluating the value. Key is applied
 * after the scope.
 * @param ignoreCase {@code YES} to ignore case when checking String values, {@code NO} to check case.
 * Strings contained in arrays and dictionaries also follow this rule.
 * @return A JSON matcher.
 */
+ (instancetype)matcherWithValueMatcher:(UAJSONValueMatcher *)valueMatcher scope:(NSArray<NSString *>*)scope ignoreCase:(BOOL)ignoreCase;


@end

NS_ASSUME_NONNULL_END
