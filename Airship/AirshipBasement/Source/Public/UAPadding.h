/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Padding adds constant values to a view's top, bottom, trailing or leading
 * constraints within its parent view.
 */
NS_SWIFT_NAME(Padding)
@interface UAPadding : NSObject

/**
 * The spacing constant added between the top of a view and its parent's top.
 */
@property(nonatomic, strong, nullable) NSNumber *top;

/**
 * The spacing constant added between the bottom of a view and its parent's bottom.
 */
@property(nonatomic, strong, nullable) NSNumber *bottom;

/**
 * The spacing constant added between the trailing edge of a view and its parent's trailing edge.
 */
@property(nonatomic, strong, nullable) NSNumber *trailing;

/**
 * The spacing constant added between the leading edge of a view and its parent's leading edge.
 */
@property(nonatomic, strong, nullable) NSNumber *leading;

/**
 * Init method
 *
 * @param top The top padding.
 * @param bottom The bottom padding.
 * @param leading The leading padding.
 * @param trailing The trailing padding.
 *
 * @return padding instance with specified padding.
 */
- (instancetype)initWithTop:(nullable NSNumber *)top
                     bottom:(nullable NSNumber *)bottom
                    leading:(nullable NSNumber *)leading
                   trailing:(nullable NSNumber *)trailing NS_SWIFT_NAME(init(_:_:_:_:));

/**
 * Factory method to create a padding object.
 *
 * @param top The top padding.
 * @param bottom The bottom padding.
 * @param leading The leading padding.
 * @param trailing The trailing padding.
 *
 * @return padding instance with specified padding.
 */
+ (instancetype)paddingWithTop:(nullable NSNumber *)top
                        bottom:(nullable NSNumber *)bottom
                       leading:(nullable NSNumber *)leading
                      trailing:(nullable NSNumber *)trailing;

/**
 * Factory method to create a padding object with a plist dictionary.
 *
 * @param paddingDict The dictionary of keys and values to be parsed into a padding object.
 *
 * @return padding instance with specified padding.
 */
+ (instancetype)paddingWithDictionary:(nullable NSDictionary *)paddingDict;

@end

NS_ASSUME_NONNULL_END
