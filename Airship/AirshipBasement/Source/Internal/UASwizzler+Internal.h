/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Util class to help with swizzling methods.
 */
@interface UASwizzler : NSObject


/**
 * Factory method.
 */
+ (instancetype)swizzler;

/**
 * Swizzles a protocol method.
 * @param instance The instance.
 * @param selector The selector to swizzle.
 * @param protocol The selector's protocol.
 * @param implementation The implmentation to replace the method with.
 */
- (void)swizzleInstance:(id)instance
               selector:(SEL)selector
               protocol:(Protocol *)protocol
         implementation:(IMP)implementation;

/**
 * Swizzles a class or instance method.
 * @param instance The instance.
 * @param selector The selector to swizzle.
 * @param implementation The implmentation to replace the method with.
 */
- (void)swizzleInstance:(id)instance
               selector:(SEL)selector
         implementation:(IMP)implementation;


/**
 * Swizzles a protocol method.
 * @param clazz The class.
 * @param selector The selector to swizzle.
 * @param protocol The selector's protocol.
 * @param implementation The implmentation to replace the method with.
 */
- (void)swizzleClass:(Class)clazz
            selector:(SEL)selector
            protocol:(Protocol *)protocol
      implementation:(IMP)implementation;

/**
 * Swizzles a class or instance method.
 * @param clazz The class.
 * @param selector The selector to swizzle.
 * @param implementation The implmentation to replace the method with.
 */
- (void)swizzleClass:(Class)clazz
            selector:(SEL)selector
      implementation:(IMP)implementation;

/**
 * Unswizzles all methods.
 */
- (void)unswizzle;

/**
 * Gets the original implementation for a given selector.
 *
 * @param selector The selector.
 * @return The original implmentation, or nil if its not found.
 */
- (nullable IMP)originalImplementation:(SEL)selector;

@end

NS_ASSUME_NONNULL_END
