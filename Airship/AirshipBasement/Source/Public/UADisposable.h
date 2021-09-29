/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A convenience class for creating self-referencing cancellation tokens.
 *
 * @note It is left up to the creator to determine what is disposed of and
 * under what circumstances.  This includes threading and memory management concerns.
 */
NS_SWIFT_NAME(Disposable)
@interface UADisposable : NSObject

///---------------------------------------------------------------------------------------
/// @name Disposable Creation
///---------------------------------------------------------------------------------------

/**
 * Create a new disposable.
 *
 * @param disposalBlock A disposal block to be executed upon disposal.
 */
- (instancetype)init:(void (^)(void))disposalBlock NS_SWIFT_NAME(init(_:));

///---------------------------------------------------------------------------------------
/// @name Disposable Remove
///---------------------------------------------------------------------------------------

/**
 * Dispose of associated resources.
 */
- (void)dispose;

@end

NS_ASSUME_NONNULL_END
