/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Defines changes to perform on channel attributes.
 */
@interface UAAttributeMutations : NSObject

///---------------------------------------------------------------------------------------
/// @name Attribute Mutations Methods
///---------------------------------------------------------------------------------------

/**
 * Generates an empty mutation.
 * @return An empty mutation.
 */
+ (instancetype)mutations;

/**
 * Sets a string attribute
 * @param string The string.
 * @param attribute The attribute key.
 */
- (void)setString:(NSString *)string forAttribute:(NSString *)attribute;

/**
 * Sets a number attribute
 * @param number The number.
 * @param attribute The attribute key.
 */
- (void)setNumber:(NSNumber *)number forAttribute:(NSString *)attribute;

/**
 * Removes an attribute
 * @param attribute The attribute key.
 */
- (void)removeAttribute:(NSString *)attribute;

@end

NS_ASSUME_NONNULL_END
