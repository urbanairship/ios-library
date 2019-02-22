/* Copyright Urban Airship and Contributors */

#import "UAJSONValueMatcher.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAJSONValueMatcher
 */
@interface UAJSONValueMatcher ()

///---------------------------------------------------------------------------------------
/// @name JSON Value Matcher Internal Methods
///---------------------------------------------------------------------------------------


/**
 * Compares two values, optionally ignoring string case.
 *
 * @param valueOne The first value to compare.
 * @param valueTwo The second value to compare.
 * @param ignoreCase {@code YES} to ignore case when checking String values, {@code NO} to check case.
 * Strings contained in arrays and dictionaries also follow this rule.
 * @return `YES` if the values are equal, otherwise `NO`.
 */
- (BOOL)value:(nullable id)valueOne isEqualToValue:(nullable id)valueTwo ignoreCase:(BOOL)ignoreCase;

@end

NS_ASSUME_NONNULL_END
