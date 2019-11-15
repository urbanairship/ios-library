/* Copyright Airship and Contributors */

NS_ASSUME_NONNULL_BEGIN


/**
 Defines changes to perform on channel attributes.
*/
@interface UAAttributeMutations : NSObject

///---------------------------------------------------------------------------------------
/// @name Attribute Mutations Methods
///---------------------------------------------------------------------------------------

/**
 Generates an empty mutation.
 @return An empty mutation.
*/
+ (instancetype)mutations;

/**
 Define strings to be set to attributes.
 @param string The string to be set.
 @param attribute The attribute to which the string will be set.
 */
- (void)setString:(NSString *)string forAttribute:(NSString *)attribute;

/**
 Define attributes to be removed.
 @param attribute The attribute from which the string will be removed.
 */
- (void)removeAttribute:(NSString *)attribute;

@end

NS_ASSUME_NONNULL_END
